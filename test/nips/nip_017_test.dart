import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() async {
  const authorNsec =
      'nsec1w8udu59ydjvedgs3yv5qccshcj8k05fh3l60k9x57asjrqdpa00qkmr89m';
  final author = Keys(authorNsec);

  const recipientNsec =
      'nsec12ywtkplvyq5t6twdqwwygavp5lm4fhuang89c943nf2z92eez43szvn4dt';
  final recipient = Keys(recipientNsec);

  const message = 'Hola, que tal?';

  final dm = await Nip17.create(
    authorSecretKey: author.secret,
    receiverPubkey: recipient.public,
    message: message,
  );

  group('NIP-17 Direct Message', () {
    test('encode a direct message', () async {
      expect(dm.kind, 1059);
      expect(dm.tags, [
        [
          "p",
          "918e2da906df4ccd12c8ac672d8335add131a4cf9d27ce42b3bb3625755f0788"
        ]
      ]);
    });

    test('decode a direct message', () async {
      final x = await Nip17.parse(
        giftWrap: dm,
        receiverSecretKey: recipient.secret,
      );

      expect(x.kind, 14);
      expect(x.pubkey, author.public);
      expect(x.sig, isEmpty);
      expect(x.tags, [
        [
          "p",
          "918e2da906df4ccd12c8ac672d8335add131a4cf9d27ce42b3bb3625755f0788"
        ]
      ]);
    });
  });
}
