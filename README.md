[![License: LGPL v3](https://img.shields.io/badge/License-LGPL_v3-blue.svg)](https://www.gnu.org/licenses/lgpl-3.0)
[![nostr CI](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml/badge.svg)](https://github.com/ethicnology/dart-nostr/actions/workflows/dart-test.yml)
[![pub package](https://img.shields.io/pub/v/nostr.svg)](https://pub.dartlang.org/packages/nostr)
[![codecov](https://codecov.io/gh/ethicnology/dart-nostr/branch/main/graph/badge.svg?token=RNIA9IIRB6)](https://codecov.io/gh/ethicnology/dart-nostr)
# nostr
A Flutter library for Nostr implemented in Dart.

[Dispute](https://github.com/ethicnology/dispute) is a basic nostr client written in flutter with this library that will show you an implementation.

## Getting started
```sh
flutter pub add nostr
```


## [NIPS](https://github.com/nostr-protocol/nips)
- [x] [NIP-01 Basic protocol flow](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [x] [NIP-02 Follow List and Petnames](https://github.com/nostr-protocol/nips/blob/master/02.md)
- [x] [NIP-05 DNS-based Internet Identifiers](https://github.com/nostr-protocol/nips/blob/master/05.md)
- [x] [NIP-09 Event Deletion Request](https://github.com/nostr-protocol/nips/blob/master/09.md)
- [x] [NIP-10 Text Note Threading](https://github.com/nostr-protocol/nips/blob/master/10.md)
- [x] [NIP-11 Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md)
- [x] [NIP-13 Proof of Work](https://github.com/nostr-protocol/nips/blob/master/13.md)
- [x] [NIP-17 Private Direct Messages](https://github.com/nostr-protocol/nips/blob/master/17.md)
- [x] [NIP-18 Reposts](https://github.com/nostr-protocol/nips/blob/master/18.md)
- [x] [NIP-19 Bech32-encoded Entities](https://github.com/nostr-protocol/nips/blob/master/19.md)
- [x] [NIP-20 Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
- [x] [NIP-21 nostr: URI Scheme](https://github.com/nostr-protocol/nips/blob/master/21.md)
- [x] [NIP-22 Comments](https://github.com/nostr-protocol/nips/blob/master/22.md)
- [x] [NIP-23 Long-form Content](https://github.com/nostr-protocol/nips/blob/master/23.md)
- [x] [NIP-25 Reactions](https://github.com/nostr-protocol/nips/blob/master/25.md)
- [x] [NIP-27 Text Note References](https://github.com/nostr-protocol/nips/blob/master/27.md)
- [x] [NIP-28 Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md)
- [x] [NIP-29 Relay-based Groups](https://github.com/nostr-protocol/nips/blob/master/29.md)
- [x] [NIP-32 Labeling](https://github.com/nostr-protocol/nips/blob/master/32.md)
- [x] [NIP-38 User Statuses](https://github.com/nostr-protocol/nips/blob/master/38.md)
- [x] [NIP-40 Expiration Timestamp](https://github.com/nostr-protocol/nips/blob/master/40.md)
- [x] [NIP-42 Authentication](https://github.com/nostr-protocol/nips/blob/master/42.md)
- [x] [NIP-44 Encrypted Payloads (Versioned)](https://github.com/nostr-protocol/nips/blob/master/44.md)
- [~] [NIP-46 Nostr Connect](https://github.com/nostr-protocol/nips/blob/master/46.md) — kind 24133 event envelope only. No `bunker://` / `nostrconnect://` URI parsing, no JSON-RPC method encoders. Bring your own.
- [~] [NIP-47 Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md) — kind 13194/2319x event envelopes only. No `nostr+walletconnect://` URI parsing, no JSON-RPC method encoders.
- [x] [NIP-50 Search Capability](https://github.com/nostr-protocol/nips/blob/master/50.md)
- [~] [NIP-51 Lists](https://github.com/nostr-protocol/nips/blob/master/51.md) — create helpers for kinds 10000/10001/30000/30001 only. Other list kinds (10003-10102, 30002-30030, etc.) need to be built by hand using `Event.from`.
- [x] [NIP-53 Live Activities](https://github.com/nostr-protocol/nips/blob/master/53.md)
- [x] [NIP-57 Lightning Zaps](https://github.com/nostr-protocol/nips/blob/master/57.md)
- [x] [NIP-58 Badges](https://github.com/nostr-protocol/nips/blob/master/58.md)
- [x] [NIP-59 Gift Wrap](https://github.com/nostr-protocol/nips/blob/master/59.md)
- [x] [NIP-65 Relay List Metadata](https://github.com/nostr-protocol/nips/blob/master/65.md)
- [x] [NIP-72 Moderated Communities](https://github.com/nostr-protocol/nips/blob/master/72.md)
- [x] [NIP-89 Application Handlers](https://github.com/nostr-protocol/nips/blob/master/89.md)
- [x] [NIP-94 File Metadata](https://github.com/nostr-protocol/nips/blob/master/94.md)
- [x] [NIP-98 HTTP Auth](https://github.com/nostr-protocol/nips/blob/master/98.md)


## Usage

```dart
import 'package:nostr/nostr.dart';

// Generate or import keys
final keys = Keys.generate();
print('Public key: ${keys.public}');
print('npub: ${keys.npub}');

// Create and sign an event
final event = Event.from(
  kind: 1,
  tags: [],
  content: 'Hello Nostr!',
  secretKey: keys.secret,
);

// Serialize for relay
print(event.serialize());

// Subscribe to events
final request = Request(
  subscriptionId: generateRandomHex(),
  filters: [const Filter(kinds: [1], limit: 10)],
);
print(request.serialize());
```

For more examples, see the [example/](https://github.com/ethicnology/dart-nostr/tree/develop/example) directory.
