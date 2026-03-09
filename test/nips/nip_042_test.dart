import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('nip042', () {
    test('create produces kind 22242 with relay and challenge tags', () {
      final event = Auth.create(
        challenge: 'abc123challenge',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      expect(event.kind, 22242);
      expect(event.content, '');
      expect(event.tags[0], ['relay', 'wss://relay.example.com']);
      expect(event.tags[1], ['challenge', 'abc123challenge']);
      expect(event.isValid(), isTrue);
    });

    test('create produces event with recent timestamp', () {
      final event = Auth.create(
        challenge: 'test',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(event.createdAt, greaterThan(now - 600));
      expect(event.createdAt, lessThanOrEqualTo(now));
    });

    test('validate returns true for matching event', () {
      final event = Auth.create(
        challenge: 'my-challenge',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      expect(
        Auth.validate(
          event: event,
          relayUrl: 'wss://relay.example.com',
          challenge: 'my-challenge',
        ),
        isTrue,
      );
    });

    test('validate returns false for wrong relay', () {
      final event = Auth.create(
        challenge: 'my-challenge',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      expect(
        Auth.validate(
          event: event,
          relayUrl: 'wss://other-relay.com',
          challenge: 'my-challenge',
        ),
        isFalse,
      );
    });

    test('validate returns false for wrong challenge', () {
      final event = Auth.create(
        challenge: 'my-challenge',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      expect(
        Auth.validate(
          event: event,
          relayUrl: 'wss://relay.example.com',
          challenge: 'wrong-challenge',
        ),
        isFalse,
      );
    });

    test('validate returns false for wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['relay', 'wss://relay.example.com'],
          ['challenge', 'test'],
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        Auth.validate(
          event: event,
          relayUrl: 'wss://relay.example.com',
          challenge: 'test',
        ),
        isFalse,
      );
    });

    test('typedef Nip42 works', () {
      final event = Nip42.create(
        challenge: 'test',
        relayUrl: 'wss://relay.example.com',
        secretKey: secretKey,
      );
      expect(event.kind, 22242);
    });
  });
}
