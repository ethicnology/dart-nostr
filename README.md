[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![nostr CI](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml/badge.svg)](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml)
[![pub package](https://img.shields.io/pub/v/nostr.svg)](https://pub.dartlang.org/packages/nostr)
[![codecov](https://codecov.io/gh/ethicnology/dart-nostr/branch/main/graph/badge.svg?token=RNIA9IIRB6)](https://codecov.io/gh/ethicnology/dart-nostr)
# nostr
A library for nostr protocol implemented in dart for flutter

## Getting started
```sh
flutter pub add nostr
```


## [NIPS](https://github.com/nostr-protocol/nips)
* [NIP01 Events and signature](https://github.com/nostr-protocol/nips/blob/master/01.md)

## Usage

```dart
import 'dart:io';
import 'package:nostr/nostr.dart';

void main() async {
  String id =
      "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  String pubKey =
      "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  int createdAt = 1672175320;
  int kind = 1;
  List<List<String>> tags = [];
  String content = "Ceci est une analyse du websocket";
  String sig =
      "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

  // Instanciate an event with all the field
  Event oneEvent = Event(
    id,
    pubKey,
    createdAt,
    kind,
    tags,
    content,
    sig,
  );

  print(oneEvent.id);
  // 4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49

  // Instanciate an event with a partial data and let the library sign the event with your private key
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
    'wss://nostr.sandwich.farm', // or any nostr relay
  );

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