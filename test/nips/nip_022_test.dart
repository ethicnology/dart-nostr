import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip022', () {
    test('decode comment on event root', () {
      final event = Event.partial(
        kind: 1111,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          [
            'E',
            'root-event-id-hex',
            'wss://relay.example.com',
            'root-pubkey-hex'
          ],
          ['K', '1'],
          ['P', 'root-pubkey-hex'],
          [
            'e',
            'parent-event-id-hex',
            'wss://relay.example.com',
            'parent-pubkey-hex'
          ],
          ['k', '1111'],
          ['p', 'parent-pubkey-hex'],
        ],
        content: 'This is a comment on an event.',
      );

      final comment = Nip22.parse(event);

      expect(comment.rootId, 'root-event-id-hex');
      expect(comment.rootKind, 1);
      expect(comment.rootPubkey, 'root-pubkey-hex');
      expect(comment.parentId, 'parent-event-id-hex');
      expect(comment.parentKind, 1111);
      expect(comment.parentPubkey, 'parent-pubkey-hex');
      expect(comment.content, 'This is a comment on an event.');
      expect(comment.pubkey,
          'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233');
      expect(comment.createdAt, 1700000000);
    });

    test('decode comment on addressable event root', () {
      final event = Event.partial(
        kind: 1111,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['A', '30023:author-pubkey:article-id', 'wss://relay.example.com'],
          ['K', '30023'],
          ['e', 'parent-event-id-hex'],
          ['k', '1111'],
        ],
        content: 'Comment on an article.',
      );

      final comment = Nip22.parse(event);

      expect(comment.rootId, '30023:author-pubkey:article-id');
      expect(comment.rootKind, 30023);
      expect(comment.parentId, 'parent-event-id-hex');
      expect(comment.parentKind, 1111);
      expect(comment.content, 'Comment on an article.');
    });

    test('decode comment on external resource', () {
      final event = Event.partial(
        kind: 1111,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['I', 'https://example.com/article'],
          ['K', 'url'],
          ['i', 'https://example.com/article'],
          ['k', 'url'],
        ],
        content: 'Commenting on external content.',
      );

      final comment = Nip22.parse(event);

      expect(comment.rootId, 'https://example.com/article');
      expect(comment.parentId, 'https://example.com/article');
      expect(comment.content, 'Commenting on external content.');
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip22.parse(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('decode throws on missing required tags', () {
      // Spec MUST: K, k, plus at least one root-scope (E/A/I) and one
      // parent (e/a/i). A bare event must be rejected.
      final event = Event.partial(
        kind: 1111,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [],
        content: 'A bare comment.',
      );
      expect(() => Nip22.parse(event), throwsA(isA<MissingTagException>()));
    });

    test('decode throws when K tag missing', () {
      final event = Event.partial(
        kind: 1111,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['E', 'root-id'],
          ['e', 'parent-id'],
          ['k', '1'],
          // K is missing
        ],
        content: 'comment',
      );
      expect(() => Nip22.parse(event), throwsA(isA<MissingTagException>()));
    });

    test('encode comment on event', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip22.create(
        content: 'Great post!',
        secretKey: secretKey,
        rootTag: ['E', 'root-id', 'wss://relay.example.com', 'root-pubkey'],
        rootKind: '1',
        parentTag: [
          'e',
          'parent-id',
          'wss://relay.example.com',
          'parent-pubkey'
        ],
        parentKind: '1111',
        rootPubkey: 'root-pubkey',
        parentPubkey: 'parent-pubkey',
      );
      expect(event.kind, 1111);
      expect(event.content, 'Great post!');
      expect(event.tags[0][0], 'E');
      expect(event.tags[1], ['K', '1']);
      expect(event.tags[2], ['P', 'root-pubkey']);
      expect(event.tags[3][0], 'e');
      expect(event.tags[4], ['k', '1111']);
      expect(event.tags[5], ['p', 'parent-pubkey']);
    });

    test('encode and decode round-trip', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip22.create(
        content: 'Hello',
        secretKey: secretKey,
        rootTag: ['E', 'root-id'],
        rootKind: '1',
        parentTag: ['e', 'parent-id'],
        parentKind: '1111',
      );
      final comment = Nip22.parse(event);
      expect(comment.content, 'Hello');
      expect(comment.rootId, 'root-id');
      expect(comment.rootKind, 1);
      expect(comment.parentId, 'parent-id');
      expect(comment.parentKind, 1111);
    });

    test('decode real-world kind 1111 comment from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['1111'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final comment = Nip22.parse(event);
      expect(comment.content, isNotEmpty);
      expect(comment.pubkey, event.pubkey);
      // This real event uses I/i tags (external URL) with K="web"
      expect(comment.rootId, startsWith('https://'));
      expect(comment.parentId, startsWith('https://'));
      // "web" is not an integer kind, so rootKind should be null
      expect(comment.rootKind, isNull);
    });

    test('typedef alias works', () {
      // Nip22 is an alias for Comment
      expect(Nip22.kindComment, 1111);
    });
  });
}
