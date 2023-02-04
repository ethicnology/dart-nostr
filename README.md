[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![nostr CI](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml/badge.svg)](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml)
[![pub package](https://img.shields.io/pub/v/nostr.svg)](https://pub.dartlang.org/packages/nostr)
[![codecov](https://codecov.io/gh/ethicnology/dart-nostr/branch/main/graph/badge.svg?token=RNIA9IIRB6)](https://codecov.io/gh/ethicnology/dart-nostr)
# nostr
A library for nostr protocol implemented in dart for flutter.  

[Dispute](https://github.com/ethicnology/dispute) is a basic nostr client written in flutter with this library that will show you an implementation.   

## Getting started
```sh
flutter pub add nostr
```


## [NIPS](https://github.com/nostr-protocol/nips)
- [x] [NIP01 Events and signature](https://github.com/nostr-protocol/nips/blob/master/01.md#events-and-signatures)
- [x] [NIP01 Request and filters](https://github.com/nostr-protocol/nips/blob/master/01.md#communication-between-clients-and-relays)
- [x] [NIP01 Close](https://github.com/nostr-protocol/nips/blob/master/01.md#communication-between-clients-and-relays)
- [x] [NIP15 EOSE](https://github.com/nostr-protocol/nips/blob/master/15.md)
- [x] [NIP20 OK](https://github.com/nostr-protocol/nips/blob/master/20.md)

## Usage
### Events messages
```dart
import 'dart:io';
import 'package:nostr/nostr.dart';

void main() async {
  // Use the Keychain class to manipulate private/public keys and use handy methods encapsulated from dart-bip340
  var keys = Keychain(
    "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  );
  print(keys.public ==
      "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b");

  // Generate random keys
  var randomKeys = Keychain.generate();
  print(randomKeys.private);

  // Instantiate an event with all the field
  String id =
      "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  String pubkey = keys.public;
  int createdAt = 1672175320;
  int kind = 1;
  List<List<String>> tags = [];
  String content = "Ceci est une analyse du websocket";
  String sig =
      "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

  Event oneEvent = Event(
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig,
  );

  print(oneEvent.id);
  // 4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49

  // Instantiate an event with a partial data and let the library sign the event with your private key
  Event anotherEvent = Event.from(
    kind: 1,
    tags: [],
    content: "vi veri universum vivus vici",
    privkey:
        "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12", // DO NOT REUSE THIS PRIVATE KEY
  );

  print(anotherEvent.pubkey);
  // 981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b

  // Connecting to a nostr relay using websocket
  WebSocket webSocket = await WebSocket.connect(
    'wss://relay.nostr.info', // or any nostr relay
  );
  // if the current socket fail try another one
  // wss://nostr.sandwich.farm
  // wss://relay.damus.io

  // Send an event to the WebSocket server
  webSocket.add(anotherEvent.serialize());

  // Listen for events from the WebSocket server
  await Future.delayed(Duration(seconds: 1));
  webSocket.listen((event) {
    print('Received event: $event');
  });

  // Close the WebSocket connection
  await webSocket.close();
}
```

### Request messages and filters
```dart
import 'dart:io';
import 'package:nostr/nostr.dart';

void main() async {
// Create a subscription message request with one or many filters
  Request requestWithFilter = Request(generate64RandomHexChars(), [
    Filter(
      kinds: [0, 1, 2, 7],
      since: 1674063680,
      limit: 450,
    )
  ]);

  // Connecting to a nostr relay using websocket
  WebSocket webSocket = await WebSocket.connect(
    'wss://relay.nostr.info', // or any nostr relay
  );
  // if the current socket fail try another one
  // wss://nostr.sandwich.farm
  // wss://relay.damus.io

  // Send a request message to the WebSocket server
  webSocket.add(requestWithFilter.serialize());

  // Listen for events from the WebSocket server
  await Future.delayed(Duration(seconds: 1));
  webSocket.listen((event) {
    print('Received event: $event');
  });

  // Close the WebSocket connection
  await webSocket.close();
}
```

### Close subscription
```dart
import 'package:nostr/nostr.dart';

void main() async {
  String subscriptionId = generate64RandomHexChars();
  var close1 = Close(subscriptionId);
  assert(close1.subscriptionId == subscriptionId);

  var close2 = Close(subscriptionId);
  assert(close2.serialize() == '["CLOSE","$subscriptionId"]');

  var close3 = Close.deserialize(["CLOSE", subscriptionId]);
  assert(close3.subscriptionId == subscriptionId);
}
```

### Any nostr message deserializer  
```dart
import 'package:nostr/nostr.dart';

void main() async {
  var eventPayload =
      '["EVENT","3979053091133091",{"id":"a60679692533b308f1d862c2a5ca5c08a304e5157b1df5cde0ff0454b9920605","pubkey":"7c579328cf9028a4548d5117afa4f8448fb510ca9023f576b7bc90fc5be6ce7e","created_at":1674405882,"kind":1,"tags":[],"content":"GM gm gm! Currently bathing my brain in coffee âï¸  hahaha. How many other nostrinos love coffee? ð¤ªð¤","sig":"10262aa6a83e0b744cda2097f06f7354357512b82846f6ef23ef7d997136b64815c343b613a0635a27da7e628c96ac2475f66dd72513c1fb8ce6560824eb25b8"}]';
  var event = Message.deserialize(eventPayload);
  assert(event.type == "EVENT");
  assert(event.message.id ==
      "a60679692533b308f1d862c2a5ca5c08a304e5157b1df5cde0ff0454b9920605");

  String requestPayload =
      '["REQ","22055752544101437",{"kinds":[0,1,2,7],"since":1674320733,"limit":450}]';
  var req = Message.deserialize(requestPayload);
  assert(req.type == "REQ");
  assert(req.message.filters[0].limit == 450);

  String closePayload = '["CLOSE","anyrandomstring"]';
  var close = Message.deserialize(closePayload);
  assert(close.type == "CLOSE");
  assert(close.message.subscriptionId == "anyrandomstring");

  String noticePayload =
      '["NOTICE", "restricted: we can\'t serve DMs to unauthenticated users, does your client implement NIP-42?"]';
  var notice = Message.deserialize(noticePayload);
  assert(notice.type == "NOTICE");

  String eosePayload = '["EOSE", "random"]';
  var eose = Message.deserialize(eosePayload);
  assert(eose.type == "EOSE");

  String okPayload =
      '["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, ""]';
  var ok = Message.deserialize(okPayload);
  assert(ok.type == "OK");
}
```
