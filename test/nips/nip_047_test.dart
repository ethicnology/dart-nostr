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

    test('parseInfo parses capabilities from content', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: 'pay_invoice get_balance make_invoice list_transactions',
        secretKey: secretKey,
      );
      final info = WalletConnect.parseInfo(event);
      expect(info.capabilities, [
        'pay_invoice',
        'get_balance',
        'make_invoice',
        'list_transactions',
      ]);
      expect(info.pubkey, event.pubkey);
    });

    test('parseInfo parses encryption and notification tags', () {
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
      final info = WalletConnect.parseInfo(event);
      expect(info.encryption, ['nip44_v2', 'nip04']);
      expect(info.notifications, ['payment_received']);
    });

    test('parseInfo throws InvalidKindException for wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'pay_invoice',
        secretKey: secretKey,
      );
      expect(() => WalletConnect.parseInfo(event),
          throwsA(isA<InvalidKindException>()));
    });

    test('parseInfo handles empty content', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      final info = WalletConnect.parseInfo(event);
      expect(info.capabilities, isEmpty);
    });

    test('request creates a kind 23194 event', () {
      final event = WalletConnect.request(
        encryptedContent: 'encrypted-request',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 23194);
      expect(event.content, 'encrypted-request');
      expect(event.tags[0], ['p', walletPubkey]);
    });

    test('response creates a kind 23195 event with e tag', () {
      const requestId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = WalletConnect.response(
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

    test('parse parses a request event', () {
      final event = WalletConnect.request(
        encryptedContent: 'encrypted-payload',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      final parsed = WalletConnect.parse(event);
      expect(parsed.kind, 23194);
      expect(parsed.targetPubkey, walletPubkey);
      expect(parsed.encryptedContent, 'encrypted-payload');
      expect(parsed.requestEventId, isNull);
    });

    test('parse parses a response event', () {
      const requestId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final event = WalletConnect.response(
        encryptedContent: 'encrypted-result',
        clientPubkey: walletPubkey,
        requestEventId: requestId,
        secretKey: secretKey,
      );
      final parsed = WalletConnect.parse(event);
      expect(parsed.kind, 23195);
      expect(parsed.targetPubkey, walletPubkey);
      expect(parsed.requestEventId, requestId);
      expect(parsed.encryptedContent, 'encrypted-result');
    });

    test('parse throws for info kind (use parseInfo instead)', () {
      final event = Event.from(
        kind: 13194,
        tags: [],
        content: 'pay_invoice',
        secretKey: secretKey,
      );
      expect(() => WalletConnect.parse(event),
          throwsA(isA<InvalidKindException>()));
    });

    test('parse throws InvalidKindException for unrelated kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'hello',
        secretKey: secretKey,
      );
      expect(() => WalletConnect.parse(event),
          throwsA(isA<InvalidKindException>()));
    });

    test('parseInfo real-world kind 13194 from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['13194'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final info = WalletConnect.parseInfo(event);
      expect(info.capabilities, contains('pay_invoice'));
      expect(info.capabilities, contains('get_balance'));
      expect(info.pubkey, event.pubkey);
    });

    test('typedef Nip47 works', () {
      final event = Nip47.request(
        encryptedContent: 'test',
        walletServicePubkey: walletPubkey,
        secretKey: secretKey,
      );
      expect(event.kind, 23194);
    });
  });
}
