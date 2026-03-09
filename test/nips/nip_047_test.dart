import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip047', () {
    const String secretKey =
        '826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8';
    const String walletPubkey =
        '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

    test('decodeInfo parses capabilities from content', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: 'pay_invoice get_balance make_invoice list_transactions',
        secretKey: secretKey,
      );
      final info = Nip47.decodeInfo(event);
      expect(info.capabilities, [
        'pay_invoice',
        'get_balance',
        'make_invoice',
        'list_transactions',
      ]);
      expect(info.pubkey, event.pubkey);
    });

    test('decodeInfo parses encryption and notification tags', () {
      final event = Event.from(
        kind: 13194,
        tags: [
          ['encryption', 'nip44_v2'],
          ['encryption', 'nip04'],
          ['notifications', 'payment_received'],
        ],
        content: 'pay_invoice',
        secretKey: secretKey,
      );
      final info = Nip47.decodeInfo(event);
      expect(info.encryption, ['nip44_v2', 'nip04']);
      expect(info.notifications, ['payment_received']);
    });

    test('decodeInfo throws InvalidKindException for wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'pay_invoice',
        secretKey: secretKey,
      );
      expect(
          () => Nip47.decodeInfo(event), throwsA(isA<InvalidKindException>()));
    });

    test('decodeInfo handles empty content', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      final info = Nip47.decodeInfo(event);
      expect(info.capabilities, isEmpty);
    });

    test('encodeRequest creates a kind 23194 event', () {
      final event = Nip47.encodeRequest(
        encryptedContent: 'encrypted-request',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 23194);
      expect(event.content, 'encrypted-request');
      expect(event.tags[0], ['p', walletPubkey]);
    });

    test('encodeResponse creates a kind 23195 event with e tag', () {
      const requestId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = Nip47.encodeResponse(
        encryptedContent: 'encrypted-response',
        clientPubkey: walletPubkey,
        requestEventId: requestId,
        secretKey: secretKey,
      );
      expect(event.kind, 23195);
      expect(event.content, 'encrypted-response');
      expect(event.tags[0], ['p', walletPubkey]);
      expect(event.tags[1], ['e', requestId]);
    });

    test('decode parses a request event', () {
      final event = Nip47.encodeRequest(
        encryptedContent: 'encrypted-payload',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      final decoded = Nip47.decode(event);
      expect(decoded.kind, 23194);
      expect(decoded.targetPubkey, walletPubkey);
      expect(decoded.encryptedContent, 'encrypted-payload');
      expect(decoded.requestEventId, isNull);
    });

    test('decode parses a response event', () {
      const requestId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = Nip47.encodeResponse(
        encryptedContent: 'encrypted-result',
        clientPubkey: walletPubkey,
        requestEventId: requestId,
        secretKey: secretKey,
      );
      final decoded = Nip47.decode(event);
      expect(decoded.kind, 23195);
      expect(decoded.targetPubkey, walletPubkey);
      expect(decoded.requestEventId, requestId);
      expect(decoded.encryptedContent, 'encrypted-result');
    });

    test('decode throws for info kind (use decodeInfo instead)', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: 'pay_invoice',
        secretKey: secretKey,
      );
      expect(() => Nip47.decode(event), throwsA(isA<InvalidKindException>()));
    });

    test('decode throws InvalidKindException for unrelated kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'hello',
        secretKey: secretKey,
      );
      expect(() => Nip47.decode(event), throwsA(isA<InvalidKindException>()));
    });

    test('decodeInfo real-world kind 13194 from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['13194'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final info = Nip47.decodeInfo(event);
      expect(info.capabilities, contains('pay_invoice'));
      expect(info.capabilities, contains('get_balance'));
      expect(info.pubkey, event.pubkey);
    });

    test('typedef WalletConnect works', () {
      final event = WalletConnect.encodeRequest(
        encryptedContent: 'test',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 23194);
    });
  });
}
