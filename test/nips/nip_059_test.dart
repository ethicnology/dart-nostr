import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NIP-59 Gift Wrap Tests', () {
    // Example from the spec
    const authorSecretKey =
        '0beebd062ec8735f4243466049d7747ef5d6594ee838de147f8aab842b15e273';
    const recipientSecretKey =
        'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';
    const ephemeralSecretKey =
        '4f02eac59266002db5801adc5270700ca69d5b8f761d8732fab2fbf233c90cbd';

    const rumorContent = 'Are you going to the party tonight?';
    const rumorCreatedAt = 1691518405;
    const rumorPubkey =
        '611df01bfcf85c26ae65453b772d8f1dfd25c264621c0277e1fc1518686faef9';

    test('Wrap & Unwrap yields the same rumor content (NIP-59 example)',
        () async {
      // 1) Construct an UNSIGNED rumor (kind=1, no .id, no .sig)
      //    If your "Event" constructor auto-signs, you may need to forcibly remove .id/.sig.
      final rumor = Event.partial(
        tags: [],
        content: rumorContent,
        createdAt: rumorCreatedAt,
        pubkey: rumorPubkey,
      );

      // 2) Wrap the rumor:
      //    - Seal => kind=13 => signed by author
      //    - GiftWrap => kind=1059 => signed by ephemeral
      //    We'll explicitly specify ephemeralSecretKey from the spec.
      final giftWrap = await Nip59.wrap(
        rumor: rumor,
        authorSecretKey: authorSecretKey,
        recipientPubkey: Keys(recipientSecretKey).public,
        ephemeralSecretKey: ephemeralSecretKey,
        createdAt: 1703021488,
      );

      expect(giftWrap.kind, 1059);
      expect(giftWrap.createdAt, 1703021488);
      expect(giftWrap.tags, [
        [
          "p",
          "166bf3765ebd1fc55decfe395beff2ea3b2a4e0a8946e7eb578512b555737c99"
        ]
      ]);
      expect(giftWrap.pubkey,
          '18b1a75918f1f2c90c23da616bce317d36e348bcf5f7ba55e75949319210c87c');
      expect(giftWrap.content, isNotEmpty);
      expect(giftWrap.sig, isNotNull,
          reason: 'giftWrap must be signed by ephemeral key');

      // 3) The recipient unwraps
      final unwrappedRumor = await Nip59.unwrap(
        giftWrap: giftWrap,
        recipientSecretKey: recipientSecretKey,
      );

      // The unwrapped rumor should be kind=1, no signature, same content
      expect(unwrappedRumor.kind, 1);
      expect(unwrappedRumor.content, rumorContent);
      expect(unwrappedRumor.sig, isEmpty, reason: 'Rumor must remain unsigned');
      // Per the NIP-59 example (and NIP-17: "Fields id and created_at are
      // required"), the rumor carries its canonical id on the wire — this
      // is the exact id from the spec example.
      expect(
        unwrappedRumor.id,
        '9dd003c6d3b73b74a85a9ab099469ce251653a7af76f523671ab828acd2a0ef9',
        reason: 'Rumor carries the canonical id from the NIP-59 example',
      );
    });

    test('the sealed rumor JSON has an id and no sig field (spec shape)',
        () async {
      // Decrypt the seal out of a gift wrap and inspect the rumor JSON
      // directly: rust-nostr's UnsignedEvent and the NIP-59 example both
      // serialize `id` present and `sig` absent.
      final rumor = Event.partial(
        tags: [],
        content: rumorContent,
        createdAt: rumorCreatedAt,
        pubkey: rumorPubkey,
      );
      final giftWrap = await Nip59.wrap(
        rumor: rumor,
        authorSecretKey: authorSecretKey,
        recipientPubkey: Keys(recipientSecretKey).public,
        ephemeralSecretKey: ephemeralSecretKey,
      );

      // Peel the gift wrap, then the seal, using the recipient key.
      final sealJson = await Nip44.decrypt(
        payload: giftWrap.content,
        recipientSecretKey: recipientSecretKey,
        senderPubkey: giftWrap.pubkey,
      );
      final seal = Event.fromJson(sealJson);
      final rumorJson = await Nip44.decrypt(
        payload: seal.content,
        recipientSecretKey: recipientSecretKey,
        senderPubkey: seal.pubkey,
      );
      final decoded = json.decode(rumorJson) as Map<String, dynamic>;

      expect(decoded['id'],
          '9dd003c6d3b73b74a85a9ab099469ce251653a7af76f523671ab828acd2a0ef9');
      expect(decoded.containsKey('sig'), isFalse,
          reason: 'rumor JSON must not carry a sig field (NIP-59 example, '
              'rust-nostr UnsignedEvent)');
    });

    test('wrap/unwrap with rust-nostr test keys', () async {
      final vectors = json.decode(
          File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
      final nip59 = vectors['nip59'];

      final senderSecret = nip59['sender_secret'] as String;
      final receiverSecret = nip59['receiver_secret'] as String;
      final receiverPubkey = Keys(receiverSecret).public;

      final rumor = Event.partial(
        content: 'cross-impl test',
        createdAt: 1700000000,
        pubkey: Keys(senderSecret).public,
      );

      final giftWrap = await Nip59.wrap(
        rumor: rumor,
        authorSecretKey: senderSecret,
        recipientPubkey: receiverPubkey,
      );

      expect(giftWrap.kind, 1059);

      final unwrapped = await Nip59.unwrap(
        giftWrap: giftWrap,
        recipientSecretKey: receiverSecret,
      );

      expect(unwrapped.content, 'cross-impl test');
      expect(unwrapped.pubkey, Keys(senderSecret).public);
      expect(unwrapped.sig, isEmpty);
    });

    test('gift wrap created_at is within the past 2 days', () async {
      final rumor = Event.partial(
        tags: [],
        content: 'test',
        createdAt: 1691518405,
        pubkey: rumorPubkey,
      );
      final giftWrap = await Nip59.wrap(
        rumor: rumor,
        authorSecretKey: authorSecretKey,
        recipientPubkey: Keys(recipientSecretKey).public,
        ephemeralSecretKey: ephemeralSecretKey,
      );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const twoDays = 2 * 24 * 3600;
      expect(giftWrap.createdAt, lessThanOrEqualTo(now));
      expect(giftWrap.createdAt, greaterThanOrEqualTo(now - twoDays));
    });

    test('unwrap rejects a seal carrying non-empty tags', () async {
      // Forge a seal with a tag inside the wrap. NIP-59 says kind-13
      // tags MUST be empty; the unwrap path should refuse this even if
      // the outer signature and decryption succeed.
      final realRecipientPub = Keys(recipientSecretKey).public;
      final ephemeral = Keys.generate();
      final author = Keys(authorSecretKey);

      // Build a rumor + encrypt it into a seal, but cheat the seal by
      // hand-crafting one with a tag.
      final rumor = Event.partial(
        pubkey: author.public,
        content: 'hidden',
        tags: [],
        createdAt: 1700000000,
      );
      final sealCiphertext = await Encryption.encrypt(
        plaintext: rumor.toJson(),
        senderSecretKey: authorSecretKey,
        recipientPubkey: realRecipientPub,
      );
      final forgedSeal = Event.from(
        kind: GiftWrap.kindSeal,
        tags: [
          ['SMUGGLED', 'data'],
        ],
        content: sealCiphertext,
        secretKey: authorSecretKey,
        createdAt: 1700000000,
      );
      // Wrap the forged seal with an ephemeral key as normal.
      final wrapCiphertext = await Encryption.encrypt(
        plaintext: forgedSeal.toJson(),
        senderSecretKey: ephemeral.secret,
        recipientPubkey: realRecipientPub,
      );
      final wrap = Event.from(
        kind: GiftWrap.kindGiftWrap,
        tags: [
          ['p', realRecipientPub],
        ],
        content: wrapCiphertext,
        secretKey: ephemeral.secret,
      );

      await expectLater(
        Nip59.unwrap(
          giftWrap: wrap,
          recipientSecretKey: recipientSecretKey,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          CryptoErrorCode.sealMustHaveEmptyTags,
        )),
      );
    });

    group('adversarial unwrap', () {
      final recipient = Keys(recipientSecretKey);
      final author = Keys(authorSecretKey);

      /// Wraps [rumorJson] into a gift wrap encrypted to [recipient],
      /// signing the seal with [sealSecret] and the wrap with a fresh
      /// ephemeral key — the manual path needed to smuggle non-conformant
      /// inner payloads past Nip59.wrap (which rebuilds the rumor).
      Future<Event> wrapManually(
        String rumorJson,
        String sealSecret,
        Keys recipient,
      ) async {
        final sealCiphertext = await Encryption.encrypt(
          plaintext: rumorJson,
          senderSecretKey: sealSecret,
          recipientPubkey: recipient.public,
        );
        final seal = Event.from(
          kind: GiftWrap.kindSeal,
          content: sealCiphertext,
          secretKey: sealSecret,
        );
        final ephemeral = Keys.generate();
        final wrapCiphertext = await Encryption.encrypt(
          plaintext: seal.toJson(),
          senderSecretKey: ephemeral.secret,
          recipientPubkey: recipient.public,
        );
        return Event.from(
          kind: GiftWrap.kindGiftWrap,
          tags: [
            ['p', recipient.public]
          ],
          content: wrapCiphertext,
          secretKey: ephemeral.secret,
        );
      }

      test('rejects a signed rumor (rumorMustBeUnsigned)', () async {
        // A rumor carrying a signature breaks deniability — the spec says
        // the inner event MUST always be unsigned.
        final signedRumor = Event.from(
          kind: 1,
          content: 'i am signed',
          secretKey: author.secret,
        );
        final wrap = await wrapManually(
          signedRumor.toJson(),
          author.secret,
          recipient,
        );
        await expectLater(
          Nip59.unwrap(giftWrap: wrap, recipientSecretKey: recipient.secret),
          throwsA(isA<CryptoException>().having(
            (e) => e.code,
            'code',
            CryptoErrorCode.rumorMustBeUnsigned,
          )),
        );
      });

      test('rejects a rumor whose pubkey differs from the seal author',
          () async {
        // Impersonation attempt: the seal is signed by the attacker but
        // the rumor claims a victim's pubkey. NIP-17: "Clients MUST
        // verify if pubkey of the kind:13 is the same pubkey as that of
        // the unsignedMessageRumor".
        final victim = Keys.generate();
        final attacker = Keys.generate();
        final rumorJson = json.encode({
          'id': '',
          'pubkey': victim.public,
          'created_at': 1700000000,
          'kind': 1,
          'tags': [],
          'content': 'spoofed',
        });
        final wrap = await wrapManually(rumorJson, attacker.secret, recipient);
        await expectLater(
          Nip59.unwrap(giftWrap: wrap, recipientSecretKey: recipient.secret),
          throwsA(isA<CryptoException>().having(
            (e) => e.code,
            'code',
            CryptoErrorCode.sealAuthorMismatch,
          )),
        );
      });

      test('rejects a gift wrap with an invalid signature', () async {
        final rumor = Event.partial(
          pubkey: author.public,
          content: 'hello',
          createdAt: 1700000000,
        );
        final giftWrap = await Nip59.wrap(
          rumor: rumor,
          authorSecretKey: author.secret,
          recipientPubkey: recipient.public,
        );
        // Re-sign the wrap's content with a DIFFERENT key while keeping
        // the original ephemeral pubkey — the signature no longer matches.
        final attacker = Keys.generate();
        final tampered = Event.from(
          kind: giftWrap.kind,
          tags: giftWrap.tags,
          content: giftWrap.content,
          secretKey: attacker.secret,
          pubkey: giftWrap.pubkey,
          createdAt: giftWrap.createdAt,
        );
        await expectLater(
          Nip59.unwrap(giftWrap: tampered, recipientSecretKey: recipient.secret),
          throwsA(isA<CryptoException>().having(
            (e) => e.code,
            'code',
            CryptoErrorCode.invalidGiftWrapSignature,
          )),
        );
      });

      test('unwrap with the wrong recipient key fails at the MAC check',
          () async {
        final rumor = Event.partial(
          pubkey: author.public,
          content: 'for your eyes only',
          createdAt: 1700000000,
        );
        final giftWrap = await Nip59.wrap(
          rumor: rumor,
          authorSecretKey: author.secret,
          recipientPubkey: recipient.public,
        );
        final eavesdropper = Keys.generate();
        await expectLater(
          Nip59.unwrap(
              giftWrap: giftWrap, recipientSecretKey: eavesdropper.secret),
          throwsA(isA<CryptoException>().having(
            (e) => e.code,
            'code',
            CryptoErrorCode.invalidMac,
          )),
        );
      });
    });
  });
}
