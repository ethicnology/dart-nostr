import 'package:nostr/nostr.dart';

Future<void> main() async {
  const alice =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const bob =
      'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';

  final giftWrap = await Nip17.encode(
    message: 'Hey Bob, how are you?',
    authorSecretKey: alice,
    receiverPubkey: Keys(bob).public,
  );
  assert(giftWrap.kind == 1059);

  final dm = await Nip17.decode(
    giftWrap: giftWrap,
    receiverSecretKey: bob,
  );
  assert(dm.content == 'Hey Bob, how are you?');
  print('DM: ${dm.content}');
}
