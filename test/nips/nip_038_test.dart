import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip038', () {
    test('decode general status', () {
      final event = Event.partial(
        kind: 30315,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'general'],
          ['r', 'https://example.com'],
          ['expiration', '1700100000'],
        ],
        content: 'Working on dart-nostr',
      );

      final status = Nip38.decode(event);

      expect(status.statusType, 'general');
      expect(status.content, 'Working on dart-nostr');
      expect(status.url, 'https://example.com');
      expect(status.expiration, 1700100000);
      expect(status.pubkey,
          'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233');
      expect(status.createdAt, 1700000000);
    });

    test('decode music status', () {
      final event = Event.partial(
        kind: 30315,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'music'],
          ['r', 'spotify:track:abc123'],
          ['expiration', '1700003600'],
        ],
        content: 'Dark Side of the Moon - Pink Floyd',
      );

      final status = Nip38.decode(event);

      expect(status.statusType, 'music');
      expect(status.content, 'Dark Side of the Moon - Pink Floyd');
      expect(status.url, 'spotify:track:abc123');
      expect(status.expiration, 1700003600);
    });

    test('decode status without optional fields', () {
      final event = Event.partial(
        kind: 30315,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'general'],
        ],
        content: 'Just chilling',
      );

      final status = Nip38.decode(event);

      expect(status.statusType, 'general');
      expect(status.content, 'Just chilling');
      expect(status.url, isNull);
      expect(status.expiration, isNull);
    });

    test('decode empty content clears status', () {
      final event = Event.partial(
        kind: 30315,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'general'],
        ],
      );

      final status = Nip38.decode(event);

      expect(status.content, '');
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip38.decode(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('decode throws MissingTagException for missing d tag', () {
      final event = Event.partial(
        kind: 30315,
        tags: [],
        content: 'no status type',
      );

      expect(
        () => Nip38.decode(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('encode status with all fields', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip38.encode(
        statusType: 'music',
        content: 'Listening to Pink Floyd',
        secretKey: secretKey,
        url: 'spotify:track:abc123',
        expiration: 1700100000,
      );
      expect(event.kind, 30315);
      expect(event.content, 'Listening to Pink Floyd');
      expect(event.tags[0], ['d', 'music']);
      expect(event.tags[1], ['r', 'spotify:track:abc123']);
      expect(event.tags[2], ['expiration', '1700100000']);
    });

    test('encode and decode round-trip', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip38.encode(
        statusType: 'general',
        content: 'Coding',
        secretKey: secretKey,
      );
      final status = Nip38.decode(event);
      expect(status.statusType, 'general');
      expect(status.content, 'Coding');
      expect(status.url, isNull);
      expect(status.expiration, isNull);
    });

    test('encode clear status with empty content', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip38.encode(
        statusType: 'general',
        content: '',
        secretKey: secretKey,
      );
      final status = Nip38.decode(event);
      expect(status.content, '');
    });

    test('decode real-world kind 30315 status from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['30315'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final status = Nip38.decode(event);
      expect(status.statusType, isNotEmpty);
      expect(status.pubkey, event.pubkey);
    });

    test('typedef alias works', () {
      expect(UserStatuses.kindUserStatus, 30315);
    });
  });
}
