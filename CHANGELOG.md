## 2.0.0

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
| `Nip42` | `Auth` | `typedef Nip42 = Auth` |
| `Nip44` | `Encryption` | `typedef Nip44 = Encryption` |
| `Nip46` | `NostrConnect` | `typedef Nip46 = NostrConnect` |
| `Nip47` | `WalletConnect` | `typedef Nip47 = WalletConnect` |
| `Nip51` | `NostrList` | `typedef Nip51 = NostrList` |
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
| `Nip9.encode()` | `Deletion.requestDeletion()` |
| `Nip9.decode()` | `Deletion.parse()` |
| `Nip25.encode()` | `Reaction.create()` |
| `Nip25.decode()` | `Reaction.parse()` |
| `Nip28.createChannel()` | `PublicChat.channel()` |
| `Nip28.getChannelCreation()` | `PublicChat.parseChannel()` |
| `Nip47.encodeRequest()` | `WalletConnect.request()` |
| `Nip47.decodeInfo()` | `WalletConnect.parseInfo()` |
| `Nip51.createMutePeople()` | `NostrList.mutePeople()` |
| `Nip51.getLists()` | `NostrList.parse()` |
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
| `UserStatus` (model) | `UserStatusData` |
| `LiveActivity` (model) | `LiveActivityData` |
| `ZapRequest` / `ZapReceipt` | `ZapRequestData` / `ZapReceiptData` |
| `ShareableIdentifiers` | `ShareableIdentifierData` |
| `UserList` | `UserListData` |

**Other breaking changes:**

| Before | After |
|--------|-------|
| `Keys.from(secretKey: ...)` | Removed — use `Keys(secretKey)` |
| `Nip9.toDeleteEvent(event)` | Removed — use `Deletion.parse(event)` |
| `Filter` fields mutable | `Filter` fields `final`, constructor `const` |
| All model positional ctors | All model named `const` constructors |

### New Features

- `Keys.nsec` / `Keys.npub` getters
- `Keys()` now validates exact 64-char hex length
- `MessageType.closed` (CLOSED relay message per NIP-01)
- `Nip2.encode()` creates kind-3 follow list events
- `Nip23.encode()` creates kind-30023 article events
- `Nip5.verify()` DNS identity verification with no-redirect per spec
- `Nip5.verificationUrl()` helper
- `Nip9` now supports `a` tags (addressable events) and `k` tags (kind indication)
- `Nip21.encode()` rejects `nsec` identifiers per spec
- NIP-51 `getLists()` handles both plaintext JSON and NIP-44 encrypted content
- Semantic typedef aliases for every NIP (`TextNote`, `FollowList`, `DirectMessage`, etc.)
- 13 new NIP implementations: 18, 22, 25, 29, 32, 38, 42, 46, 47, 53, 57, 65, 72, 89
- rust-nostr cross-implementation test vectors (NIP-19, 13, 21, 44, 59, 05, 09)
- Real-world relay event fixture tests for 20+ event kinds

### Bug Fixes

- fix(nip59): `_randomPastTimestamp` now covers the full 2-day window (was ~172 seconds)
- fix(nip10): bounds check on tags without markers (prevents `RangeError`)
- fix(nip44): stale error message expectations in test vectors
- fix(nip28): safe null handling instead of force-unwraps on malformed events
- fix(nip05): `isValidName` now allows hyphens and dots per spec
- fix(nip23): replaced private `_getTagValue` helpers with shared `findTagValue`
- fix: copy-paste doc errors in `Eose` and `Nip20`

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
