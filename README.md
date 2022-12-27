[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![nostr CI](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml/badge.svg)](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml)
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
import 'package:nostr/nostr.dart';

void main() {
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

  Event event = Event(
    id,
    pubKey,
    createdAt,
    kind,
    tags,
    content,
    sig,
  );

  print(event.id);
  // 4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49

  Event event2 = Event.from(
    createdAt: 1672175320,
    kind: 1,
    tags: [],
    content: "Ceci est une analyse du websocket",
    privkey:
        "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12", // DO NOT REUSE THIS PRIVATE KEY
  );

  print(event2.id == event1.id);
  // true
  print(event2.pubkey == event1.pubkey);
  // true
}

```