import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('parseHostFlat', () {
    test('bare testls.bit', () {
      final p = parseHostFlat('testls.bit')!;
      expect(p.namecoinName, 'd/testls');
      expect(p.subdomainLabels, isEmpty);
    });

    test('relay.testls.bit splits into d/testls + [relay]', () {
      final p = parseHostFlat('relay.testls.bit')!;
      expect(p.namecoinName, 'd/testls');
      expect(p.subdomainLabels, ['relay']);
    });

    test('a.b.c.testls.bit splits into d/testls + [a, b, c]', () {
      final p = parseHostFlat('a.b.c.testls.bit')!;
      expect(p.namecoinName, 'd/testls');
      expect(p.subdomainLabels, ['a', 'b', 'c']);
    });

    test('tolerates trailing dot', () {
      final p = parseHostFlat('relay.testls.bit.')!;
      expect(p.namecoinName, 'd/testls');
      expect(p.subdomainLabels, ['relay']);
    });

    test('tolerates uppercase', () {
      final p = parseHostFlat('Relay.TESTLS.BIT')!;
      expect(p.namecoinName, 'd/testls');
      expect(p.subdomainLabels, ['relay']);
    });

    test('rejects non-bit hosts', () {
      expect(parseHostFlat('example.com'), isNull);
      expect(parseHostFlat(''), isNull);
      expect(parseHostFlat('.bit'), isNull);
      expect(parseHostFlat('bit'), isNull);
      expect(parseHostFlat('testls.bittech'), isNull);
    });
  });

  group('walkSubdomain', () {
    test('empty labels returns root unchanged', () {
      final root = {
        'relay': 'wss://example.com/',
        'foo': 'bar',
      };
      final out = walkSubdomain(root, [])!;
      expect(out['relay'], 'wss://example.com/');
      expect(out['foo'], 'bar');
    });

    test('exact label match', () {
      final root = {
        'relay': 'wss://parent.example.com/',
        'map': {
          'sub': {'relay': 'wss://child.example.com/'},
        },
      };
      final out = walkSubdomain(root, ['sub'])!;
      expect(out['relay'], 'wss://child.example.com/');
    });

    test('wildcard fallback', () {
      final root = {
        'map': {
          '*': {'relay': 'wss://wild.example.com/'},
        },
      };
      final out = walkSubdomain(root, ['arbitrary'])!;
      expect(out['relay'], 'wss://wild.example.com/');
    });

    test('exact label preferred over wildcard', () {
      final root = {
        'map': {
          '*': {'relay': 'wss://wild.example.com/'},
          'specific': {'relay': 'wss://specific.example.com/'},
        },
      };
      final out = walkSubdomain(root, ['specific'])!;
      expect(out['relay'], 'wss://specific.example.com/');
    });

    test('returns null when no match', () {
      final root = {
        'map': {
          'other': {'relay': 'wss://other.example.com/'},
        },
      };
      expect(walkSubdomain(root, ['missing']), isNull);
    });

    test('multi-level walk: a.b.c uses map.c.map.b.map.a', () {
      final root = {
        'map': {
          'c': {
            'map': {
              'b': {
                'map': {
                  'a': {'relay': 'wss://abc.example.com/'},
                },
              },
            },
          },
        },
      };
      final out = walkSubdomain(root, ['a', 'b', 'c'])!;
      expect(out['relay'], 'wss://abc.example.com/');
    });

    test('empty-key default merges into parent', () {
      final root = {
        'relay': 'wss://parent.example.com/',
        'map': {
          '': {'tls': 'fallback-tls', 'extra': 'merged'},
        },
      };
      final out = walkSubdomain(root, [])!;
      // Existing parent fields take precedence.
      expect(out['relay'], 'wss://parent.example.com/');
      // New fields from "" merge in.
      expect(out['tls'], 'fallback-tls');
      expect(out['extra'], 'merged');
    });

    test('NO ancestor inheritance for relay/tls', () {
      final root = {
        'relay': 'wss://parent.example.com/',
        'tls': [
          [3, 1, 1, 'aGVsbG8='],
        ],
        'map': {
          'sub': {'foo': 'bar'},
        },
      };
      final out = walkSubdomain(root, ['sub'])!;
      // The walked node has 'foo' but NOT 'relay' or 'tls' from ancestor.
      expect(out['foo'], 'bar');
      expect(out.containsKey('relay'), isFalse);
      expect(out.containsKey('tls'), isFalse);
    });

    test('shorthand string promoted to {ip:[string]}', () {
      final root = {
        'map': {
          'sub': '203.0.113.10',
        },
      };
      final out = walkSubdomain(root, ['sub'])!;
      expect(out['ip'], ['203.0.113.10']);
    });
  });

  group('parseRelayUrls', () {
    test('top-level relay (string)', () {
      const value = '{"relay":"wss://relay.example.com/"}';
      expect(parseRelayUrls(value), ['wss://relay.example.com/']);
    });

    test('top-level relays (array)', () {
      const value =
          '{"relays":["wss://a.example.com/","wss://b.example.com/"]}';
      expect(parseRelayUrls(value),
          ['wss://a.example.com/', 'wss://b.example.com/']);
    });

    test('priority: relay > relays > nostr.relay > nostr.relays', () {
      const value = '''
      {
        "relay": "wss://1.example.com/",
        "relays": ["wss://2.example.com/"],
        "nostr": {
          "relay": "wss://3.example.com/",
          "relays": ["wss://4.example.com/"]
        }
      }''';
      final urls = parseRelayUrls(value);
      expect(urls.first, 'wss://1.example.com/');
      expect(urls, contains('wss://2.example.com/'));
      expect(urls, contains('wss://3.example.com/'));
      expect(urls, contains('wss://4.example.com/'));
    });

    test('non-ws scheme is rejected', () {
      const value = '''
      {"relay":"https://not-a-relay.example.com/","relays":["wss://ok.example.com/"]}''';
      expect(parseRelayUrls(value), ['wss://ok.example.com/']);
    });

    test('subdomain walk: relay.testls.bit', () {
      const value = '''
      {
        "relay": "wss://parent.example.com/",
        "map": {
          "relay": {"relay": "wss://relay.example.com/"}
        }
      }''';
      expect(parseRelayUrls(value, ['relay']),
          ['wss://relay.example.com/']);
    });

    test('subdomain walk: ancestor relay does NOT leak', () {
      const value = '''
      {
        "relay": "wss://parent.example.com/",
        "map": {
          "sub": {"foo": "bar"}
        }
      }''';
      expect(parseRelayUrls(value, ['sub']), isEmpty);
    });

    test('malformed JSON returns empty', () {
      expect(parseRelayUrls('not json'), isEmpty);
      expect(parseRelayUrls('{}'), isEmpty);
    });

    test('pubkey-keyed nostr.relays', () {
      const value = '''
      {
        "nostr": {
          "names": {"_": "abcd1234"},
          "relays": {
            "abcd1234": ["wss://k.example.com/"]
          }
        }
      }''';
      expect(parseRelayUrls(value), ['wss://k.example.com/']);
    });

    test('deduplicates URLs', () {
      const value = '''
      {
        "relay": "wss://x.example.com/",
        "relays": ["wss://x.example.com/", "wss://y.example.com/"]
      }''';
      expect(parseRelayUrls(value),
          ['wss://x.example.com/', 'wss://y.example.com/']);
    });
  });

  group('parseTlsaRecords', () {
    test('top-level tls array', () {
      const value = '''
      {"tls": [[3,1,1,"aGVsbG8="], [2,0,2,"d29ybGQ="]]}''';
      final records = parseTlsaRecords(value);
      expect(records, hasLength(2));
      expect(records[0].usage, TlsaUsage.daneEe);
      expect(records[1].usage, TlsaUsage.daneTa);
    });

    test('skips malformed entries', () {
      const value = '''
      {"tls": [[3,1,1,"aGVsbG8="], "not-an-array", [3,1], [3,1,1,""]]}''';
      final records = parseTlsaRecords(value);
      expect(records, hasLength(1));
    });

    test('subdomain walk: tls at child', () {
      const value = '''
      {
        "tls": [[3,1,1,"cGFyZW50"]],
        "map": {
          "relay": {"tls": [[3,1,1,"Y2hpbGQ="]]}
        }
      }''';
      final parent = parseTlsaRecords(value);
      final child = parseTlsaRecords(value, ['relay']);
      expect(parent.first.associationDataBase64, 'cGFyZW50');
      expect(child.first.associationDataBase64, 'Y2hpbGQ=');
    });

    test('subdomain walk: ancestor tls does NOT leak', () {
      const value = '''
      {
        "tls": [[3,1,1,"cGFyZW50"]],
        "map": {
          "sub": {"foo": "bar"}
        }
      }''';
      expect(parseTlsaRecords(value, ['sub']), isEmpty);
    });

    test('absent tls returns empty', () {
      expect(parseTlsaRecords('{"foo":"bar"}'), isEmpty);
    });

    test('non-array tls returns empty', () {
      expect(parseTlsaRecords('{"tls":"not-an-array"}'), isEmpty);
    });
  });

  group('parseTorEndpoints', () {
    test('tor as string promotes to ws://...onion/', () {
      const value = '{"tor":"abc123.onion"}';
      expect(parseTorEndpoints(value), ['ws://abc123.onion/']);
    });

    test('tor as array of strings', () {
      const value = '{"tor":["abc123.onion","def456.onion"]}';
      expect(parseTorEndpoints(value),
          ['ws://abc123.onion/', 'ws://def456.onion/']);
    });

    test('pre-formed ws://...onion/ passes through', () {
      const value = '{"tor":"ws://abc.onion/path"}';
      expect(parseTorEndpoints(value), ['ws://abc.onion/path']);
    });

    test('_tor.txt shape (matches d/testls live record)', () {
      const value = '{"_tor":{"txt":"abc.onion"}}';
      expect(parseTorEndpoints(value), ['ws://abc.onion/']);
    });

    test('non-onion strings dropped', () {
      const value = '{"tor":["wss://not-onion.example.com/","abc.onion"]}';
      expect(parseTorEndpoints(value), ['ws://abc.onion/']);
    });

    test('multi-label .onion REJECTED', () {
      const value = '{"tor":"evil.legit.onion"}';
      expect(parseTorEndpoints(value), isEmpty);
    });

    test('subdomain walk: tor at child', () {
      const value = '''
      {
        "map": {
          "relay": {"tor": "child.onion"}
        }
      }''';
      expect(parseTorEndpoints(value, ['relay']), ['ws://child.onion/']);
    });

    test('subdomain walk: ancestor tor does NOT leak', () {
      const value = '{"tor":"parent.onion","map":{"sub":{"foo":"bar"}}}';
      expect(parseTorEndpoints(value, ['sub']), isEmpty);
    });

    test('rejects empty label', () {
      const value = '{"tor":".onion"}';
      expect(parseTorEndpoints(value), isEmpty);
    });
  });
}
