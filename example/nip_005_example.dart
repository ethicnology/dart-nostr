import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip5.encode(
    name: 'alice',
    domain: 'example.com',
    relays: ['wss://relay.example.com'],
    secretKey: secretKey,
  );
  assert(event.kind == 0);

  final url = Nip5.verificationUrl('alice@example.com');
  assert(url.toString() == 'https://example.com/.well-known/nostr.json?name=alice');
  print('Verification URL: $url');
}
