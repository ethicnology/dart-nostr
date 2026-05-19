## 2.0.0

First major rewrite since v1.5.0. The library is now pure-protocol (no transport / WebSocket dependency), Flutter Web compatible, and spec-aligned against the upstream `nostr-protocol/nips` master. NIP-04 plaintext DMs are gone, every NIP has typed parse output, and all crypto runs through `Schnorr` / `Encryption` (no direct `bip340`).

### Breaking Changes

**NIP-04 removed** — Use `Nip17` / `DirectMessage` (NIP-17 over NIP-59 gift wrap) instead.

**Parameter `privkey` renamed to `secretKey`** across the entire API (`Event.from`, all NIP encode methods, `Nip59.wrap`/`unwrap`, etc.)

**Core API:**

| Before | After |
|--------|-------|
| `Keychain(privkey)` | `Keys(privkey)` |
| `keychain.private` | `keys.secret` |
| `Event.fromJson(Map)` | `Event.fromMap(Map)` |
| `Event.toJson()` → `Map` | `Event.toMap()` |
| `Event.deserialize(dynamic)` | `Event.deserialize(String)` |
| `Request('id', [filter])` | `Request(subscriptionId: 'id', filters: [filter])` |
| `Filter(e: [...])` | `Filter(eTags: [...])` |
| `Filter(p: [...])` | `Filter(pTags: [...])` |
| `Filter(a: [...])` | `Filter(aTags: [...])` |
| `MessageType.name` | `MessageType.label` |
| `generate64RandomHexChars()` | `generateRandomHex()` |

**NIP classes renamed — domain name is now the primary class, `Nip*` is the alias:**

| Before | After | Alias |
|--------|-------|-------|
| `Nip1` | `Note` | `typedef Nip1 = Note` |
| `Nip2` | `FollowList` | `typedef Nip2 = FollowList` |
| `Nip5` | `DnsIdentifier` | `typedef Nip5 = DnsIdentifier` |
| `Nip9` | `Deletion` | `typedef Nip9 = Deletion` |
| `Nip10` | `Threading` | `typedef Nip10 = Threading` |
| `Nip13` | `ProofOfWork` | `typedef Nip13 = ProofOfWork` |
| `Nip17` | `DirectMessage` | `typedef Nip17 = DirectMessage` |
| `Nip18` | `Repost` | `typedef Nip18 = Repost` |
| `Nip19` | `Bech32Entity` | `typedef Nip19 = Bech32Entity` |
| `Nip20` | `CommandResult` | `typedef Nip20 = CommandResult` |
| `Nip21` | `NostrUri` | `typedef Nip21 = NostrUri` |
| `Nip22` | `Comment` | `typedef Nip22 = Comment` |
| `Nip23` | `Article` | `typedef Nip23 = Article` |
| `Nip25` | `Reaction` | `typedef Nip25 = Reaction` |
| `Nip28` | `PublicChat` | `typedef Nip28 = PublicChat` |
| `Nip29` | `Group` | `typedef Nip29 = Group` |
| `Nip32` | `Label` | `typedef Nip32 = Label` |
| `Nip38` | `UserStatus` | `typedef Nip38 = UserStatus` |
| `Nip42` | `RelayAuth` | `typedef Nip42 = RelayAuth` |
| `Nip44` | `Encryption` | `typedef Nip44 = Encryption` |
| `Nip46` | `NostrConnect` | `typedef Nip46 = NostrConnect` |
| `Nip47` | `WalletConnect` | `typedef Nip47 = WalletConnect` |
| `Nip51` | `UserList` | `typedef Nip51 = UserList` |
| `Nip53` | `LiveActivity` | `typedef Nip53 = LiveActivity` |
| `Nip57` | `Zap` | `typedef Nip57 = Zap` |
| `Nip59` | `GiftWrap` | `typedef Nip59 = GiftWrap` |
| `Nip65` | `RelayList` | `typedef Nip65 = RelayList` |
| `Nip72` | `ModeratedCommunity` | `typedef Nip72 = ModeratedCommunity` |
| `Nip89` | `AppHandler` | `typedef Nip89 = AppHandler` |

**Methods renamed — `encode()`→`create()`, `decode()`→`parse()`, spec-aligned verbs:**

| Before | After |
|--------|-------|
| `Nip1.encodeTextNote()` | `Note.create()` |
| `Nip1.encodeSetMetadata()` | `Note.setMetadata()` |
| `Nip1.decodeTextNote()` | `Note.parse()` |
| `Nip2.encode()` | `FollowList.create()` |
| `Nip2.decode()` | `FollowList.parse()` |
| `Nip5.encode()` | `DnsIdentifier.create()` |
| `Nip5.decode()` | `DnsIdentifier.parse()` |
| `Nip9.encode()` | `Deletion.create()` |
| `Nip9.decode()` | `Deletion.parse()` |
| `Nip10.fromTags(tags)` | `Threading.parseTags(tags)` |
| `Nip25.encode()` | `Reaction.create()` |
| `Nip25.decode()` | `Reaction.parse()` |
| `Nip28.createChannel()` | `PublicChat.channel()` |
| `Nip28.setChannelMetaData()` | `PublicChat.channelMetadata()` |
| `Nip28.sendChannelMessage()` | `PublicChat.channelMessage()` |
| `Nip28.hideChannelMessage()` | `PublicChat.hideMessage()` |
| `Nip28.muteUser()` | `PublicChat.muteUser()` |
| `Nip28.getChannelCreation()` | `PublicChat.parseChannel()` |
| `Nip28.getChannelMetadata()` | `PublicChat.parseMetadata()` |
| `Nip28.getChannelMessage()` | `PublicChat.parseMessage()` |
| `Nip28.getMessageHidden()` | `PublicChat.parseHidden()` |
| `Nip28.getUserMuted()` | `PublicChat.parseMuted()` |
| `Nip47.encodeRequest()` | `WalletConnect.request()` |
| `Nip47.decodeInfo()` | `WalletConnect.parseInfo()` |
| `Nip51.createMutePeople()` | `UserList.mutePeople()` |
| `Nip51.createPinEvent()` | `UserList.pinEvent()` |
| `Nip51.createCategorizedPeople()` | `UserList.categorizedPeople()` |
| `Nip51.createCategorizedBookmarks()` | `UserList.categorizedBookmarks()` |
| `Nip51.peoplesToTags()` | `UserList.contactsToTags()` |
| `Nip51.peoplesToContent()` | `UserList.contactsToContent()` |
| `Nip51.getLists(event, secretKey)` | `UserList.parse(event, secretKey: ...)` |
| `Nip57.encodeZapRequest()` | `Zap.request()` |
| `Nip57.decodeZapReceipt()` | `Zap.parseReceipt()` |

**All model classes renamed with `Data` suffix:**

| Before | After |
|--------|-------|
| `Note` | `NoteData` |
| `Profile` | `ProfileData` |
| `DNS` | `DnsData` |
| `DeletionRequest` | `DeletionRequestData` |
| `Reaction` (model) | `ReactionData` |
| `Repost` (model) | `RepostData` |
| `Comment` (model) | `CommentData` |
| `Nip23Article` | `ArticleData` |
| `Channel` | `ChannelData` |
| `ChannelMessage` | `ChannelMessageData` |
| `ChannelMessageHidden` | `ChannelMessageHiddenData` |
| `ChannelUserMuted` | `ChannelUserMutedData` |
| `UserStatus` (model) | `UserStatusData` |
| `LiveActivity` (model) | `LiveActivityData` |
| `ZapRequest` / `ZapReceipt` | `ZapRequestData` / `ZapReceiptData` |
| `ShareableIdentifiers` | `ShareableIdentifierData` |
| `UserList` | `UserListData` |

**Event-kind constants standardised to `kindXxx` prefix on every NIP
class** (e.g. `Zap.kindZapRequest`, `WalletConnect.kindWalletInfo`,
`ModeratedCommunity.kindCommunity`, `AppHandler.kindHandlerInfo`,
`NostrConnect.kindNostrConnect`, `Deletion.kindDeletion`).

**Signature changes (same name, different shape):**

| Before | After |
|--------|-------|
| `Close.deserialize(dynamic)` | `Close.deserialize(String payload)` |
| `Eose.deserialize(dynamic)` | `Eose.deserialize(String payload)` |
| `Request.deserialize(dynamic)` | `Request.deserialize(String payload)` |
| `Message.deserialize(dynamic)` | `Message.deserialize(String payload)` |
| `Nip20.deserialize(dynamic)` | `CommandResult.deserialize(String payload)` |
| `MessageType.fromName(String)` | `MessageType.from(String)` |
| `Keychain.sign(String message)` | `Keys.sign({required String message})` |
| `UserList.parse(event, privkey)` *(sync)* | `UserList.parse(event, {required secretKey})` *(async, named arg)* |
| `UserList.fromContent(...)` *(sync)* | `UserList.fromContent(...)` *(async)* |
| `Event.from(secretKey, kind, tags, content, createdAt)` | `Event.from({required kind, required tags, required content, required secretKey, createdAt?, …})` |

**Removed without direct replacement:**

| Removed | Migration |
|---------|-----------|
| `Keychain` class | Use `Keys` |
| `Keychain.verify(pubkey, message, sig)` | Use `Schnorr.verify(...)` |
| `Nip4` / `EncryptedDirectMessage` (NIP-04) | Use `DirectMessage` (NIP-17 over NIP-59) |
| `Nip19.encodePubkey/encodePrivkey/encodeNote` | Use `Bech32Entity.encode(prefix: ..., data: ...)` |
| `Nip19.decodePubkey/decodePrivkey/decodeNote` | Use `Bech32Entity.decode(payload: ...)` or `Bech32Entity.decodeAny(...)` |
| `kepler.dart`, `crypto/operator.dart`, `crypto/nip_004.dart` | Internal NIP-04 helpers, gone with NIP-04 |
| `Contact.aliasPubKey` field | Field removed; `Contact(pubkey, mainRelay, petName)` is 3-arg |

**Other breaking changes:**

| Before | After |
|--------|-------|
| `Filter` fields mutable | `Filter` fields `final`, constructor `const` |
| All model positional ctors | All model named `const` constructors |
| `bip340` re-exported via `package:nostr` | Internal; use `Schnorr.sign / verify / derivePublicKey` |
| `nip_044_utils.dart` re-exported | Internal; use `Encryption.encrypt / decrypt` |

### New Features

- `Keys.nsec` / `Keys.npub` getters
- `Keys()` now validates exact 64-char hex length
- `MessageType.closed` (CLOSED relay message per NIP-01)
- `FollowList.create()` (kind-3 follow list events)
- `Article.create()` (kind-30023 / 30024 long-form events)
- `DnsIdentifier.verify()` DNS identity verification with no-redirect per spec
- `DnsIdentifier.verificationUrl()` helper
- `Deletion` now supports `a` tags (addressable events) and `k` tags (kind indication)
- `NostrUri.encode()` rejects `nsec` identifiers per spec
- `UserList.parse()` handles both plaintext JSON and NIP-44 encrypted content
- Semantic typedef aliases for every NIP (`TextNote`, `Profile`, `DirectMessage`, etc.)
- New NIP implementations since v1.5.0: 11, 17, 18, 22, 23, 25, 27, 29, 32, 38, 40, 42, 44, 46, 47, 51 (expanded), 53, 57, 58, 59, 65, 72, 89, 94, 98
- Top-level `Tag = List<String>` and `Tags = List<Tag>` typedefs
- **`Filter.tagFilters: Map<String, List<String>>?`** — generic
  single-letter tag filter map (`#d` / `#t` / `#k` / `#r`, etc.).
  `Filter.fromJson` collects every `#X` key into this map;
  `eTags` / `aTags` / `pTags` still take precedence when set.
- **NIP-13 mining** — `nonceTag(value, target)`, `targetFromTag`,
  `meetsTarget(event)`, and `mine(difficulty, kind, content, secretKey,
  ...)` for actually producing PoW events. Previously only
  `countLeadingZeroes` was exposed.
- **NIP-11** — relay information document: `RelayInfo.fetch(relayUrl)`
  returns `RelayInfoData` with `supportedNips`, `limitation`,
  `software`, `version`, and operator contact fields. URL scheme
  rewritten from `wss://` / `ws://` to `https://` / `http://`
  automatically. Tolerant of wrong-typed fields commonly seen in
  the wild.
- **NIP-94** — file metadata events (kind 1063).
- **NIP-98** — HTTP auth (kind 27235): `create`, `validate`,
  `payloadHash`, `toAuthHeader` / `fromAuthHeader`.
- **NIP-58** Profile Badges migrated to **kind 10008** per spec;
  `parseProfileBadges` accepts the legacy kind 30008 form too.
- **NIP-29** write helpers (`message`, `threadRoot`, `threadReply`,
  `joinRequest`, `leaveRequest`) and parsers for `parseAdmins`
  (kind 39001) / `parseMembers` (kind 39002).
- **`MissingTagException` permissive mode** — every `parse(...)`
  method now accepts `{bool permissive = false}`; in permissive mode
  the missing-tag set is recorded on `<Data>.missingTags` and
  `<Data>.isComplete` instead of throwing, so consumers can still
  display whatever is salvageable on the ~31 % of real-world events
  that violate spec requirements.
- rust-nostr cross-implementation test vectors (NIP-19, 13, 21, 44, 59, 05, 09)
- Real-world relay event fixture tests for 20+ event kinds

### Bug Fixes & Spec Compliance

**HIGH (security / correctness)**

- **NIP-44** (`unpad`): enforce `padded.length == 2 + calcPaddedLen(unpaddedLen)`
  per spec pseudocode — prevents accepting malleable / over-sized padded
  buffers.
- **NIP-19** (`encodeShareableIdentifiers` / `decodeShareableIdentifiers`):
  switch naddr identifier and relay byte encoding from `String.codeUnits`
  (UTF-16) to `utf8.encode` / `utf8.decode`. Matches rust-nostr and
  nostr-tools; unblocks non-ASCII `d`-tags (e.g. `café`, `日本`, emoji).
- **NIP-98** (`fromAuthHeader`, `validate`): `fromAuthHeader` verifies
  id + signature on the decoded event. `validate` calls
  `event.isValid()` first for defense in depth.
- **NIP-42** (`validate`) and **NIP-59** (`unwrap`) call
  `event.isValid()` at the top so forged events are caught before any
  request- or decrypt-specific check.

**Spec gaps closed**

- **NIP-22** (`parse`): throws `MissingTagException` when required `K`,
  `k`, root-scope (`E`/`A`/`I`), or parent (`e`/`a`/`i`) tags are absent.
- **NIP-25** (`parse`): when multiple `e`/`p` tags exist, the target is
  the LAST one per spec. Surfaces the `e` relay hint and optional `a`.
- **NIP-29** (`parseMetadata`): throws on missing `d` tag (group
  identifier — required by NIP-01 for addressable events).
- **NIP-65** (`parse`): unknown markers fall back to read+write instead
  of silently dropping the relay.
- **NIP-72** (`approval`): `approvedEventJson` required when referenced
  via `e` (spec MUST). Added `approvedEventCoord` for addressable
  posts; rejects when neither (or both) of `e`/`a` is provided.
- **NIP-89** (`parseHandlerInfo`): platform-handler detection uses a
  positive allowlist (`web`, `ios`, `android`, `iphone`, `ipad`,
  `macos`, `linux`, `windows`) instead of a brittle exclude-list.
- **NIP-19**: `encodeShareableIdentifiers` requires `author` and `kind`
  for `naddr`. 5000-char soft cap on encode and decode. Added
  `decodeAny()` dispatcher.

**Real bugs**

- **NIP-28** (`parseChannel` / `parseMetadata`): channel content with
  the spec-defined `relays` array no longer crashes
  `Map<String, String>.from`. `ChannelData` exposes
  `relays: List<String>` separately from string `additional`.
- **NIP-21** (`decode`): rejects `nostr:nsec1…` and any prefix outside
  `{npub, note, nprofile, nevent, naddr}`.
- Tag-bounds bugs (RangeError on empty tags) fixed in `nip_002.dart`,
  `nip_028.dart`, `nip_065.dart`.
- fix(nip59): `_randomPastTimestamp` now covers the full 2-day window (was ~172 seconds)
- fix(nip10): bounds check on tags without markers (prevents `RangeError`)
- fix(nip44): stale error message expectations in test vectors
- fix(nip28): safe null handling instead of force-unwraps on malformed events
- fix(nip05): `isValidName` now allows hyphens and dots per spec
- fix(nip23): replaced private `_getTagValue` helpers with shared `findTagValue`
- fix: copy-paste doc errors in `Eose` and `Nip20`

### Architecture

- **`bip340` direct imports removed** from `event.dart` and `keys.dart`;
  both route through `Schnorr`. Added `Schnorr.derivePublicKey` with
  32-byte input validation. `Event.isValid` catches
  `InvalidKeyException` and returns false instead of propagating.
- **`nip_044_utils.dart` no longer re-exported** from `nostr.dart`. The
  raw crypto primitives (`pad`, `unpad`, `chacha20`, `hkdf`,
  `calculateMac`, `parsePayload`, etc.) are easy to misuse and now stay
  internal. Use `Encryption.encrypt` / `Encryption.decrypt`. Tests that
  need the primitives import the file path directly.

## 1.5.0

- feat: add EOSE class to obtain subscriptionId (#41)

## 1.4.3

- refactor: Message.type is made of an MessageType enum instead of a String

## 1.4.2

- NIP50: search filter

## 1.4.1

- [new **a** filter](https://github.com/nostr-protocol/nips/commit/e50bf508d9014cfb19bfa8a5c4ec88dc4788d490)
- Upgrade bip340 dependency

## 1.4.0

- NIP 04 Encrypted Direct Message
- NIP 05 Mapping Nostr keys to DNS-based internet identifiers
- NIP 10 Conventions for clients' use of e and p tags in text events
- NIP 15 End of Stored Events Notice
- NIP 19 bech32-encoded entities
- NIP 20 Command Results
- NIP 28 Public Chat
- NIP 51 Lists

## 1.3.4

- fix: pending bip340 issue
- test: Update test to check public key
- refactor: Event partial and from to factories

## 1.3.3

- add comments about verify and fix typo
- nip 002 implementation, unit tests, examples and documentation
- Event.partial to init an empty event that you validate later, documentation

## 1.3.2

- refactor: Event with optional verification
- remove tests with encoding problem
- improve coverage

## 1.3.1

- fix: Inconsitency in events is breaking tags

## 1.3.0

- add Close (+ unit tests)
- add Message wrapper deserializer (+ unit tests)
- Documentation

## 1.2.0

- add Filters (+ unit tests)
- add Request (+ unit tests)
- Documentation

## 1.1.0

- fix Event.fromJson
- add subscriptionId
- deserialization of NOSTR formatted events with or without subscription_id
- add unit tests for Event to improve coverage
- Create Keychain container for private/public keys to encapsulate bip340 and add handy methods.
- Documentation

## 1.0.1

- Fix createdAt initialization
- Add asserts
- Code comments

## 1.0.0

- Initial version.
