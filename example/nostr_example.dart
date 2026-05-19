import 'dart:io';
import 'package:nostr/nostr.dart';

void main() async {
  // Use the Keys class to manipulate secret/public keys and use handy methods encapsulated from dart-bip340
  final keys = Keys(
    "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  );
  assert(keys.public ==
      "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b");

  // or generate random keys
  final randomKeys = Keys.generate();
  print(randomKeys.secret);

  // Instantiate an event from raw fields. By default the constructor
  // validates id + signature and throws EventValidationException if
  // either is wrong. Use verify: false when reconstructing untrusted
  // third-party event copies.
  //
  // Here we sign a fresh event with the secret key so the test data is
  // genuinely valid rather than hardcoded.
  final signed = Event.from(
    kind: 1,
    tags: [],
    content: 'Ceci est une analyse du websocket',
    secretKey: keys.secret,
  );
  final oneEvent = Event(
    signed.id,
    signed.pubkey,
    signed.createdAt,
    signed.kind,
    signed.tags,
    signed.content,
    signed.sig,
  );
  assert(oneEvent.id == signed.id);

  // Create a partial event from nothing and fill it with data until it is valid
  final partialEvent = Event.partial();
  assert(partialEvent.isValid() == false);
  partialEvent
    ..createdAt = currentUnixTimestampSeconds()
    ..pubkey =
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b"
    ..id = partialEvent.getEventId()
    ..sig = partialEvent.getSignature(
      "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
    );
  assert(partialEvent.isValid() == true);

  // Instantiate an event with a partial data and let the library sign the event with your secret key
  final Event anotherEvent = Event.from(
    kind: 1,
    tags: [],
    content: "vi veri universum vivus vici",
    secretKey:
        "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12", // DO NOT REUSE THIS PRIVATE KEY
  );

  assert(anotherEvent.pubkey ==
      "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b");

  // Connecting to a nostr relay using websocket
  final WebSocket webSocket = await WebSocket.connect(
    'wss://nos.lol', // or any nostr relay
  );

  // Send an event to the WebSocket server
  webSocket.add(anotherEvent.serialize());

  // Listen for events from the WebSocket server
  await Future.delayed(const Duration(seconds: 1));
  webSocket.listen((event) {
    print('Received event: $event');
  });

  // Close the WebSocket connection
  await webSocket.close();
}
