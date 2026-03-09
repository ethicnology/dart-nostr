import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Encode a relay list (kind 10002)
  final event = Nip65.create(
    relays: [
      const RelayMetadata(url: 'wss://relay.damus.io', read: true, write: true),
      const RelayMetadata(url: 'wss://nos.lol', read: true, write: false),
      const RelayMetadata(url: 'wss://relay.nostr.band', read: false, write: true),
    ],
    secretKey: secretKey,
  );
  assert(event.kind == 10002);
  assert(event.tags[0] == ['r', 'wss://relay.damus.io']);
  assert(event.tags[1] == ['r', 'wss://nos.lol', 'read']);
  assert(event.tags[2] == ['r', 'wss://relay.nostr.band', 'write']);

  // Decode a relay list
  final relays = Nip65.parse(event);
  assert(relays.length == 3);
  assert(relays[0].url == 'wss://relay.damus.io');
  assert(relays[0].read == true);
  assert(relays[0].write == true);
  assert(relays[1].write == false); // read-only relay
}
