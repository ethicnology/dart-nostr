// NIP-01 (Basic protocol flow) — direct unit tests for the Note helpers.
// Event-level behaviour is covered in event_test.dart; this file focuses
// on Note.create / Note.setMetadata / Note.parse and the tag extractors.

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const _secret =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('NIP-01 Note.create', () {
    test('builds a kind-1 event with bare content', () {
      final event = Note.create(content: 'hello', secretKey: _secret);
      expect(event.kind, Note.kindShortNote);
      expect(event.content, 'hello');
      expect(event.tags, isEmpty);
      expect(event.isValid(), isTrue);
    });

    test('emits root + reply e-tags when threading is supplied', () {
      final event = Note.create(
        content: 'reply',
        secretKey: _secret,
        rootEvent: 'a' * 64,
        rootEventRelay: 'wss://relay.example',
        replyEvent: 'b' * 64,
        replyEventRelay: 'wss://relay.example',
      );
      // Two e tags: root and reply, in that order
      final eTags =
          event.tags.where((t) => t.isNotEmpty && t[0] == 'e').toList();
      expect(eTags, hasLength(2));
      expect(eTags[0][3], 'root');
      expect(eTags[1][3], 'reply');
    });

    test('emits p tags and hashtags', () {
      final event = Note.create(
        content: 'cc',
        secretKey: _secret,
        replyUsers: ['c' * 64, 'd' * 64],
        replyUserRelays: ['wss://x', 'wss://y'],
        hashTags: ['nostr', 'dart'],
      );
      final pTags =
          event.tags.where((t) => t.isNotEmpty && t[0] == 'p').toList();
      expect(pTags, hasLength(2));
      expect(pTags[0][1], 'c' * 64);
      expect(pTags[1][2], 'wss://y');
      final tTags =
          event.tags.where((t) => t.isNotEmpty && t[0] == 't').toList();
      expect(tTags.map((t) => t[1]), ['nostr', 'dart']);
    });
  });

  group('NIP-01 Note.setMetadata', () {
    test('builds a kind-0 event with the supplied JSON content', () {
      final event = Note.setMetadata(
        content: '{"name":"alice"}',
        secretKey: _secret,
      );
      expect(event.kind, Note.kindMetadata);
      expect(event.content, '{"name":"alice"}');
      expect(event.tags, isEmpty);
    });
  });

  group('NIP-01 Note.parse', () {
    test('accepts kind 1 short text notes', () {
      final event = Note.create(content: 'hello', secretKey: _secret);
      final data = Note.parse(event);
      expect(data.content, 'hello');
      expect(data.pubkey, event.pubkey);
      expect(data.id, event.id);
      expect(data.hashTags, isEmpty);
    });

    test('accepts NIP-29 kind 11 thread root events', () {
      final event = Event.from(
        kind: Group.kindGroupThreadRoot,
        tags: [
          ['h', 'group-123'],
        ],
        content: 'thread root',
        secretKey: _secret,
      );
      final data = Note.parse(event);
      expect(data.content, 'thread root');
      expect(data.groupId, 'group-123');
    });

    test('accepts NIP-29 kind 12 thread reply events', () {
      final event = Event.from(
        kind: Group.kindGroupThreadReply,
        tags: [
          ['h', 'group-456'],
        ],
        content: 'reply',
        secretKey: _secret,
      );
      expect(() => Note.parse(event), returnsNormally);
    });

    test('rejects unsupported kinds with InvalidKindException', () {
      final event = Event.from(
        kind: 7,
        tags: [],
        content: '+',
        secretKey: _secret,
      );
      expect(
        () => Note.parse(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('surfaces quote-repost id from q tag', () {
      final event = Event.from(
        kind: Note.kindShortNote,
        tags: [
          ['q', 'q' * 64],
        ],
        content: 'quoted',
        secretKey: _secret,
      );
      final data = Note.parse(event);
      expect(data.quoteRepostId, 'q' * 64);
    });
  });

  group('NIP-01 helpers', () {
    test('extractHashTags returns empty when no t tags', () {
      expect(Note.extractHashTags([]), isEmpty);
      expect(
        Note.extractHashTags([
          ['e', 'a' * 64]
        ]),
        isEmpty,
      );
    });

    test('extractHashTags collects every t tag value', () {
      expect(
        Note.extractHashTags([
          ['t', 'nostr'],
          ['t', 'dart'],
          ['p', 'a' * 64],
        ]),
        ['nostr', 'dart'],
      );
    });

    test('quoteRepostId returns null without q tag', () {
      expect(Note.quoteRepostId([]), isNull);
    });

    test('groupId returns the h tag value', () {
      expect(
        Note.groupId([
          ['h', 'group-abc'],
        ]),
        'group-abc',
      );
    });
  });
}
