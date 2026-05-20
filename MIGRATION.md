# Migration guide: v1.5.x → v2.0.0

dart-nostr v2.0.0 is a ground-up rewrite. **Every public class touched
the renamer**, NIP-04 plaintext DMs are gone, and the library is now
pure-protocol (no WebSocket transport — bring your own).

This guide is the shortest path from working v1 code to working v2 code.
It does NOT explain features new to v2; for that, see [CHANGELOG.md].

If you only do one thing: **read the section that matches each compile
error you hit, in order**. The errors will guide you through the
migration top-to-bottom.

---

## 0. Pubspec

```diff
 dependencies:
-  nostr: ^1.5.0
+  nostr: ^2.0.0
```

Then `dart pub get`.

---

## 1. Keys

`Keychain` was renamed `Keys` and tightened.

```diff
-import 'package:nostr/nostr.dart';
-
-final keychain = Keychain('a' * 64);
-print(keychain.private);
-print(keychain.public);
-final sig = keychain.sign('hello');
-final ok = Keychain.verify(keychain.public, 'hello', sig);
+import 'package:nostr/nostr.dart';
+
+final keys = Keys('a' * 64);
+print(keys.secret);
+print(keys.public);
+print(keys.nsec);             // new: bech32 nsec
+print(keys.npub);             // new: bech32 npub
+final sig = keys.sign(message: 'hello');
+final ok = Schnorr.verify(pubkey: keys.public, message: 'hello', sig: sig);
```

Notes:
- `Keys()` now **throws** if the input isn't exactly 64 hex chars.
- `Keys.sign(message: ...)` is named-only.
- `Keychain.verify` (static) is gone — use `Schnorr.verify`.

---

## 2. Events

`Event.from` is now all-named; `fromJson`/`toJson` were split into Map
and String variants for clarity.

```diff
-final event = Event.from(
-  'a' * 64,           // privkey
-  1,                  // kind
-  [],                 // tags
-  'Hello',            // content
-  1700000000,         // createdAt
-);
-final json = event.toJson();        // String
-final map  = event.toJson();        // Map (the same call, ambiguous!)
-final parsed = Event.fromJson(map);
+final event = Event.from(
+  kind: 1,
+  tags: [],
+  content: 'Hello',
+  secretKey: 'a' * 64,
+  // createdAt: 1700000000,   // optional, defaults to now
+);
+final jsonStr = event.toJson();         // String only
+final map     = event.toMap();          // Map only
+final parsed  = Event.fromMap(map);     // Map -> Event
+final parsedFromStr = Event.fromJson(jsonStr); // String -> Event
+final wire = Event.deserialize('["EVENT","$subId",${event.toJson()}]'); // relay frame -> Event
```

`Event.isValid()` still returns `bool` but is no longer based on the
old "10-digit `createdAt` string" check; it accepts any timestamp in
`(0, 253402300800)` and verifies id + signature via `Schnorr`.

---

## 3. Filters

`Filter` is now `const`-constructible and uses spelled-out tag fields.

```diff
-var filter = Filter()
-  ..kinds = [1]
-  ..e = ['abc']
-  ..p = ['def']
-  ..a = ['30023:pubkey:slug']
-  ..limit = 50;
+final filter = Filter(
+  kinds: [1],
+  eTags: ['abc'],
+  pTags: ['def'],
+  aTags: ['30023:pubkey:slug'],
+  // new: generic single-letter tag filter
+  tagFilters: {'d': ['my-d-tag'], 't': ['nostr', 'dart']},
+  limit: 50,
+);
```

All fields are `final`. To "modify" a filter, build a new one.

---

## 4. Subscriptions

`Request` is named-only.

```diff
-final req = Request('sub-id', [Filter()..kinds = [1]]);
+final req = Request(
+  subscriptionId: 'sub-id',
+  filters: [Filter(kinds: [1])],
+);
```

---

## 5. Relay messages

Every `deserialize` factory now takes a raw JSON **string**, not a
pre-decoded `List<dynamic>`. This matches what comes out of a
WebSocket directly.

```diff
-final close = Close.deserialize(['CLOSE', 'sub-id']);
-final eose  = Eose.deserialize(['EOSE', 'sub-id']);
-final msg   = Message.deserialize(rawListFromJsonDecode);
+final close = Close.deserialize('["CLOSE","sub-id"]');
+final eose  = Eose.deserialize('["EOSE","sub-id"]');
+final msg   = Message.deserialize(rawWebSocketFrame); // String
```

If you were calling `json.decode()` first and feeding a `List`, drop
the `json.decode` and pass the raw frame.

---

## 6. NIP class renames

Every `NipN` class got a domain name. The `NipN` typedef alias still
works, so existing code mostly compiles — but new code should use the
descriptive name.

| Old | New |
|-----|-----|
| `Nip1`  | `Note` |
| `Nip2`  | `FollowList` |
| `Nip5`  | `DnsIdentifier` |
| `Nip9`  | `Deletion` |
| `Nip10` | `Threading` |
| `Nip13` | `ProofOfWork` |
| `Nip19` | `Bech32Entity` |
| `Nip20` | `CommandResult` |
| `Nip28` | `PublicChat` |
| `Nip51` | `UserList` |

All other NIPs in v2 were not present in v1.5 and don't need migration.

---

## 7. NIP-04 plaintext DMs are removed

This is the biggest functional change. NIP-04 had cryptographic issues
(no padding, metadata leakage) and is deprecated upstream. v2 ships
NIP-17 + NIP-59 (gift-wrapped DMs) over NIP-44 v2 instead.

```diff
-import 'package:nostr/nostr.dart';
-
-final crypted = Nip4.encrypt(senderPrivKey, receiverPubKey, 'hello');
-final cleartext = Nip4.decrypt(receiverPrivKey, senderPubKey, crypted);
+import 'package:nostr/nostr.dart';
+
+final wrap = await DirectMessage.create(
+  message: 'hello',
+  authorSecretKey: senderSecretKey,
+  recipientPubkey: receiverPubkey,
+);
+// publish `wrap` (a kind-1059 event) to relays.
+
+// On the receiving side:
+final inner = await DirectMessage.parse(
+  giftWrap: wrap,
+  recipientSecretKey: receiverSecretKey,
+);
+print(inner.content);  // 'hello'
```

Helpers `kepler.dart`, `crypto/operator.dart`, `crypto/nip_004.dart`
went with NIP-04. There is no v2 equivalent — switch to NIP-17.

---

## 8. NIP-01 (Note / Metadata)

```diff
-final note = Nip1.encodeTextNote(privkey, 'Hello');
-final meta = Nip1.encodeSetMetadata(privkey, '{"name":"alice"}');
-final parsed = Nip1.decodeTextNote(event);
+final note = Note.create(content: 'Hello', secretKey: secretKey);
+final meta = Note.setMetadata(
+  content: '{"name":"alice"}',
+  secretKey: secretKey,
+);
+final parsed = Note.parse(event);
+
+// new: kind constants
+Note.kindMetadata;   // 0
+Note.kindShortNote;  // 1
```

`Note.parse` also accepts NIP-29 kinds 11 and 12 (group thread root /
reply); see new public field `NoteData.groupId`.

---

## 9. NIP-02 (Follow list)

```diff
-final tags = Nip2.toTags([Profile(pubkey, relay, petname)]);
-final event = Nip2.encode(privkey, profiles, '');
-final profiles = Nip2.decode(event);
+final event = FollowList.create(
+  profiles: [ProfileData(pubkey: 'a' * 64, relay: 'wss://r', petname: 'x')],
+  secretKey: secretKey,
+);
+final profiles = FollowList.parse(event);  // List<ProfileData>
+
+// new: kind constant
+FollowList.kindFollowList;  // 3
```

The model is `ProfileData` (was `Profile`). `typedef Profile = ProfileData`
is provided so old code still compiles.

---

## 10. NIP-05 (DNS identifiers)

```diff
-final event = Nip5.encode(privkey, 'alice', 'example.com', ['wss://r']);
-final dns = await Nip5.decode(event);
+final event = DnsIdentifier.create(
+  name: 'alice',
+  domain: 'example.com',
+  relays: ['wss://r'],
+  secretKey: secretKey,
+);
+final dns = await DnsIdentifier.parse(event);  // Future<DnsData?>
+
+// new in v2: actually fetch / verify the identifier
+final fetched = await DnsIdentifier.fetch('alice@example.com');
+final ok = await DnsIdentifier.verify(
+  identifier: 'alice@example.com',
+  pubkey: 'expected-hex-pubkey',
+);
```

---

## 11. NIP-09 (Deletion)

```diff
-final delEvent = Nip9.encode(privkey, ['evt-id-1', 'evt-id-2']);
-final ids = Nip9.toDeleteEvent(event);
+final delEvent = Deletion.create(
+  secretKey: secretKey,
+  eventIds: ['evt-id-1', 'evt-id-2'],
+  // optional:
+  addressableCoords: ['30023:pubkey:my-article'],
+  kinds: [1, 30023],
+  content: 'these were published by accident',
+);
+final parsed = Deletion.parse(event);     // DeletionRequestData
+parsed.eventIds; parsed.addressableCoords; parsed.kinds;
```

`Deletion.create` now **throws** `InvalidArgumentException` if neither
`eventIds` nor `addressableCoords` is supplied — per spec, a deletion
event must reference at least one target.

---

## 12. NIP-10 (Threading)

```diff
-final thread = Nip10.fromTags(event.tags);
+final thread = Threading.parseTags(event.tags);
```

`fromTags` was renamed `parseTags` (symmetric with `toTags`).

---

## 13. NIP-19 (Bech32 entities)

This NIP got the heaviest API change. The old `encodePubkey` /
`encodeNote` family is gone — there's one `encode` + one
`encodeShareableIdentifiers` now.

```diff
-final npub = Nip19.encodePubkey(hexPubkey);
-final note = Nip19.encodeNote(hexEventId);
-final hex  = Nip19.decodePubkey(npub);
+final npub = Bech32Entity.encode(
+  prefix: Nip19Prefix.npub,
+  data: hexPubkey,
+);
+final note = Bech32Entity.encode(
+  prefix: Nip19Prefix.note,
+  data: hexEventId,
+);
+final decoded = Bech32Entity.decode(payload: npub);
+decoded.prefix;  // Nip19Prefix.npub
+decoded.data;    // hexPubkey
+
+// nprofile / nevent / naddr stay in the dedicated helper:
+final nprofile = Bech32Entity.encodeShareableIdentifiers(
+  prefix: Nip19Prefix.nprofile,
+  data: hexPubkey,
+  relays: ['wss://relay.example'],
+);
+
+// new: prefix-agnostic dispatcher when you don't know what you got
+final any = Bech32Entity.decodeAny(payload: 'nostr:...');
```

`Nip19` typedef still works as an alias for `Bech32Entity`. Method
names *did* change though — the typedef preserves the class name, not
the method names.

---

## 14. NIP-20 (Command Results)

```diff
-final result = Nip20.deserialize(['OK', eventId, true, 'reason']);
+final result = CommandResult.deserialize('["OK","$eventId",true,"reason"]');
```

---

## 15. NIP-28 (Public Chat)

Every method was renamed. Same pattern: `set*` / `send*` / `hide*` /
`get*` are gone; `create` / domain-verb / `parse*` replaces them.

```diff
-final channel = Nip28.createChannel(privkey, 'Name', 'About', picURL);
-final meta    = Nip28.setChannelMetaData(privkey, ...);
-final msg     = Nip28.sendChannelMessage(privkey, channelId, 'hi');
-final hide    = Nip28.hideChannelMessage(privkey, msgId);
-
-final parsedCreate  = Nip28.getChannelCreation(event);
-final parsedMeta    = Nip28.getChannelMetadata(event);
-final parsedMsg     = Nip28.getChannelMessage(event);
+final channel = PublicChat.channel(name: 'Name', about: 'About', picture: picURL, secretKey: secretKey);
+final meta    = PublicChat.channelMetadata(...);
+final msg     = PublicChat.channelMessage(channelId: id, content: 'hi', secretKey: secretKey);
+final hide    = PublicChat.hideMessage(messageId: msgId, reason: 'spam', secretKey: secretKey);
+
+final parsedCreate = PublicChat.parseChannel(event);
+final parsedMeta   = PublicChat.parseMetadata(event);
+final parsedMsg    = PublicChat.parseMessage(event);
+
+// new: kind constants
+PublicChat.kindChannelCreation;   // 40
+PublicChat.kindChannelMessage;    // 42
```

All builders now use named parameters and `secretKey:`.

---

## 16. NIP-51 (Lists)

Most disruptive of the carryover NIPs. All builders and the parser
changed; the parser is now **async** (NIP-44 decryption replaces NIP-04).

```diff
-final muteEvent = await Nip51.createMutePeople(privkey, peoples, encrypted);
-final pinEvent  = await Nip51.createPinEvent(privkey, items, encrypted);
-final catP      = await Nip51.createCategorizedPeople('mygroup', privkey, p, e);
-final catB      = await Nip51.createCategorizedBookmarks('reads', privkey, b, e);
-final lists     = Nip51.getLists(event, privkey);
+final muteEvent = await UserList.mutePeople(
+  publicContacts, encryptedContacts, secretKey, pubkey,
+);
+final pinEvent  = await UserList.pinEvent(
+  publicItems, encryptedItems, secretKey, pubkey,
+);
+final catP      = await UserList.categorizedPeople(
+  'mygroup', publicContacts, encryptedContacts, secretKey, pubkey,
+);
+final catB      = await UserList.categorizedBookmarks(
+  'reads', publicBookmarks, encryptedBookmarks, secretKey, pubkey,
+);
+final lists     = await UserList.parse(event, secretKey: secretKey);
```

`Contact` lost the `aliasPubKey` field — it's now `Contact(pubkey,
mainRelay, petName)` (3 args).

`UserListData` (was `UserList`) gains `hashtags`, `words`, `coordinates`
fields parsed from `t` / `word` / `a` tags.

---

## 17. Random / utils

```diff
-final hex32 = generate64RandomHexChars();
+final hex32 = generateRandomHex();          // 32 bytes / 64 hex chars
+final hex16 = generateRandomHex(bytes: 16); // any length
```

---

## 18. Errors

v1 mostly threw raw `Exception('some message')` or `FormatException`.
v2 has a typed hierarchy rooted at `NostrException`:

```dart
try {
  Comment.parse(event);          // strict
} on MissingTagException catch (e) {
  print('event missing tag: ${e.tag}');
} on InvalidKindException catch (e) {
  print('wrong kind: ${e.kind}, expected one of ${e.expected}');
} on NostrException catch (e) {
  print('other nostr error: $e');
}
```

If you prefer to tolerate malformed input, every parser with required
tags accepts a `permissive: true` flag — the `data.missingTags` set
will record what was absent and `data.isComplete` will be `false`,
but the call won't throw:

```dart
final data = FileMetadata.parse(event, permissive: true);
if (!data.isComplete) {
  print('partial event, missing: ${data.missingTags}');
}
```

This matters in practice — roughly **31 % of NIP-94** events and
**27 % of NIP-29 group metadata** observed on production relays
violate the spec. Permissive mode lets you display them anyway.

---

## 19. Things that aren't here anymore

If your v1 code uses one of these and you can't find it:

| Removed | Replacement |
|---------|-------------|
| `Keychain` | `Keys` |
| `Keychain.verify(...)` | `Schnorr.verify(...)` |
| `Nip4` / `EncryptedDirectMessage` (NIP-04) | `DirectMessage` (NIP-17 over NIP-59) |
| `kepler.dart` / `crypto/operator.dart` | gone with NIP-04 |
| `bip340` re-exported from `package:nostr` | use `Schnorr.sign` / `verify` / `derivePublicKey` |
| `nip_044_utils.dart` re-exported | use `Encryption.encrypt` / `Encryption.decrypt` |
| `Nip19.encodePubkey` / `encodePrivkey` / `encodeNote` | `Bech32Entity.encode(prefix:, data:)` |
| `Nip19.decodePubkey` / `decodePrivkey` / `decodeNote` | `Bech32Entity.decode(payload:)` or `decodeAny(...)` |
| `Contact.aliasPubKey` | field removed |
| `Filter` mutable fields | build new const `Filter()`s |
| `generate64RandomHexChars()` | `generateRandomHex()` |
| `MessageType.fromName(s)` | `MessageType.from(s)` |
| `MessageType.name` | `MessageType.label` |

---

## 20. `NoteData.thread` is now non-nullable

```diff
-final Thread? t = note.thread;          // Thread?
-if (t == null) print('no thread refs');
+final Thread t = note.thread;           // Thread (always non-null)
+if (t.root.eventId.isEmpty && t.etags.isEmpty && t.ptags.isEmpty) {
+  print('no thread refs');
+}
```

`Note.parse` already returned a non-null sentinel `Thread` for plain
notes — the declared `Thread?` type was wrong. Code using `?.` for
chained access will still compile but should drop the `?`.

---

## 21. NIP-29 `GroupMetadataData` gained three flag fields

```diff
-isOpen, isPublic
+isOpen, isClosed, isPublic, isPrivate, isBroadcast
```

`parseMetadata` reports presence of each NIP-29 metadata flag tag
independently. The pairs `open/closed` and `public/private` are
mutually exclusive per spec, but the library doesn't enforce that —
relays may emit either, both, or neither, and consumers decide what
"unspecified" means for their UI.

---

## 22. `Filter.fromJson` / `toJson` are now String-based

```diff
-final filter = Filter.fromJson(jsonMap);          // Map  -> Filter
-final jsonMap = filter.toJson();                  // Filter -> Map
+final filter = Filter.fromJson(jsonString);       // String -> Filter
+final jsonString = filter.toJson();               // Filter -> String
+
+// The Map variants moved to `fromMap` / `toMap`:
+final filter = Filter.fromMap(jsonMap);
+final jsonMap = filter.toMap();
```

This matches the convention used by `Event`, `Close`, `Eose`, `Request`,
`Message`, and `CommandResult`. Internal callers (NIP-01 REQ frame
assembly) now go through `toMap`.

---

## 23. `Event` is now immutable

```diff
-final e = Event.partial();
-e.createdAt = currentUnixTimestampSeconds();
-e.pubkey   = '...';
-e.id       = e.getEventId();
-e.sig      = e.getSignature(secretKey);
+final unsigned = Event.unsigned(
+  pubkey: '...',
+  kind: 1,
+  content: '',
+  createdAt: currentUnixTimestampSeconds(),
+);
+final signed = unsigned.copyWith(
+  sig: unsigned.getSignature(secretKey),
+);
```

Every `Event` field is `final`. The previous v1.5-era idiom of
mutating fields on a `partial` event no longer compiles. Two helpers
replace it:

- **`Event.unsigned({pubkey, kind, content, createdAt, tags})`** —
  builds an event with the canonical `id` precomputed and `sig` empty.
  Use this for NIP-17 rumors (which MUST never be signed) and NIP-13
  mining probes (where signing per attempt is wasted work).
- **`event.copyWith({...})`** — returns a new event with the named
  fields replaced. Useful when promoting an unsigned event to signed
  (pass `sig:`), or when attaching a `subscriptionId` after the fact.

`Event.partial(...)` still exists as a thin "skip validation"
constructor — handy in tests — but it can no longer be mutated.

---

## 24. NIP-57 `amount` is now `BigInt`

```diff
-final zap = Zap.request(
-  ..., amount: 21000,                     // int
-);
-final amount = parsed.amount;             // int?
+final zap = Zap.request(
+  ..., amount: BigInt.from(21000),
+);
+final amount = parsed.amount;             // BigInt?
```

Bitcoin's total supply exceeds 2^53 millisats. When the library is
compiled to JavaScript (Flutter Web), values above `2^53` lose
precision through `int`. Switching to `BigInt` keeps every realistic
zap amount exact. Constants like `21000` become `BigInt.from(21000)`.

---

## 25. Smoke-test your migration

After all errors compile away, run the upstream-vector tests and live
relay validation that ship with the library to confirm your imports
are well-behaved:

```bash
dart pub get
dart analyze
dart test
```

You should see all tests passing and a clean analyzer. If you
forked the library, the `tool/` directory has scripts that capture
real-world events from popular relays and run them through every
parser — a strong end-to-end check before shipping.

---

## Questions / problems?

[Open an issue](https://github.com/ethicnology/dart-nostr/issues) with
the v1 snippet that broke and the error you're seeing — that's the
fastest path to either a fix or a missing migration row in this doc.
