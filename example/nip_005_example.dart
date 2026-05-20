import 'package:nostr/nostr.dart';

void main() async {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip5.create(
    name: 'alice',
    domain: 'example.com',
    relays: ['wss://relay.example.com'],
    secretKey: secretKey,
  );
  assert(event.kind == 0);

  final url = Nip5.verificationUrl('alice@example.com');
  assert(url.toString() ==
      'https://example.com/.well-known/nostr.json?name=alice');
  print('Verification URL: $url');

  // Fetch NIP-05 data from DNS (live lookup)
  final dnsData = await Nip5.fetch('_@yukikishimoto.com');
  if (dnsData != null) {
    print('Fetched pubkey: ${dnsData.pubkey}');
    print('Relays: ${dnsData.relays}');
  }

  // Verify a NIP-05 identifier against a pubkey (live DNS lookup)
  final isValid = await Nip5.verify(
    identifier: '_@yukikishimoto.com',
    pubkey: '68d81165918100b7da43fc28f7d1fc12554466e1115886b9e7bb326f65ec4272',
  );
  print('_@yukikishimoto.com verified: $isValid');
}
