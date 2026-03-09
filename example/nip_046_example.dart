import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const targetPubkey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  final event = Nip46.encode(
    encryptedContent: '{"id":"1","method":"sign_event","params":[]}',
    targetPubkey: targetPubkey,
    secretKey: secretKey,
  );
  assert(event.kind == 24133);

  final decoded = Nip46.decode(event);
  assert(decoded.targetPubkey == targetPubkey);
  print('Nostr Connect to: ${decoded.targetPubkey}');
}
