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

  // Instantiate an event with all the field
  const id = "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  final pubkey = keys.public;
  const createdAt = 1672175320;
  const kind = 1;
  final tags = [<String>[]];
  const content = "Ceci est une analyse du websocket";
  const sig =
      "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

  final oneEvent = Event(
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig,
  );
  assert(oneEvent.id ==
      "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49");

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
    privkey:
        "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12", // DO NOT REUSE THIS PRIVATE KEY
  );

  assert(anotherEvent.pubkey ==
      "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b");

  // Connecting to a nostr relay using websocket
  final WebSocket webSocket = await WebSocket.connect(
    'wss://relay.nostr.info', // or any nostr relay
  );
  // if the current socket fail try another one
  // wss://nostr.sandwich.farm
  // wss://relay.damus.io

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
