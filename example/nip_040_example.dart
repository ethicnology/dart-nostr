import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Create expiration tag (expires in 1 hour)
  final expiresAt = currentUnixTimestampSeconds() + 3600;
  final tag = Expiration.tag(expiresAt);
  assert(tag[0] == 'expiration');
  print('Expiration tag: $tag');

  // Create an event with an expiration tag
  final event = Event.from(
    kind: 1,
    tags: [tag],
    content: 'This note expires in 1 hour',
    secretKey: secretKey,
  );

  assert(!Expiration.isExpired(event));
  print('Expires at: ${Expiration.findExpiration(event)}');
  print('Is expired: ${Expiration.isExpired(event)}');
}
