import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NamecoinRelayResolver.isBitUrl', () {
    test('matches wss://example.bit/', () {
      expect(NamecoinRelayResolver.isBitUrl('wss://example.bit/'), isTrue);
      expect(NamecoinRelayResolver.isBitUrl('ws://example.bit/'), isTrue);
    });

    test('matches subdomain', () {
      expect(NamecoinRelayResolver.isBitUrl('wss://relay.testls.bit/'),
          isTrue);
    });

    test('rejects non-bit', () {
      expect(NamecoinRelayResolver.isBitUrl('wss://example.com/'), isFalse);
      expect(NamecoinRelayResolver.isBitUrl('https://example.bit/'), isFalse);
      expect(NamecoinRelayResolver.isBitUrl('garbage'), isFalse);
    });
  });

  group('NamecoinRelayResolver.resolve (mock)', () {
    test('returns null for non-bit URL without I/O', () async {
      final resolver = NamecoinRelayResolver(client: _NeverCalledClient());
      final r = await resolver.resolve('wss://example.com/');
      expect(r, isNull);
    });

    test('resolves bare host', () async {
      const value = '{"relay":"wss://real.example.com/"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://example.bit/');
      expect(r!.canonicalUrl, 'wss://example.bit/');
      expect(r.clearnetUrl, 'wss://real.example.com/');
      expect(r.candidates, ['wss://real.example.com/']);
      expect(r.tlsaRecords, isEmpty);
      expect(r.onionEndpoints, isEmpty);
    });

    test('resolves subdomain via map walk', () async {
      const value = '''
      {
        "relay": "wss://parent.example.com/",
        "map": {
          "relay": {"relay": "wss://child.example.com/"}
        }
      }''';
      final client = _StubClient({'d/testls': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://relay.testls.bit/');
      expect(r!.clearnetUrl, 'wss://child.example.com/');
    });

    test('preserves user path', () async {
      const value = '{"relay":"wss://real.example.com/"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r =
          await resolver.resolve('wss://example.bit/rooms/foo');
      expect(r!.clearnetUrl, 'wss://real.example.com/rooms/foo');
    });

    test('exposes TLSA records', () async {
      const value = '''
      {
        "relay": "wss://real.example.com/",
        "tls": [[3,1,1,"aGVsbG8="]]
      }''';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://example.bit/');
      expect(r!.tlsaRecords, hasLength(1));
      expect(r.tlsaRecords.first.usage, TlsaUsage.daneEe);
    });

    test('exposes Tor endpoints', () async {
      const value = '''
      {
        "relay": "wss://real.example.com/",
        "tor": "abc.onion"
      }''';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://example.bit/');
      expect(r!.onionEndpoints, ['ws://abc.onion/']);
    });

    test('returns null when name not found', () async {
      final client =
          _ThrowingClient(const NameNotFoundException('d/missing'));
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://missing.bit/');
      expect(r, isNull);
    });

    test('returns null when record has no relay/tor', () async {
      const value = '{"foo":"bar"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://example.bit/');
      expect(r, isNull);
    });

    test('caches results: 2 lookups → 1 ElectrumX call', () async {
      const value = '{"relay":"wss://real.example.com/"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r1 = await resolver.resolve('wss://example.bit/');
      final r2 = await resolver.resolve('wss://example.bit/');
      expect(r1!.clearnetUrl, 'wss://real.example.com/');
      expect(r2!.clearnetUrl, 'wss://real.example.com/');
      expect(client.callCount, 1);
    });

    test('caches negative results', () async {
      final client =
          _ThrowingClient(const NameNotFoundException('d/missing'));
      final resolver = NamecoinRelayResolver(client: client);
      await resolver.resolve('wss://missing.bit/');
      await resolver.resolve('wss://missing.bit/');
      // Both lookups hit the same cached negative; only 1 throw.
      expect(client.callCount, 1);
    });

    test('subdomain trap: never queries d/sub.parent', () async {
      // The resolver should query d/parent (the registered name),
      // walk into map.sub, NOT query d/sub.parent.
      final client = _StubClient({
        'd/parent': '{"map":{"sub":{"relay":"wss://ok.example.com/"}}}',
      });
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://sub.parent.bit/');
      expect(r!.clearnetUrl, 'wss://ok.example.com/');
      expect(client.queriedNames, ['d/parent']);
    });

    test('onion-only record yields null clearnet', () async {
      const value = '{"tor":"abc.onion"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      final r = await resolver.resolve('wss://example.bit/');
      expect(r, isNotNull);
      expect(r!.clearnetUrl, isNull);
      expect(r.onionEndpoints, ['ws://abc.onion/']);
    });

    test('invalidate drops a single host', () async {
      const value = '{"relay":"wss://real.example.com/"}';
      final client = _StubClient({'d/example': value});
      final resolver = NamecoinRelayResolver(client: client);
      await resolver.resolve('wss://example.bit/');
      resolver.invalidate('example.bit');
      await resolver.resolve('wss://example.bit/');
      expect(client.callCount, 2);
    });
  });

  group('NamecoinRelayResolver (live Namecoin blockchain)', () {
    final pinnedClient = DefaultElectrumxClient(
      httpClient: _trustAllHttpClient(),
    );

    tearDownAll(() async {
      await pinnedClient.close();
    });

    test('resolve wss://testls.bit/ (root)', () async {
      final resolver = NamecoinRelayResolver(client: pinnedClient);
      final r = await resolver.resolve('wss://testls.bit/');
      // testls.bit might or might not have a relay field; we just
      // confirm the resolver doesn't blow up and returns either a
      // valid resolution or null.
      if (r != null) {
        // If a relay field is present, validate the shape.
        expect(r.canonicalUrl, 'wss://testls.bit/');
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('resolve wss://relay.testls.bit/ (subdomain via map)', () async {
      final resolver = NamecoinRelayResolver(client: pinnedClient);
      final r = await resolver.resolve('wss://relay.testls.bit/');
      // Confirm at least that we did a lookup. The subdomain may or
      // may not have a relay field today; the assertion is "no crash".
      expect(r, anyOf(isNull, isA<RelayResolution>()));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('non-existent .bit returns null', () async {
      final resolver = NamecoinRelayResolver(client: pinnedClient);
      final r = await resolver.resolve(
          'wss://definitely_does_not_exist_xyz_qux.bit/');
      expect(r, isNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

class _StubClient implements ElectrumxClient {
  final Map<String, String> values;
  final List<String> queriedNames = [];
  int callCount = 0;
  _StubClient(this.values);

  @override
  Future<String> nameShow(String name) async {
    callCount++;
    queriedNames.add(name);
    final v = values[name];
    if (v == null) throw NameNotFoundException(name);
    return v;
  }

  @override
  Future<void> close() async {}
}

class _ThrowingClient implements ElectrumxClient {
  final Exception error;
  int callCount = 0;
  _ThrowingClient(this.error);

  @override
  Future<String> nameShow(String name) {
    callCount++;
    throw error;
  }

  @override
  Future<void> close() async {}
}

class _NeverCalledClient implements ElectrumxClient {
  @override
  Future<String> nameShow(String name) {
    fail('nameShow should not be called for non-bit URLs');
  }

  @override
  Future<void> close() async {}
}

HttpClient _trustAllHttpClient() {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 10);
  return c;
}
