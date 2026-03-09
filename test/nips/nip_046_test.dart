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

    test('encode creates a kind 24133 event with p tag', () {
      final event = Nip46.encode(
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

    test('decode extracts fields from a kind 24133 event', () {
      final event = Nip46.encode(
        encryptedContent: encryptedContent,
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      final decoded = Nip46.decode(event);
      expect(decoded.targetPubkey, targetPubkey);
      expect(decoded.encryptedContent, encryptedContent);
      expect(decoded.pubkey, event.pubkey);
      expect(decoded.id, event.id);
      expect(decoded.createdAt, event.createdAt);
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['p', targetPubkey]
        ],
        content: encryptedContent,
        secretKey: secretKey,
      );
      expect(() => Nip46.decode(event), throwsA(isA<InvalidKindException>()));
    });

    test('decode throws MissingTagException when p tag is absent', () {
      final event = Event.from(
        kind: 24133,
        tags: [],
        content: encryptedContent,
        secretKey: secretKey,
      );
      expect(() => Nip46.decode(event), throwsA(isA<MissingTagException>()));
    });

    test('round-trip encode then decode', () {
      final event = Nip46.encode(
        encryptedContent: 'encrypted-rpc-message',
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      final decoded = Nip46.decode(event);
      expect(decoded.encryptedContent, 'encrypted-rpc-message');
      expect(decoded.targetPubkey, targetPubkey);
    });

    test('decode real-world kind 24133 from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['24133'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final decoded = Nip46.decode(event);
      expect(decoded.targetPubkey, isNotEmpty);
      expect(decoded.encryptedContent, isNotEmpty);
      expect(decoded.pubkey, event.pubkey);
    });

    test('typedef NostrConnect works', () {
      final event = NostrConnect.encode(
        encryptedContent: encryptedContent,
        targetPubkey: targetPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 24133);
    });
  });
}
