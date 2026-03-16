import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NIP-40 Expiration Timestamp', () {
    test('tag() creates a valid expiration tag', () {
      final t = Expiration.tag(1600000000);
      expect(t, ['expiration', '1600000000']);
    });

    test('findExpiration() returns timestamp when present', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['expiration', '1600000000'],
        ],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.findExpiration(event), 1600000000);
    });

    test('findExpiration() returns null when absent', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.findExpiration(event), isNull);
    });

    test('findExpiration() returns null for non-numeric value', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['expiration', 'not-a-number'],
        ],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.findExpiration(event), isNull);
    });

    test('isExpired() returns true for past timestamp', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['expiration', '1000000000'], // 2001
        ],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.isExpired(event), isTrue);
    });

    test('isExpired() returns false for far-future timestamp', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['expiration', '9999999999'], // year 2286
        ],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.isExpired(event), isFalse);
    });

    test('isExpired() returns false when no expiration tag', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'hello',
        secretKey:
            '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      expect(Expiration.isExpired(event), isFalse);
    });

    test('typedef Nip40 works', () {
      expect(Nip40.tag(123), ['expiration', '123']);
    });
  });
}
