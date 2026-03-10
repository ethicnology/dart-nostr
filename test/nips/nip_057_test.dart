import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip057', () {
    const String secretKey =
        '826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8';
    const String recipientPubkey =
        '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';
    group('zap request encoding', () {
      test('encodes a basic zap request with required fields', () {
        final event = Nip57.request(
          recipientPubkey: recipientPubkey,
          relays: ['wss://relay1.com', 'wss://relay2.com'],
          secretKey: secretKey,
        );
        expect(event.kind, 9734);
        expect(event.content, '');
        expect(event.tags[0][0], 'relays');
        expect(event.tags[0][1], 'wss://relay1.com');
        expect(event.tags[0][2], 'wss://relay2.com');
        expect(event.tags[1], ['p', recipientPubkey]);
      });

      test('encodes a zap request with all optional fields', () {
        final event = Nip57.request(
          recipientPubkey: recipientPubkey,
          relays: ['wss://relay.com'],
          secretKey: secretKey,
          content: 'Great post!',
          eventId:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          addressableCoord: '30023:pubkey:slug',
          amount: 21000,
          lnurl: 'lnurl1dp68gurn8ghj7...',
        );
        expect(event.kind, 9734);
        expect(event.content, 'Great post!');

        final eTags = event.tags.where((t) => t[0] == 'e').toList();
        expect(eTags.length, 1);
        expect(eTags[0][1],
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');

        final aTags = event.tags.where((t) => t[0] == 'a').toList();
        expect(aTags.length, 1);
        expect(aTags[0][1], '30023:pubkey:slug');

        final amountTags = event.tags.where((t) => t[0] == 'amount').toList();
        expect(amountTags.length, 1);
        expect(amountTags[0][1], '21000');

        final lnurlTags = event.tags.where((t) => t[0] == 'lnurl').toList();
        expect(lnurlTags.length, 1);
        expect(lnurlTags[0][1], 'lnurl1dp68gurn8ghj7...');
      });
    });

    group('zap request decoding', () {
      test('decodes a zap request event', () {
        final event = Nip57.request(
          recipientPubkey: recipientPubkey,
          relays: ['wss://relay1.com', 'wss://relay2.com'],
          secretKey: secretKey,
          content: 'Nice!',
          amount: 5000,
        );
        final request = Nip57.parseRequest(event);
        expect(request.recipientPubkey, recipientPubkey);
        expect(request.relays, ['wss://relay1.com', 'wss://relay2.com']);
        expect(request.content, 'Nice!');
        expect(request.amount, 5000);
        expect(request.pubkey, event.pubkey);
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [
            ['p', recipientPubkey]
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip57.parseRequest(event),
            throwsA(isA<InvalidKindException>()));
      });
    });

    group('zap receipt decoding', () {
      test('decodes a zap receipt with embedded request', () {
        // Create a zap request first
        final zapRequest = Nip57.request(
          recipientPubkey: recipientPubkey,
          relays: ['wss://relay.com'],
          secretKey: secretKey,
          content: 'Zap!',
          amount: 1000,
        );

        // Create a zap receipt that embeds the request in the description tag
        final receiptEvent = Event.from(
          kind: 9735,
          tags: [
            ['p', recipientPubkey],
            ['bolt11', 'lnbc10u1p3...'],
            ['description', zapRequest.toJson()],
            ['preimage', 'abcdef1234567890'],
            [
              'e',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
            ],
          ],
          content: '',
          secretKey: secretKey,
        );

        final receipt = Nip57.parseReceipt(receiptEvent);
        expect(receipt.recipientPubkey, recipientPubkey);
        expect(receipt.bolt11, 'lnbc10u1p3...');
        expect(receipt.preimage, 'abcdef1234567890');
        expect(receipt.eventId,
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        expect(receipt.embeddedRequest, isNotNull);
        expect(receipt.embeddedRequest!.content, 'Zap!');
        expect(receipt.embeddedRequest!.amount, 1000);
        expect(receipt.embeddedRequest!.recipientPubkey, recipientPubkey);
      });

      test('decodes a zap receipt with P (sender) tag', () {
        final zapRequest = Nip57.request(
          recipientPubkey: recipientPubkey,
          relays: ['wss://relay.com'],
          secretKey: secretKey,
        );

        final receiptEvent = Event.from(
          kind: 9735,
          tags: [
            ['p', recipientPubkey],
            ['P', zapRequest.pubkey],
            ['bolt11', 'lnbc1...'],
            ['description', zapRequest.toJson()],
          ],
          content: '',
          secretKey: secretKey,
        );

        final receipt = Nip57.parseReceipt(receiptEvent);
        expect(receipt.senderPubkey, zapRequest.pubkey);
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip57.parseReceipt(event),
            throwsA(isA<InvalidKindException>()));
      });

      test('throws MissingTagException when bolt11 is absent', () {
        final event = Event.from(
          kind: 9735,
          tags: [
            ['p', recipientPubkey],
            ['description', '{}'],
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip57.parseReceipt(event),
            throwsA(isA<MissingTagException>()));
      });

      test('throws MissingTagException when description is absent', () {
        final event = Event.from(
          kind: 9735,
          tags: [
            ['p', recipientPubkey],
            ['bolt11', 'lnbc1...'],
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip57.parseReceipt(event),
            throwsA(isA<MissingTagException>()));
      });

      test('handles invalid embedded request JSON gracefully', () {
        final event = Event.from(
          kind: 9735,
          tags: [
            ['p', recipientPubkey],
            ['bolt11', 'lnbc1...'],
            ['description', 'not-valid-json'],
          ],
          content: '',
          secretKey: secretKey,
        );
        final receipt = Nip57.parseReceipt(event);
        expect(receipt.embeddedRequest, isNull);
        expect(receipt.bolt11, 'lnbc1...');
      });
    });

    test('decode real-world kind 9735 zap receipt from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['9735'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final receipt = Nip57.parseReceipt(event);
      expect(receipt.bolt11, startsWith('lnbc'));
      expect(receipt.recipientPubkey, isNotEmpty);
      expect(receipt.senderPubkey, isNotEmpty);
      expect(receipt.eventId, isNotEmpty);
      expect(receipt.preimage, isNotEmpty);
      // Embedded zap request should parse successfully
      expect(receipt.embeddedRequest, isNotNull);
      expect(receipt.embeddedRequest!.recipientPubkey, receipt.recipientPubkey);
      expect(receipt.embeddedRequest!.relays, isNotEmpty);
    });

    test('anonymous zap request uses throwaway keys and anon tag', () {
      final event = Zap.anonymousRequest(
        recipientPubkey: recipientPubkey,
        relays: ['wss://relay.damus.io'],
        content: 'Anonymous zap!',
        amount: 1000,
      );
      expect(event.kind, 9734);
      expect(findTagValue(event.tags, 'p'), recipientPubkey);
      // Has anon tag with no content
      final anonTag = event.tags.firstWhere((t) => t[0] == 'anon');
      expect(anonTag.length, 1); // just ["anon"], no payload
      // Pubkey is NOT the sender's key
      expect(event.pubkey, isNot(equals(Keys(secretKey).public)));
    });

    test('private zap request round-trip encrypt/decrypt', () async {
      const recipientSecret =
          'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';
      final recipientPub = Keys(recipientSecret).public;

      final privateZap = await Zap.privateRequest(
        recipientPubkey: recipientPub,
        relays: ['wss://relay.damus.io'],
        secretKey: secretKey,
        content: 'Private zap message!',
        amount: 21000,
      );

      expect(privateZap.kind, 9734);
      expect(privateZap.content, ''); // content hidden
      // Has anon tag with encrypted payload
      final anonTag = privateZap.tags.firstWhere((t) => t[0] == 'anon');
      expect(anonTag.length, 2);
      expect(anonTag[1], isNotEmpty);
      // Outer pubkey is ephemeral, not sender
      expect(privateZap.pubkey, isNot(equals(Keys(secretKey).public)));

      // Recipient decrypts
      final decrypted = await Zap.decryptPrivateRequest(
        privateZapEvent: privateZap,
        recipientSecretKey: recipientSecret,
      );

      // Inner event reveals real sender and message
      expect(decrypted.pubkey, Keys(secretKey).public);
      expect(decrypted.content, 'Private zap message!');
      expect(decrypted.amount, 21000);
      expect(decrypted.recipientPubkey, recipientPub);
    });

    test('typedef Zaps works', () {
      final event = Zaps.request(
        recipientPubkey: recipientPubkey,
        relays: ['wss://relay.com'],
        secretKey: secretKey,
      );
      expect(event.kind, 9734);
    });
  });
}
