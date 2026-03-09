import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('nip065', () {
    test('encode relay list', () {
      final event = Nip65.encode(
        relays: [
          const RelayMetadata(url: 'wss://a.com', read: true, write: true),
          const RelayMetadata(url: 'wss://b.com', read: true, write: false),
          const RelayMetadata(url: 'wss://c.com', read: false, write: true),
        ],
        secretKey: secretKey,
      );
      expect(event.kind, 10002);
      expect(event.tags[0], ['r', 'wss://a.com']);
      expect(event.tags[1], ['r', 'wss://b.com', 'read']);
      expect(event.tags[2], ['r', 'wss://c.com', 'write']);
    });

    test('decode relay list', () {
      final event = Event.from(
        kind: 10002,
        tags: [
          ['r', 'wss://a.com'],
          ['r', 'wss://b.com', 'read'],
          ['r', 'wss://c.com', 'write'],
        ],
        content: '',
        secretKey: secretKey,
      );
      final relays = Nip65.decode(event);
      expect(relays.length, 3);
      expect(relays[0].url, 'wss://a.com');
      expect(relays[0].read, isTrue);
      expect(relays[0].write, isTrue);
      expect(relays[1].read, isTrue);
      expect(relays[1].write, isFalse);
      expect(relays[2].read, isFalse);
      expect(relays[2].write, isTrue);
    });

    test('decode skips non-r tags', () {
      final event = Event.from(
        kind: 10002,
        tags: [
          ['r', 'wss://a.com'],
          ['p', 'some-pubkey'],
          ['r', 'wss://b.com', 'read'],
        ],
        content: '',
        secretKey: secretKey,
      );
      final relays = Nip65.decode(event);
      expect(relays.length, 2);
    });

    test('decode throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(() => Nip65.decode(event), throwsA(isA<InvalidKindException>()));
    });

    test('encode and decode round-trip', () {
      final relays = [
        const RelayMetadata(url: 'wss://a.com', read: true, write: true),
        const RelayMetadata(url: 'wss://b.com', read: true, write: false),
        const RelayMetadata(url: 'wss://c.com', read: false, write: true),
      ];
      final event = Nip65.encode(relays: relays, secretKey: secretKey);
      final decoded = Nip65.decode(event);

      expect(decoded.length, 3);
      expect(decoded[0].url, 'wss://a.com');
      expect(decoded[0].read, isTrue);
      expect(decoded[0].write, isTrue);
      expect(decoded[1].url, 'wss://b.com');
      expect(decoded[1].read, isTrue);
      expect(decoded[1].write, isFalse);
      expect(decoded[2].url, 'wss://c.com');
      expect(decoded[2].read, isFalse);
      expect(decoded[2].write, isTrue);
    });

    test('decode real-world kind 10002 relay list from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['10002'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final relays = Nip65.decode(event);
      expect(relays, isNotEmpty);
      for (final relay in relays) {
        expect(relay.url, startsWith('ws'));
      }
    });

    test('typedef alias works', () {
      final event = RelayList.encode(
        relays: [const RelayMetadata(url: 'wss://a.com', read: true, write: true)],
        secretKey: secretKey,
      );
      expect(event.kind, 10002);
    });
  });
}
