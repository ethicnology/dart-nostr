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

    test('validate fails on URL mismatch with typed exception', () {
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
        throwsA(isA<FieldMismatchException>()
            .having((e) => e.field, 'field', 'url')
            .having((e) => e.expected, 'expected', 'https://other.com/api')
            .having((e) => e.actual, 'actual', 'https://example.com/api')),
      );
    });

    test('validate fails on method mismatch with typed exception', () {
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
        throwsA(isA<FieldMismatchException>()
            .having((e) => e.field, 'field', 'method')),
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

    test('fromAuthHeader throws MalformedAuthHeaderException on bad base64', () {
      expect(
        () => HttpAuth.fromAuthHeader('Nostr not-valid-base64!!!'),
        throwsA(isA<MalformedAuthHeaderException>()
            .having((e) => e.code, 'code', AuthHeaderError.badBase64)),
      );
    });

    test('fromAuthHeader throws MalformedAuthHeaderException on bad JSON', () {
      final b64 = base64.encode(utf8.encode('not json'));
      expect(
        () => HttpAuth.fromAuthHeader('Nostr $b64'),
        throwsA(isA<MalformedAuthHeaderException>()
            .having((e) => e.code, 'code', AuthHeaderError.invalidJson)),
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
      // The rust-nostr `valid_auth_header` fixture is used in rust-nostr's
      // own NEGATIVE test suite — its event id/sig are intentionally not
      // cryptographically valid. We assert that fromAuthHeader rejects it.
      test('fromAuthHeader rejects rust-nostr negative-test vector', () {
        final header = nip98['valid_auth_header'] as String;
        expect(
          () => HttpAuth.fromAuthHeader(header),
          throwsA(isA<NostrException>()),
        );
      });

      test('fromAuthHeader rejects lowercase nostr prefix', () {
        final header = nip98['lowercase_prefix_header'] as String;
        expect(
          () => HttpAuth.fromAuthHeader(header),
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

    group('signature verification', () {
      test('fromAuthHeader rejects tampered signature', () {
        final event = HttpAuth.create(
          url: 'https://example.com/api',
          method: 'GET',
          secretKey: secretKey,
        );

        // Tamper with the sig (flip a hex digit)
        final tampered = Event(
          event.id,
          event.pubkey,
          event.createdAt,
          event.kind,
          event.tags,
          event.content,
          event.sig.replaceRange(0, 1, event.sig[0] == '0' ? '1' : '0'),
          verify: false,
        );

        final header = HttpAuth.toAuthHeader(tampered);
        expect(
          () => HttpAuth.fromAuthHeader(header),
          throwsA(isA<NostrException>()),
        );
      });

      test('fromAuthHeader rejects tampered content', () {
        final event = HttpAuth.create(
          url: 'https://example.com/api',
          method: 'GET',
          secretKey: secretKey,
        );

        // Tamper with content; id will no longer match canonical hash
        final tampered = Event(
          event.id,
          event.pubkey,
          event.createdAt,
          event.kind,
          event.tags,
          'forged content',
          event.sig,
          verify: false,
        );

        final header = HttpAuth.toAuthHeader(tampered);
        expect(
          () => HttpAuth.fromAuthHeader(header),
          throwsA(isA<NostrException>()),
        );
      });

      test('validate rejects an event built with verify:false bypass', () {
        // Build an event with someone else's pubkey but our own (wrong) sig.
        // This is the impersonation case the docstring promise must prevent.
        final realEvent = HttpAuth.create(
          url: 'https://example.com/api',
          method: 'GET',
          secretKey: secretKey,
        );
        final forged = Event(
          realEvent.id,
          // Different pubkey — anyone can claim this
          '0000000000000000000000000000000000000000000000000000000000000001',
          realEvent.createdAt,
          realEvent.kind,
          realEvent.tags,
          realEvent.content,
          realEvent.sig,
          verify: false,
        );

        expect(
          () => HttpAuth.validate(
            event: forged,
            url: 'https://example.com/api',
            method: 'GET',
          ),
          throwsA(isA<NostrException>()),
        );
      });
    });
  });
}
