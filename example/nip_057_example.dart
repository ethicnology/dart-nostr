import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const recipientPubkey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  // Encode a zap request (kind 9734)
  final zapRequest = Nip57.request(
    recipientPubkey: recipientPubkey,
    relays: ['wss://relay.damus.io', 'wss://nos.lol'],
    secretKey: secretKey,
    content: 'Great post!',
    eventId: 'a60679692533b308f1d862c2a5ca5c08a304e5157b1df5cde0ff0454b9920605',
    amount: BigInt.from(21000), // millisats
  );
  assert(zapRequest.kind == 9734);
  assert(findTagValue(zapRequest.tags, 'p') == recipientPubkey);
  assert(findTagValue(zapRequest.tags, 'amount') == '21000');

  // Decode a zap request
  final decoded = Nip57.parseRequest(zapRequest);
  assert(decoded.recipientPubkey == recipientPubkey);
  assert(decoded.amount == BigInt.from(21000));
  assert(decoded.content == 'Great post!');
  assert(decoded.relays.length == 2);
}
