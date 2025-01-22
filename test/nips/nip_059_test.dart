import 'package:test/test.dart';
import 'package:nostr/nostr.dart';

void main() {
  group('NIP-59 Gift Wrap Tests', () {
    // Example from the spec
    final authorPrivkey =
        '0beebd062ec8735f4243466049d7747ef5d6594ee838de147f8aab842b15e273';
    final recipientPrivkey =
        'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';
    final ephemeralPrivkey =
        '4f02eac59266002db5801adc5270700ca69d5b8f761d8732fab2fbf233c90cbd';

    final rumorContent = 'Are you going to the party tonight?';
    final rumorCreatedAt = 1691518405;
    final rumorPubkey =
        '611df01bfcf85c26ae65453b772d8f1dfd25c264621c0277e1fc1518686faef9';

    test('Wrap & Unwrap yields the same rumor content (NIP-59 example)',
        () async {
      // 1) Construct an UNSIGNED rumor (kind=1, no .id, no .sig)
      //    If your "Event" constructor auto-signs, you may need to forcibly remove .id/.sig.
      final rumor = Event.partial(
        kind: 1,
        tags: [],
        content: rumorContent,
        createdAt: rumorCreatedAt,
        pubkey: rumorPubkey,
      );

      // 2) Wrap the rumor:
      //    - Seal => kind=13 => signed by author
      //    - GiftWrap => kind=1059 => signed by ephemeral
      //    We'll explicitly specify ephemeralPrivkey from the spec.
      final giftWrap = await Nip59.wrap(
        rumor: rumor,
        authorPrivkey: authorPrivkey,
        recipientPubkey: Keychain(recipientPrivkey).public,
        ephemeralPrivkey: ephemeralPrivkey,
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
        recipientPrivkey: recipientPrivkey,
      );

      // The unwrapped rumor should be kind=1, no signature, same content
      expect(unwrappedRumor.kind, 1);
      expect(unwrappedRumor.content, rumorContent);
      expect(unwrappedRumor.sig, isEmpty, reason: 'Rumor must remain unsigned');
      expect(unwrappedRumor.id, isEmpty,
          reason: 'Rumor is never broadcast as itself');
    });
  });
}
