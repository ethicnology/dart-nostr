import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('nip025', () {
    test('encode like reaction with default content', () {
      final event = Nip25.create(
        eventId: 'abc123',
        eventPubkey: 'def456',
        secretKey: secretKey,
      );
      expect(event.kind, 7);
      expect(event.content, '+');
      expect(event.tags[0][0], 'e');
      expect(event.tags[0][1], 'abc123');
      expect(event.tags[1], ['p', 'def456']);
    });

    test('encode emoji reaction with relay and k tag', () {
      final event = Nip25.create(
        eventId: 'abc123',
        eventPubkey: 'def456',
        secretKey: secretKey,
        content: '🤙',
        relay: 'wss://relay.example.com',
        eventKind: 1,
      );
      expect(event.content, '🤙');
      expect(event.tags[0], ['e', 'abc123', 'wss://relay.example.com']);
      expect(event.tags[1], ['p', 'def456']);
      expect(event.tags[2], ['k', '1']);
    });

    test('encode reaction on addressable event includes a tag', () {
      final event = Nip25.create(
        eventId: 'abc123',
        eventPubkey: 'def456',
        secretKey: secretKey,
        addressableCoord: '30023:def456:my-article',
        eventKind: 30023,
      );
      expect(event.tags[1], ['a', '30023:def456:my-article']);
      expect(event.tags[3], ['k', '30023']);
    });

    test('decode reaction with k tag', () {
      final event = Event.from(
        kind: 7,
        tags: [
          ['e', 'abc123'],
          ['p', 'def456'],
          ['k', '1'],
        ],
        content: '-',
        secretKey: secretKey,
      );
      final reaction = Nip25.parse(event);
      expect(reaction.eventId, 'abc123');
      expect(reaction.reactedPubkey, 'def456');
      expect(reaction.reactedKind, 1);
      expect(reaction.content, '-');
    });

    test('decode reaction without k tag', () {
      final event = Event.from(
        kind: 7,
        tags: [
          ['e', 'abc123'],
          ['p', 'def456'],
        ],
        content: '+',
        secretKey: secretKey,
      );
      final reaction = Nip25.parse(event);
      expect(reaction.reactedKind, isNull);
    });

    test('decode real-world kind 7 reaction from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['7'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final reaction = Nip25.parse(event);
      expect(reaction.eventId, isNotEmpty);
      expect(reaction.reactedPubkey, isNotEmpty);
      expect(reaction.pubkey, event.pubkey);
      expect(reaction.content, isNotEmpty);
    });

    test('encode and decode round-trip', () {
      final event = Nip25.create(
        eventId: 'abc123',
        eventPubkey: 'def456',
        secretKey: secretKey,
        content: '❤️',
        eventKind: 1,
      );
      final reaction = Nip25.parse(event);
      expect(reaction.eventId, 'abc123');
      expect(reaction.reactedPubkey, 'def456');
      expect(reaction.reactedKind, 1);
      expect(reaction.content, '❤️');
    });

    test('typedef Reactions works', () {
      final event = Reaction.create(
        eventId: 'abc123',
        eventPubkey: 'def456',
        secretKey: secretKey,
      );
      expect(event.kind, 7);
    });

    test('decode throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(() => Nip25.parse(event), throwsA(isA<InvalidKindException>()));
    });
  });
}
