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
}
