import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip046', () {
    const String secretKey =
        '826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8';
    const String targetPubkey =
        '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';
    const String encryptedContent = 'some-nip44-encrypted-payload';

    test('create produces a kind 24133 event with p tag', () {
      final event = NostrConnect.create(
        encryptedContent: encryptedContent,
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 24133);
      expect(event.content, encryptedContent);
      expect(event.tags.length, 1);
      expect(event.tags[0][0], 'p');
      expect(event.tags[0][1], targetPubkey);
    });

    test('parse extracts fields from a kind 24133 event', () {
      final event = NostrConnect.create(
        encryptedContent: encryptedContent,
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      final parsed = NostrConnect.parse(event);
      expect(parsed.targetPubkey, targetPubkey);
      expect(parsed.encryptedContent, encryptedContent);
      expect(parsed.pubkey, event.pubkey);
      expect(parsed.id, event.id);
      expect(parsed.createdAt, event.createdAt);
    });

    test('parse throws InvalidKindException for wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['p', targetPubkey]
        ],
        content: encryptedContent,
        secretKey: secretKey,
      );
      expect(() => NostrConnect.parse(event),
          throwsA(isA<InvalidKindException>()));
    });

    test('parse throws MissingTagException when p tag is absent', () {
      final event = Event.from(
        kind: 24133,
        tags: [],
        content: encryptedContent,
        secretKey: secretKey,
      );
      expect(() => NostrConnect.parse(event),
          throwsA(isA<MissingTagException>()));
    });

    test('round-trip create then parse', () {
      final event = NostrConnect.create(
        encryptedContent: 'encrypted-rpc-message',
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      final parsed = NostrConnect.parse(event);
      expect(parsed.encryptedContent, 'encrypted-rpc-message');
      expect(parsed.targetPubkey, targetPubkey);
    });

    test('parse real-world kind 24133 from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['24133'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final parsed = NostrConnect.parse(event);
      expect(parsed.targetPubkey, isNotEmpty);
      expect(parsed.encryptedContent, isNotEmpty);
      expect(parsed.pubkey, event.pubkey);
    });

    test('typedef Nip46 works', () {
      final event = Nip46.create(
        encryptedContent: encryptedContent,
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 24133);
    });
  });
}
