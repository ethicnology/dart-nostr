// Covers the `parse(event, permissive: true)` fallback added in v2.1.
// Real-world relays publish events that are missing spec-required tags
// (~31 % of NIP-94 file metadata on prod relays, ~3 % of NIP-29 group
// metadata). Strict mode throws `MissingTagException` so authors don't
// silently consume garbage; permissive mode records the missing tag in
// `missingTags` so consumers (timeline display, debug viewers, archival)
// can extract whatever's salvageable.

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const _secret =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

Event _build(int kind, List<List<String>> tags) =>
    Event.from(kind: kind, tags: tags, content: '', secretKey: _secret);

void main() {
  group('NIP-94 FileMetadata.parse permissive', () {
    test('strict throws on missing x', () {
      final event = _build(1063, [
        ['url', 'https://example.com/a.png'],
        ['m', 'image/png'],
      ]);
      expect(() => FileMetadata.parse(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'x')));
    });

    test('permissive surfaces x as missing instead of throwing', () {
      final event = _build(1063, [
        ['url', 'https://example.com/a.png'],
        ['m', 'image/png'],
      ]);
      final data = FileMetadata.parse(event, permissive: true);
      expect(data.sha256, '');
      expect(data.url, 'https://example.com/a.png');
      expect(data.missingTags, {'x'});
      expect(data.isComplete, isFalse);
    });

    test('permissive on fully missing event collects all three', () {
      final event = _build(1063, []);
      final data = FileMetadata.parse(event, permissive: true);
      expect(data.missingTags, {'url', 'm', 'x'});
      expect(data.isComplete, isFalse);
    });

    test('permissive on well-formed event leaves missingTags empty', () {
      final event = _build(1063, [
        ['url', 'https://example.com/a.png'],
        ['m', 'image/png'],
        ['x', 'abc'],
      ]);
      final data = FileMetadata.parse(event, permissive: true);
      expect(data.missingTags, isEmpty);
      expect(data.isComplete, isTrue);
    });
  });

  group('NIP-29 Group.parseMetadata permissive', () {
    test('strict throws on missing d', () {
      final event = _build(39000, [
        ['name', 'g'],
      ]);
      expect(() => Group.parseMetadata(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'd')));
    });

    test('permissive returns empty groupId + records d as missing', () {
      final event = _build(39000, [
        ['name', 'g'],
      ]);
      final data = Group.parseMetadata(event, permissive: true);
      expect(data.groupId, '');
      expect(data.name, 'g');
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-22 Comment.parse permissive', () {
    test('strict throws on missing root scope', () {
      final event = _build(1111, [
        ['e', 'parent-id'],
        ['k', '1'],
        ['K', '1'],
      ]);
      expect(() => Comment.parse(event),
          throwsA(isA<MissingTagException>()
              .having((e) => e.tag, 'tag', 'E/A/I')));
    });

    test('permissive surfaces all missing tag groups', () {
      final event = _build(1111, []);
      final data = Comment.parse(event, permissive: true);
      expect(data.missingTags, {'E/A/I', 'e/a/i', 'K', 'k'});
      expect(data.isComplete, isFalse);
      expect(data.rootKind, isNull);
      expect(data.parentKind, isNull);
    });
  });

  group('NIP-58 Badge.parseAward permissive', () {
    test('strict throws on missing a tag', () {
      final event = _build(8, [
        ['p', 'awardee'],
      ]);
      expect(() => Badge.parseAward(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'a')));
    });

    test('strict throws on empty awardees', () {
      final event = _build(8, [
        ['a', '30009:author:badge'],
      ]);
      expect(() => Badge.parseAward(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'p')));
    });

    test('permissive captures both missing tags', () {
      final event = _build(8, []);
      final data = Badge.parseAward(event, permissive: true);
      expect(data.missingTags, {'a', 'p'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-72 ModeratedCommunity.parseApproval permissive', () {
    test('strict throws on missing a tag', () {
      final event = _build(4550, [
        ['p', 'author'],
        ['k', '1'],
      ]);
      expect(() => ModeratedCommunity.parseApproval(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'a')));
    });

    test('permissive returns empty communityCoord with a flagged missing', () {
      final event = _build(4550, [
        ['p', 'author'],
      ]);
      final data = ModeratedCommunity.parseApproval(event, permissive: true);
      expect(data.communityCoord, '');
      expect(data.missingTags, {'a'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-72 ModeratedCommunity.parseCommunity permissive', () {
    test('strict throws on missing d', () {
      final event = _build(34550, [
        ['name', 'g'],
      ]);
      expect(() => ModeratedCommunity.parseCommunity(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'd')));
    });

    test('permissive surfaces missing d and keeps the rest', () {
      final event = _build(34550, [
        ['name', 'g'],
        ['description', 'a desc'],
      ]);
      final data = ModeratedCommunity.parseCommunity(event, permissive: true);
      expect(data.id, '');
      expect(data.name, 'g');
      expect(data.description, 'a desc');
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-58 Badge.parseDefinition permissive', () {
    test('strict throws on missing d', () {
      final event = _build(30009, [
        ['name', 'b'],
      ]);
      expect(() => Badge.parseDefinition(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'd')));
    });

    test('permissive surfaces missing d', () {
      final event = _build(30009, [
        ['name', 'b'],
      ]);
      final data = Badge.parseDefinition(event, permissive: true);
      expect(data.badgeId, '');
      expect(data.name, 'b');
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-53 LiveActivity.parse permissive', () {
    test('strict throws on missing d', () {
      final event = _build(30311, [
        ['title', 'a stream'],
      ]);
      expect(() => LiveActivity.parse(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'd')));
    });

    test('permissive surfaces missing d', () {
      final event = _build(30311, [
        ['title', 'a stream'],
      ]);
      final data = LiveActivity.parse(event, permissive: true);
      expect(data.identifier, '');
      expect(data.title, 'a stream');
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-57 Zap permissive', () {
    test('parseRequest strict throws on missing p', () {
      final event = _build(9734, [
        ['relays', 'wss://relay.example'],
      ]);
      expect(() => Zap.parseRequest(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'p')));
    });

    test('parseRequest permissive surfaces missing p', () {
      final event = _build(9734, [
        ['relays', 'wss://relay.example'],
      ]);
      final data = Zap.parseRequest(event, permissive: true);
      expect(data.recipientPubkey, '');
      expect(data.relays, ['wss://relay.example']);
      expect(data.missingTags, {'p'});
      expect(data.isComplete, isFalse);
    });

    test('parseReceipt permissive flags bolt11 / description / p', () {
      final event = _build(9735, []);
      final data = Zap.parseReceipt(event, permissive: true);
      expect(data.bolt11, '');
      expect(data.description, '');
      expect(data.recipientPubkey, '');
      expect(data.missingTags, {'bolt11', 'description', 'p'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-89 AppHandler permissive', () {
    test('parseHandlerInfo strict throws on missing d', () {
      final event = _build(31990, [
        ['k', '1'],
      ]);
      expect(() => AppHandler.parseHandlerInfo(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'd')));
    });

    test('parseHandlerInfo permissive surfaces missing d', () {
      final event = _build(31990, [
        ['k', '1'],
      ]);
      final data = AppHandler.parseHandlerInfo(event, permissive: true);
      expect(data.id, '');
      expect(data.supportedKinds, [1]);
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });

    test('parseRecommendation permissive surfaces missing d', () {
      final event = _build(31989, [
        ['a', '31990:author:handler'],
      ]);
      final data = AppHandler.parseRecommendation(event, permissive: true);
      expect(data.eventKind, isNull);
      expect(data.handlerCoords, ['31990:author:handler']);
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
    });
  });

  group('NIP-98 HttpAuth.parse permissive', () {
    test('strict throws on missing u', () {
      final event = _build(27235, [
        ['method', 'GET'],
      ]);
      expect(() => HttpAuth.parse(event),
          throwsA(isA<MissingTagException>().having((e) => e.tag, 'tag', 'u')));
    });

    test('permissive flags missing u + method', () {
      final event = _build(27235, []);
      final data = HttpAuth.parse(event, permissive: true);
      expect(data.url, '');
      expect(data.method, '');
      expect(data.missingTags, {'u', 'method'});
      expect(data.isComplete, isFalse);
    });
  });
}
