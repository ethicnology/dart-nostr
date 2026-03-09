import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip089', () {
    const String secretKey =
        '826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8';

    group('handler info', () {
      test('encodes a handler info event with all fields', () {
        final event = Nip89.handlerInfo(
          id: 'my-app',
          secretKey: secretKey,
          supportedKinds: [1, 30023],
          platforms: [
            const PlatformHandler(
              platform: 'web',
              url: 'https://app.example.com/<bech32>',
              entityType: 'nevent',
            ),
            const PlatformHandler(
              platform: 'ios',
              url: 'myapp://<bech32>',
            ),
          ],
          metadata: {
            'name': 'My App',
            'about': 'A great nostr app',
            'picture': 'https://example.com/logo.png',
          },
        );
        expect(event.kind, 31990);
        expect(findTagValue(event.tags, 'd'), 'my-app');

        final kTags = findAllTagValues(event.tags, 'k');
        expect(kTags, ['1', '30023']);

        final webTag = event.tags.firstWhere((t) => t[0] == 'web');
        expect(webTag[1], 'https://app.example.com/<bech32>');
        expect(webTag[2], 'nevent');

        final iosTag = event.tags.firstWhere((t) => t[0] == 'ios');
        expect(iosTag[1], 'myapp://<bech32>');
        expect(iosTag.length, 2); // no entity type

        final contentMap = json.decode(event.content) as Map<String, dynamic>;
        expect(contentMap['name'], 'My App');
      });

      test('encodes a minimal handler info event', () {
        final event = Nip89.handlerInfo(
          id: 'minimal',
          secretKey: secretKey,
          supportedKinds: [1],
        );
        expect(event.kind, 31990);
        expect(findTagValue(event.tags, 'd'), 'minimal');
        expect(event.content, '');
        expect(event.tags.length, 2); // d + k
      });

      test('decodes a handler info event', () {
        final event = Nip89.handlerInfo(
          id: 'decoder-test',
          secretKey: secretKey,
          supportedKinds: [1, 6, 30023],
          platforms: [
            const PlatformHandler(
              platform: 'web',
              url: 'https://app.com/<bech32>',
              entityType: 'naddr',
            ),
            const PlatformHandler(
              platform: 'android',
              url: 'intent://<bech32>',
            ),
          ],
          metadata: {
            'name': 'Decoder App',
            'picture': 'https://example.com/pic.jpg',
          },
        );
        final handler = Nip89.parseHandlerInfo(event);
        expect(handler.id, 'decoder-test');
        expect(handler.supportedKinds, [1, 6, 30023]);
        expect(handler.platforms.length, 2);
        expect(handler.platforms[0].platform, 'web');
        expect(handler.platforms[0].url, 'https://app.com/<bech32>');
        expect(handler.platforms[0].entityType, 'naddr');
        expect(handler.platforms[1].platform, 'android');
        expect(handler.platforms[1].url, 'intent://<bech32>');
        expect(handler.platforms[1].entityType, isNull);
        expect(handler.metadata, isNotNull);
        expect(handler.metadata!['name'], 'Decoder App');
        expect(handler.pubkey, event.pubkey);
      });

      test('decodes handler with empty content', () {
        final event = Nip89.handlerInfo(
          id: 'no-meta',
          secretKey: secretKey,
          supportedKinds: [1],
        );
        final handler = Nip89.parseHandlerInfo(event);
        expect(handler.metadata, isNull);
      });

      test('decodes handler with invalid content JSON gracefully', () {
        final event = Event.from(
          kind: 31990,
          tags: [
            ['d', 'bad-json'],
            ['k', '1'],
          ],
          content: 'not valid json',
          secretKey: secretKey,
        );
        final handler = Nip89.parseHandlerInfo(event);
        expect(handler.metadata, isNull);
        expect(handler.id, 'bad-json');
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [
            ['d', 'test']
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip89.parseHandlerInfo(event),
            throwsA(isA<InvalidKindException>()));
      });

      test('throws MissingTagException when d tag is absent', () {
        final event = Event.from(
          kind: 31990,
          tags: [],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip89.parseHandlerInfo(event),
            throwsA(isA<MissingTagException>()));
      });

      test('ignores non-integer k tag values', () {
        final event = Event.from(
          kind: 31990,
          tags: [
            ['d', 'test'],
            ['k', '1'],
            ['k', 'not-a-number'],
            ['k', '30023'],
          ],
          content: '',
          secretKey: secretKey,
        );
        final handler = Nip89.parseHandlerInfo(event);
        expect(handler.supportedKinds, [1, 30023]);
      });
    });

    group('handler recommendation', () {
      test('encodes a recommendation event', () {
        final event = Nip89.recommendation(
          eventKind: 1,
          handlerCoords: [
            '31990:pubkey1:app1',
            '31990:pubkey2:app2',
          ],
          secretKey: secretKey,
        );
        expect(event.kind, 31989);
        expect(findTagValue(event.tags, 'd'), '1');
        final aCoords = findAllTagValues(event.tags, 'a');
        expect(aCoords, ['31990:pubkey1:app1', '31990:pubkey2:app2']);
      });

      test('decodes a recommendation event', () {
        final event = Nip89.recommendation(
          eventKind: 30023,
          handlerCoords: ['31990:pubkey:handler'],
          secretKey: secretKey,
        );
        final rec = Nip89.parseRecommendation(event);
        expect(rec.eventKind, 30023);
        expect(rec.handlerCoords, ['31990:pubkey:handler']);
        expect(rec.pubkey, event.pubkey);
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [
            ['d', '1']
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip89.parseRecommendation(event),
            throwsA(isA<InvalidKindException>()));
      });

      test('throws MissingTagException when d tag is absent', () {
        final event = Event.from(
          kind: 31989,
          tags: [],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip89.parseRecommendation(event),
            throwsA(isA<MissingTagException>()));
      });
    });

    test('decode real-world kind 31990 handler info from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['31990'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final handler = Nip89.parseHandlerInfo(event);
      expect(handler.id, isNotEmpty);
      expect(handler.supportedKinds, contains(100));
      expect(handler.metadata, isNotNull);
      expect(handler.metadata!['name'], 'yt-summarizer');
      expect(handler.pubkey, event.pubkey);
    });

    test('typedef AppHandlers works', () {
      final event = AppHandlers.handlerInfo(
        id: 'test',
        secretKey: secretKey,
        supportedKinds: [1],
      );
      expect(event.kind, 31990);
    });
  });
}
