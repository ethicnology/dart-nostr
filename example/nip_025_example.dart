import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const eventId =
      'a60679692533b308f1d862c2a5ca5c08a304e5157b1df5cde0ff0454b9920605';
  const eventPubkey =
      '7c579328cf9028a4548d5117afa4f8448fb510ca9023f576b7bc90fc5be6ce7e';

  // Encode a like reaction
  final like = Nip25.create(
    eventId: eventId,
    eventPubkey: eventPubkey,
    secretKey: secretKey,
  );
  assert(like.kind == 7);
  assert(like.content == '+');

  // Encode a custom reaction
  final custom = Nip25.create(
    eventId: eventId,
    eventPubkey: eventPubkey,
    secretKey: secretKey,
    content: '🤙',
  );
  assert(custom.content == '🤙');

  // Decode a reaction
  final reaction = Nip25.parse(like);
  assert(reaction.eventId == eventId);
  assert(reaction.reactedPubkey == eventPubkey);
  assert(reaction.content == '+');
}
