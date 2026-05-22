import 'package:nostr/nostr.dart';

Future<void> main() async {
  const alice =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const bob =
      'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';

  final rumor = Event.partial(
    content: 'Secret rumor content',
    pubkey: Keys(alice).public,
  );

  final giftWrap = await Nip59.wrap(
    rumor: rumor,
    authorSecretKey: alice,
    recipientPubkey: Keys(bob).public,
  );
  assert(giftWrap.kind == 1059);
  print('Gift wrap created (kind ${giftWrap.kind})');

  final unwrapped = await Nip59.unwrap(
    giftWrap: giftWrap,
    recipientSecretKey: bob,
  );
  assert(unwrapped.content == 'Secret rumor content');
  print('Unwrapped: ${unwrapped.content}');
}
