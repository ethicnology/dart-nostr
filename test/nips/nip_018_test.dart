import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('nip018', () {
    test('encode text note repost (kind 6)', () {
      final original = Event.from(
        kind: 1,
        tags: [],
        content: 'hello world',
        secretKey: secretKey,
      );
      final repost = Nip18.create(
        originalEvent: original,
        secretKey: secretKey,
        relay: 'wss://relay.example.com',
      );
      expect(repost.kind, 6);
      expect(repost.tags[0], ['e', original.id, 'wss://relay.example.com']);
      expect(repost.tags[1][0], 'p');
      expect(repost.content.contains('hello world'), isTrue);
    });

    test('encode generic repost (kind 16) for non-kind-1', () {
      final original = Event.from(
        kind: 30023,
        tags: [
          ['d', 'my-article']
        ],
        content: 'article body',
        secretKey: secretKey,
      );
      final repost = Nip18.create(
        originalEvent: original,
        secretKey: secretKey,
        relay: 'wss://relay.example.com',
      );
      expect(repost.kind, 16);
      expect(repost.tags[2], ['k', '30023']);
    });

    test('decode repost', () {
      final original = Event.from(
        kind: 1,
        tags: [],
        content: 'test',
        secretKey: secretKey,
      );
      final repostEvent = Nip18.create(
        originalEvent: original,
        secretKey: secretKey,
        relay: 'wss://relay.example.com',
      );
      final repost = Nip18.parse(repostEvent);
      expect(repost.eventId, original.id);
      expect(repost.originalEvent, isNotNull);
      expect(repost.originalEvent!.content, 'test');
    });

    test('decode with empty content returns null originalEvent', () {
      final event = Event.from(
        kind: 6,
        tags: [
          ['e', 'abc123', 'wss://relay.example.com'],
          ['p', 'def456'],
        ],
        content: '',
        secretKey: secretKey,
      );
      final repost = Nip18.parse(event);
      expect(repost.eventId, 'abc123');
      expect(repost.repostedPubkey, 'def456');
      expect(repost.originalEvent, isNull);
    });

    test('decode with malformed JSON content returns null originalEvent', () {
      final event = Event.from(
        kind: 6,
        tags: [
          ['e', 'abc123'],
          ['p', 'def456'],
        ],
        content: 'not json at all',
        secretKey: secretKey,
      );
      final repost = Nip18.parse(event);
      expect(repost.originalEvent, isNull);
    });

    test('decode real-world kind 6 repost from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['6'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final repost = Nip18.parse(event);
      expect(repost.eventId, isNotEmpty);
      expect(repost.repostedPubkey, isNotEmpty);
      expect(repost.pubkey, event.pubkey);
      expect(repost.originalEvent, isNotNull);
      expect(repost.originalEvent!.kind, 1);
    });

    test('typedef Reposts works', () {
      final event = Event.from(
        kind: 6,
        tags: [
          ['e', 'abc123'],
          ['p', 'def456'],
        ],
        content: '',
        secretKey: secretKey,
      );
      final repost = Repost.parse(event);
      expect(repost.eventId, 'abc123');
    });

    test('decode throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(() => Nip18.parse(event), throwsA(isA<InvalidKindException>()));
    });
  });
}
