import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final vectors = jsonDecode(
    File('test/fixtures/rust_nostr_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final nip98 = vectors['nip98'] as Map<String, dynamic>;

  group('NIP-98 HTTP Auth', () {
    test('creates a GET auth event', () {
      final event = HttpAuth.create(
        url: 'https://example.com/api/resource',
        method: 'GET',
        secretKey: secretKey,
      );

      expect(event.kind, 27235);
      expect(event.content, '');
      expect(findTagValue(event.tags, 'u'),
          'https://example.com/api/resource');
      expect(findTagValue(event.tags, 'method'), 'GET');
      expect(findTagValue(event.tags, 'payload'), isNull);
    });

    test('creates a POST auth event with payload', () {
      final body = utf8.encode('{"data": "value"}');
      final hash = HttpAuth.payloadHash(body);

      final event = HttpAuth.create(
        url: 'https://example.com/api/upload',
        method: 'POST',
        secretKey: secretKey,
        payload: hash,
      );

      expect(findTagValue(event.tags, 'method'), 'POST');
      expect(findTagValue(event.tags, 'payload'), hash);
    });

    test('method is uppercased', () {
      final event = HttpAuth.create(
        url: 'https://example.com/',
        method: 'post',
        secretKey: secretKey,
      );
      expect(findTagValue(event.tags, 'method'), 'POST');
    });

    test('toAuthHeader produces Nostr <base64> format', () {
      final event = HttpAuth.create(
        url: 'https://example.com/',
        method: 'GET',
        secretKey: secretKey,
      );

      final header = HttpAuth.toAuthHeader(event);
      expect(header, startsWith('Nostr '));

      // Decode and verify it round-trips
      final b64 = header.substring(6);
      final decoded = utf8.decode(base64.decode(b64));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      expect(json['kind'], 27235);
    });

    test('parse extracts all fields', () {
      final body = utf8.encode('test');
      final hash = HttpAuth.payloadHash(body);

      final event = HttpAuth.create(
        url: 'https://example.com/upload',
        method: 'PUT',
        secretKey: secretKey,
        payload: hash,
      );

      final data = HttpAuth.parse(event);
      expect(data.url, 'https://example.com/upload');
      expect(data.method, 'PUT');
      expect(data.payload, hash);
      expect(data.pubkey, event.pubkey);
    });

    test('parse throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['u', 'https://example.com/'],
          ['method', 'GET'],
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => HttpAuth.parse(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('parse throws on missing u tag', () {
      final event = Event.from(
        kind: 27235,
        tags: [
          ['method', 'GET'],
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => HttpAuth.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('parse throws on missing method tag', () {
      final event = Event.from(
        kind: 27235,
        tags: [
          ['u', 'https://example.com/'],
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => HttpAuth.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('validate passes for a fresh valid event', () {
      final event = HttpAuth.create(
        url: 'https://example.com/api',
        method: 'GET',
        secretKey: secretKey,
      );

      // Should not throw
      HttpAuth.validate(
        event: event,
        url: 'https://example.com/api',
        method: 'GET',
      );
    });

    test('validate fails on URL mismatch', () {
      final event = HttpAuth.create(
        url: 'https://example.com/api',
        method: 'GET',
        secretKey: secretKey,
      );

      expect(
        () => HttpAuth.validate(
          event: event,
          url: 'https://other.com/api',
          method: 'GET',
        ),
        throwsA(isA<NostrException>()),
      );
    });

    test('validate fails on method mismatch', () {
      final event = HttpAuth.create(
        url: 'https://example.com/api',
        method: 'GET',
        secretKey: secretKey,
      );

      expect(
        () => HttpAuth.validate(
          event: event,
          url: 'https://example.com/api',
          method: 'POST',
        ),
        throwsA(isA<NostrException>()),
      );
    });

    test('validate checks payload hash', () {
      final body = utf8.encode('request body');
      final hash = HttpAuth.payloadHash(body);

      final event = HttpAuth.create(
        url: 'https://example.com/upload',
        method: 'POST',
        secretKey: secretKey,
        payload: hash,
      );

      // Correct body — should pass
      HttpAuth.validate(
        event: event,
        url: 'https://example.com/upload',
        method: 'POST',
        body: body,
      );

      // Wrong body — should fail
      expect(
        () => HttpAuth.validate(
          event: event,
          url: 'https://example.com/upload',
          method: 'POST',
          body: utf8.encode('different body'),
        ),
        throwsA(isA<NostrException>()),
      );
    });

    test('payloadHash produces consistent SHA256 hex', () {
      final body = utf8.encode('hello world');
      final hash = HttpAuth.payloadHash(body);
      // Known SHA256 of "hello world"
      expect(hash,
          'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9');
    });

    test('fromAuthHeader round-trips with toAuthHeader', () {
      final event = HttpAuth.create(
        url: 'https://example.com/api',
        method: 'GET',
        secretKey: secretKey,
      );

      final header = HttpAuth.toAuthHeader(event);
      final decoded = HttpAuth.fromAuthHeader(header);

      expect(decoded.kind, 27235);
      expect(decoded.id, event.id);
      expect(decoded.pubkey, event.pubkey);
      expect(findTagValue(decoded.tags, 'u'), 'https://example.com/api');
      expect(findTagValue(decoded.tags, 'method'), 'GET');
    });

    test('fromAuthHeader works with just base64 (no Nostr prefix)', () {
      final event = HttpAuth.create(
        url: 'https://example.com/',
        method: 'POST',
        secretKey: secretKey,
      );

      final header = HttpAuth.toAuthHeader(event);
      final b64Only = header.substring(6); // strip "Nostr "
      final decoded = HttpAuth.fromAuthHeader(b64Only);

      expect(decoded.kind, 27235);
      expect(decoded.id, event.id);
    });

    test('fromAuthHeader throws on invalid base64', () {
      expect(
        () => HttpAuth.fromAuthHeader('Nostr not-valid-base64!!!'),
        throwsA(isA<NostrException>()),
      );
    });

    test('fromAuthHeader throws on invalid JSON', () {
      final b64 = base64.encode(utf8.encode('not json'));
      expect(
        () => HttpAuth.fromAuthHeader('Nostr $b64'),
        throwsA(isA<NostrException>()),
      );
    });

    test('typedef Nip98 works', () {
      final event = Nip98.create(
        url: 'https://example.com/',
        method: 'GET',
        secretKey: secretKey,
      );
      expect(event.kind, 27235);
    });

    group('rust-nostr vectors', () {
      test('fromAuthHeader decodes valid auth header', () {
        final header = nip98['valid_auth_header'] as String;
        final event = HttpAuth.fromAuthHeader(header);
        final v = nip98['valid_event'] as Map<String, dynamic>;

        expect(event.id, v['id']);
        expect(event.pubkey, v['pubkey']);
        expect(event.kind, v['kind']);
        expect(event.createdAt, v['created_at']);
        expect(event.content, v['content']);
        expect(findTagValue(event.tags, 'u'), v['tags'][0][1]);
        expect(findTagValue(event.tags, 'method'), v['tags'][1][1]);
      });

      test('fromAuthHeader parses fields correctly', () {
        final header = nip98['valid_auth_header'] as String;
        final event = HttpAuth.fromAuthHeader(header);
        final data = HttpAuth.parse(event);

        expect(data.url, 'https://api.snort.social/api/v1/n5sp/list');
        expect(data.method, 'GET');
        expect(data.payload, isNull);
        expect(data.pubkey,
            '63fe6318dc58583cfe16810f86dd09e18bfd76aabc24a0081ce2856f330504ed');
      });

      test('fromAuthHeader rejects lowercase nostr prefix', () {
        final header = nip98['lowercase_prefix_header'] as String;
        expect(
          () => HttpAuth.fromAuthHeader(header),
          throwsA(isA<NostrException>()),
        );
      });

      test('validate rejects too-old event (rust-nostr vector)', () {
        final header = nip98['valid_auth_header'] as String;
        final event = HttpAuth.fromAuthHeader(header);

        // event.createdAt = 1682327852, simulate "now" = 1777777777
        // delta = 95449925 seconds >> 60 second window
        expect(
          () => HttpAuth.validate(
            event: event,
            url: 'https://api.snort.social/api/v1/n5sp/list',
            method: 'GET',
          ),
          throwsA(isA<NostrException>()),
        );
      });

      test('validate rejects URL/method mismatch (rust-nostr vector)', () {
        final header = nip98['valid_auth_header'] as String;
        final event = HttpAuth.fromAuthHeader(header);

        // Event URL is snort API, but we check against example.com + POST
        expect(
          () => HttpAuth.validate(
            event: event,
            url: 'https://example.com/',
            method: 'POST',
            // Bypass time check with huge window
            pastWindowSeconds: 999999999,
          ),
          throwsA(isA<NostrException>()),
        );
      });

      test('valid_auth_header_2 round-trips correctly', () {
        final v2 = nip98['valid_auth_header_2'] as Map<String, dynamic>;
        final header = v2['header'] as String;
        final event = HttpAuth.fromAuthHeader(header);

        expect(event.id, v2['event_id']);
        expect(event.pubkey, v2['pubkey']);
        expect(event.createdAt, v2['created_at']);
        expect(event.kind, 27235);
        expect(findTagValue(event.tags, 'u'), v2['url']);
        expect(findTagValue(event.tags, 'method'), v2['method']);
      });
    });
  });
}
