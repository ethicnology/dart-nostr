import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const relay = 'wss://relay.example.com';
  const challenge = 'random-challenge-string';

  final event = Nip42.encode(
    challenge: challenge,
    relayUrl: relay,
    secretKey: secretKey,
  );
  assert(event.kind == 22242);

  final valid = Nip42.validate(
    event: event,
    relayUrl: relay,
    challenge: challenge,
  );
  assert(valid == true);
  print('Auth valid: $valid');
}
