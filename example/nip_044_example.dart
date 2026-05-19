import 'package:nostr/nostr.dart';

Future<void> main() async {
  const alice =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const bob =
      'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';

  final ciphertext = await Nip44.encrypt(
    plaintext: 'Secret message for Bob',
    senderSecretKey: alice,
    recipientPubkey: Keys(bob).public,
  );
  print('Encrypted: $ciphertext');

  final plaintext = await Nip44.decrypt(
    payload: ciphertext,
    recipientSecretKey: bob,
    senderPubkey: Keys(alice).public,
  );
  assert(plaintext == 'Secret message for Bob');
  print('Decrypted: $plaintext');
}
