import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final original = Event.from(
    kind: 1,
    tags: [],
    content: 'Original post',
    secretKey: secretKey,
  );

  final repost = Nip18.encode(
    originalEvent: original,
    secretKey: secretKey,
    relay: 'wss://relay.example.com',
  );
  assert(repost.kind == 6);

  final decoded = Nip18.decode(repost);
  assert(decoded.eventId == original.id);
  print('Reposted event: ${decoded.eventId}');
}
