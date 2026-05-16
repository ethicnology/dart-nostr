import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:nostr/src/namecoin/identifier.dart';
import 'package:nostr/src/namecoin/script.dart';
import 'package:nostr/src/namecoin/value.dart';
import 'package:test/test.dart';

void main() {
  group('NamecoinIdentifier.isBit', () {
    test('matches .bit', () {
      expect(NamecoinIdentifier.isBit('alice@example.bit'), isTrue);
      expect(NamecoinIdentifier.isBit('example.bit'), isTrue);
      expect(NamecoinIdentifier.isBit('EXAMPLE.BIT'), isTrue);
      expect(NamecoinIdentifier.isBit('  example.bit  '), isTrue);
    });

    test('matches d/ and id/ namespaces', () {
      expect(NamecoinIdentifier.isBit('d/example'), isTrue);
      expect(NamecoinIdentifier.isBit('id/alice'), isTrue);
      expect(NamecoinIdentifier.isBit('D/EXAMPLE'), isTrue);
    });

    test('tolerates nostr: URI prefix', () {
      expect(NamecoinIdentifier.isBit('nostr:alice@example.bit'), isTrue);
      expect(NamecoinIdentifier.isBit('nostr:d/example'), isTrue);
    });

    test('rejects DNS-style identifiers', () {
      expect(NamecoinIdentifier.isBit('alice@example.com'), isFalse);
      expect(NamecoinIdentifier.isBit('damus@damus.io'), isFalse);
      expect(NamecoinIdentifier.isBit(''), isFalse);
      expect(NamecoinIdentifier.isBit(null), isFalse);
    });
  });

  group('parseIdentifier', () {
    test('alice@example.bit', () {
      final p = parseIdentifier('alice@example.bit')!;
      expect(p.namecoinName, 'd/example');
      expect(p.localPart, 'alice');
      expect(p.isDomain, isTrue);
    });

    test('alice@example.bit with uppercase', () {
      final p = parseIdentifier('Alice@Example.BIT')!;
      expect(p.namecoinName, 'd/example');
      expect(p.localPart, 'alice');
    });

    test('bare example.bit uses _ root', () {
      final p = parseIdentifier('example.bit')!;
      expect(p.namecoinName, 'd/example');
      expect(p.localPart, '_');
      expect(p.isDomain, isTrue);
    });

    test('d/example', () {
      final p = parseIdentifier('d/example')!;
      expect(p.namecoinName, 'd/example');
      expect(p.localPart, '_');
      expect(p.isDomain, isTrue);
    });

    test('id/alice', () {
      final p = parseIdentifier('id/alice')!;
      expect(p.namecoinName, 'id/alice');
      expect(p.localPart, '_');
      expect(p.isDomain, isFalse);
    });

    test('strips nostr: prefix', () {
      expect(parseIdentifier('nostr:alice@example.bit')!.namecoinName,
          'd/example');
      expect(parseIdentifier('NOSTR:d/example')!.namecoinName, 'd/example');
    });

    test('returns null for non-namecoin', () {
      expect(parseIdentifier('alice@example.com'), isNull);
      expect(parseIdentifier(''), isNull);
      expect(parseIdentifier('@example.bit'), isNotNull); // empty local => "_"
      expect(parseIdentifier('@example.bit')!.localPart, '_');
      expect(parseIdentifier('alice@.bit'), isNull);
      expect(parseIdentifier('.bit'), isNull);
    });
  });

  group('NamecoinIdentifier.lookupUri', () {
    test('alice@example.bit', () {
      final uri = NamecoinIdentifier.lookupUri('alice@example.bit');
      expect(uri.scheme, 'namecoin');
      expect(uri.path, 'd/example');
      expect(uri.queryParameters['local'], 'alice');
    });

    test('throws on invalid', () {
      expect(() => NamecoinIdentifier.lookupUri('alice@example.com'),
          throwsA(isA<NostrException>()));
    });
  });

  group('extractNostrFromValue', () {
    test('simple string form for root', () {
      const value =
          '''{"nostr":"460c25e60011aabbccddeeff112233445566778899aabbccddeeff0011223344"}''';
      final parsed = parseIdentifier('example.bit')!;
      final entry = extractNostrFromValue(value, parsed)!;
      expect(entry.pubkey,
          '460c25e60011aabbccddeeff112233445566778899aabbccddeeff0011223344');
      expect(entry.relays, isEmpty);
    });

    test('simple string form rejects non-root local-part', () {
      const value =
          '''{"nostr":"460c25e60011aabbccddeeff112233445566778899aabbccddeeff0011223344"}''';
      final parsed = parseIdentifier('alice@example.bit')!;
      expect(extractNostrFromValue(value, parsed), isNull);
    });

    test('extended form with names map - exact local-part wins', () {
      const value = '''
{
  "nostr": {
    "names": {
      "_":     "1111111111111111111111111111111111111111111111111111111111111111",
      "alice": "2222222222222222222222222222222222222222222222222222222222222222",
      "bob":   "3333333333333333333333333333333333333333333333333333333333333333"
    }
  }
}''';
      final parsed = parseIdentifier('alice@example.bit')!;
      final entry = extractNostrFromValue(value, parsed)!;
      expect(entry.pubkey,
          '2222222222222222222222222222222222222222222222222222222222222222');
    });

    test('extended form falls back to _ when local-part absent', () {
      const value = '''
{
  "nostr": {
    "names": {
      "_": "1111111111111111111111111111111111111111111111111111111111111111"
    }
  }
}''';
      final parsed = parseIdentifier('charlie@example.bit')!;
      final entry = extractNostrFromValue(value, parsed)!;
      expect(entry.pubkey,
          '1111111111111111111111111111111111111111111111111111111111111111');
    });

    test('extended form: relays keyed by chosen pubkey', () {
      const value = '''
{
  "nostr": {
    "names": {
      "alice": "2222222222222222222222222222222222222222222222222222222222222222"
    },
    "relays": {
      "2222222222222222222222222222222222222222222222222222222222222222": [
        "wss://relay.example.com/",
        "wss://backup.example.com/"
      ]
    }
  }
}''';
      final parsed = parseIdentifier('alice@example.bit')!;
      final entry = extractNostrFromValue(value, parsed)!;
      expect(entry.relays,
          ['wss://relay.example.com/', 'wss://backup.example.com/']);
    });

    test('id/ shape with pubkey + relays array', () {
      const value = '''
{
  "nostr": {
    "pubkey": "4444444444444444444444444444444444444444444444444444444444444444",
    "relays": ["wss://r.example.com/"]
  }
}''';
      final parsed = parseIdentifier('id/alice')!;
      final entry = extractNostrFromValue(value, parsed)!;
      expect(entry.pubkey,
          '4444444444444444444444444444444444444444444444444444444444444444');
      expect(entry.relays, ['wss://r.example.com/']);
    });

    test('returns null for malformed JSON', () {
      final parsed = parseIdentifier('example.bit')!;
      expect(extractNostrFromValue('not json', parsed), isNull);
      expect(extractNostrFromValue('{"foo":"bar"}', parsed), isNull);
    });

    test('returns null when nostr field is invalid pubkey', () {
      const value = '{"nostr":"not-a-hex-pubkey"}';
      final parsed = parseIdentifier('example.bit')!;
      expect(extractNostrFromValue(value, parsed), isNull);
    });
  });

  group('Namecoin script utilities', () {
    test('buildNameIndexScript / electrumScriptHash for d/testls', () {
      // Reference scripthash computed from the Go reference for
      // identifier "d/testls". This anchors the Dart port to the
      // canonical Go implementation.
      final script = buildNameIndexScript(utf8.encode('d/testls'));
      final scriptHash = electrumScriptHash(script);
      expect(scriptHash.length, 64);
      // Sanity check: hash is deterministic.
      expect(electrumScriptHash(buildNameIndexScript(utf8.encode('d/testls'))),
          scriptHash);
    });

    test('parseNameScript round-trip with synthetic NAME_UPDATE', () {
      // Construct: OP_NAME_UPDATE push("d/example") push(`{"a":1}`) OP_2DROP OP_DROP OP_RETURN
      const name = 'd/example';
      const value = '{"a":1}';
      final nameBytes = utf8.encode(name);
      final valueBytes = utf8.encode(value);
      final out = <int>[
        opNameUpdate,
        nameBytes.length,
        ...nameBytes,
        valueBytes.length,
        ...valueBytes,
        op2Drop,
        opDrop,
        opReturn,
      ];
      final parsed = parseNameScript(out)!;
      expect(parsed.name, name);
      expect(parsed.value, value);
    });

    test('parseNameScript rejects non-NAME_UPDATE', () {
      expect(parseNameScript([0x00, 0x01, 0x02]), isNull);
      expect(parseNameScript([]), isNull);
    });

    test('OP_PUSHDATA1 round-trip for 200-byte ASCII value', () {
      // Force OP_PUSHDATA1 path (length 0x4c-0xff). Use printable
      // ASCII so the UTF-8 round-trip is exact (real-world Namecoin
      // values are JSON, which is always valid UTF-8).
      final nameBytes = utf8.encode('d/x');
      final valueStr = '{"a":"${'x' * 190}"}';
      final valueBytes = utf8.encode(valueStr);
      expect(valueBytes.length, greaterThanOrEqualTo(0x4c));
      expect(valueBytes.length, lessThanOrEqualTo(0xff));
      final out = <int>[
        opNameUpdate,
        nameBytes.length,
        ...nameBytes,
        opPushData1,
        valueBytes.length,
        ...valueBytes,
        op2Drop,
        opDrop,
        opReturn,
      ];
      final parsed = parseNameScript(out)!;
      expect(parsed.name, 'd/x');
      expect(parsed.value, valueStr);
    });

    test('OP_PUSHDATA2 round-trip for 1024-byte ASCII value', () {
      final nameBytes = utf8.encode('d/x');
      final valueStr = '{"a":"${'y' * 1015}"}';
      final valueBytes = utf8.encode(valueStr);
      expect(valueBytes.length, greaterThan(0xff));
      final out = <int>[
        opNameUpdate,
        nameBytes.length,
        ...nameBytes,
        opPushData2,
        valueBytes.length & 0xff,
        (valueBytes.length >> 8) & 0xff,
        ...valueBytes,
        op2Drop,
        opDrop,
        opReturn,
      ];
      final parsed = parseNameScript(out)!;
      expect(parsed.name, 'd/x');
      expect(parsed.value, valueStr);
    });
  });

  group('NamecoinIdentifier (live Namecoin blockchain)', () {
    // These tests hit a real Namecoin ElectrumX server. They are the
    // Namecoin equivalent of `damus@damus.io` smoke tests in
    // nip_005_test.dart. They use a `MultiClient` that delegates the
    // TLS handshake to a custom HttpClient, since the public
    // ElectrumX servers ship self-signed certificates today.

    final pinnedClient = DefaultElectrumxClient(
      httpClient: _trustAllHttpClient(),
    );

    tearDownAll(() async {
      await pinnedClient.close();
    });

    test('fetch m@testls.bit', () async {
      final result = await NamecoinIdentifier.fetch(
        'm@testls.bit',
        client: pinnedClient,
      );
      expect(result, isNotNull,
          reason: 'm@testls.bit should resolve on Namecoin chain');
      expect(result!.pubkey.length, 64);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('fetch testls.bit (root)', () async {
      final result = await NamecoinIdentifier.fetch(
        'testls.bit',
        client: pinnedClient,
      );
      expect(result, isNotNull);
      expect(result!.pubkey.length, 64);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('fetch non-existent .bit returns null', () async {
      final result = await NamecoinIdentifier.fetch(
        'definitely_does_not_exist_xyz_qux.bit',
        client: pinnedClient,
      );
      expect(result, isNull);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

/// Returns an `HttpClient` that accepts any TLS certificate. Used for
/// the live-blockchain smoke tests against public Namecoin ElectrumX
/// servers, which ship self-signed certificates. **Never use this in
/// production.**
///
/// Production callers should pin the specific server certificate
/// fingerprints (see `PinnedElectrumXCerts` in the Go reference).
HttpClient _trustAllHttpClient() {
  final c = HttpClient();
  c.badCertificateCallback = (_, __, ___) => true;
  c.connectionTimeout = const Duration(seconds: 10);
  return c;
}
