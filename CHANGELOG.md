## 2.0.1

Security and spec-compliance patch release, produced by a full audit of the
library against the upstream `nostr-protocol/nips` specifications and the
`rust-nostr` reference implementation. **All users should upgrade.**

No public API was removed or renamed; every change tightens validation,
fixes a parser, or hardens a cryptographic path. The behavior changes listed
below only reject inputs that were invalid per spec — but if your application
was (unknowingly) producing or accepting them, read the notes carefully.

### Why this release exists

The audit found three classes of problems:

1. **Missing key validation.** Secret keys used for signing (BIP-340) and
   NIP-44 encryption (ECDH) were never checked against the secp256k1 scalar
   range `[1, n - 1]` required by both specs. A zero key crashed with a raw
   `_TypeError`; a key `≥ n` silently produced a non-canonical public key or
   a garbage ECDH shared point. The official NIP-44 test vectors pair
   invalid secret keys with an *also-invalid* public key, which masked the
   gap in the test suite.
2. **Missing authentication checks.** The NIP-57 "private zap" inner event
   was parsed *without verifying its signature*, so anyone could forge a
   private zap attributing a payment intent to any pubkey. The NIP-59
   "rumor must be unsigned" check existed but was unreachable (the wire
   field was never read), so a signed rumor was silently accepted.
3. **Spec drift.** The NIP-59 rumor was serialized without its `id` and
   with a `sig` field (the spec example, NIP-17, rust-nostr and nostr-tools
   all carry the computed `id` and omit `sig`), and several parsers
   accepted malformed inputs that rust-nostr rejects.

### Security fixes

- **NIP-44** (`computeSharedSecret`): the secret key is now validated as a
  secp256k1 scalar in `[1, n - 1]` (spec: *"private key must be a scalar in
  range [1, secp256k1_order - 1]"*). Out-of-range keys throw
  `InvalidKeyException` instead of silently producing an invalid shared
  secret. Errors from the EC backend are normalized to `CryptoException`.
- **NIP-57** (`decryptPrivateRequest`): the inner zap request's signature
  is now verified. Previously a forged inner event could impersonate any
  pubkey as the zapper (the outer event is signed by a throwaway ephemeral
  key and proves nothing about the claimed sender).
- **`Keys` / `Schnorr.derivePublicKey` / `Schnorr.sign`**: secret keys
  outside `[1, n - 1]` are rejected with `InvalidKeyException`
  (`sk = 0` previously crashed with a raw `_TypeError`, `sk ≥ n` was
  silently accepted). `Keys.generate()` re-samples until the scalar is in
  range. New public helper: `Schnorr.assertValidSecretKey`.
- **NIP-59** (`unwrap`): a rumor carrying a `sig` is now actually rejected
  (`CryptoErrorCode.rumorMustBeUnsigned`) — the check previously never
  fired because the field was dropped before being tested.
- **NIP-59** (`unwrap`): the rumor `id` is recomputed from the decrypted
  payload instead of being taken from the wire. A rumor is unsigned, so
  nothing else binds the id to the fields it identifies; a sender could
  otherwise make one payload appear under an id of their choosing, which
  clients use to deduplicate, thread and reference messages. A supplied
  id that does not match now throws `CryptoErrorCode.rumorIdMismatch`.

### Spec compliance

- **NIP-59** (`wrap`): the sealed rumor now carries its canonical `id` and
  is serialized **without** a `sig` field — the exact shape of the NIP-59
  example, NIP-17 (*"Fields id and created_at are required"*), rust-nostr's
  `UnsignedEvent::ensure_id`, and nostr-tools. Gift wraps produced by
  2.0.0 can still be unwrapped: an absent or empty `id` means "not
  supplied" and is recomputed rather than rejected.
- **NIP-44** (`parsePayload`): the decoded payload must be within
  `[99, 65603]` bytes (spec minimum, rust-nostr `MAX_PAYLOAD_SIZE`).
- **NIP-44** (`checkPublicKey`): the uncompressed `04` public key form must
  be exactly 65 bytes; longer inputs previously crashed inside the EC
  backend with a thrown `String`.
- **NIP-44** (`decrypt`): a non-UTF-8 plaintext (after a valid MAC) throws
  `CryptoException` with the new `CryptoErrorCode.invalidUtf8` instead of a
  raw `FormatException`.
- **NIP-19**: `nsec`/`npub`/`note` payloads must be exactly 32 bytes on
  both encode and decode (rust-nostr enforces the same via typed keys).
  `encodeShareableIdentifiers` rejects TLV values above 255 bytes (1-byte
  length prefix) instead of silently corrupting the stream, and
  `decodeShareableIdentifiers` now validates the TLV field widths
  (identifier and author = 32 bytes, kind = 4 bytes) instead of accepting
  truncated values.
- **NIP-19** (`decodeShareableIdentifiers`): TLV validation is now scoped
  to the prefix. The mandatory type-0 identifier is required for every
  shareable identifier, and `naddr` additionally requires the author
  (type 2) and kind (type 3) — an `nprofile` carrying no public key used
  to decode to an empty `data`, and `nostr:` URIs built from one were
  accepted. Conversely, types the spec does not define for a prefix (2
  and 3 on `nprofile`) and unknown types are now ignored rather than
  rejected, per NIP-19 (*"TLVs that are not recognized or supported
  should be ignored"*) and matching rust-nostr, which also tolerates a
  malformed optional author on `nevent`. Truncated TLV headers and
  values running past the end of the payload are reported as
  `DeserializationException` instead of surfacing as a `RangeError`.
- **NIP-21** (`decode` / `encode`): the identifier is validated as a
  well-formed NIP-19 bech32 string — a prefix match alone used to accept
  `nostr:npub1garbage`.
- **NIP-10** (`parseTags`): 2-element `p` tags (`["p", <pubkey>]`, the
  common case — the relay hint is optional) are no longer silently dropped.

### Robustness (error contract)

Every public entrypoint keeps the documented guarantee that all errors
extend `NostrException`:

- **NIP-28** (`parseHidden` / `parseMuted`): a non-object JSON content no
  longer raises `_TypeError`; `reason` defaults to empty.
- **NIP-51** (`UserList.parse` / `fromContent`): malformed list content
  (non-array JSON, non-list tags, non-string values) no longer raises
  `_TypeError`; a non-array decrypted payload throws
  `DeserializationException`.

### Denial-of-service hardening

- **NIP-05** (`fetch`) / **NIP-11** (`fetch`): both endpoints are
  attacker-controlled, so fetches are now bounded — `timeout` is a single
  deadline over the whole exchange (default 8 s) and `maxBytes` caps the
  response body (64 KiB / 256 KiB defaults). Previously a malicious
  domain could stall the caller forever or exhaust memory with an
  unbounded body. Applying the timeout per phase would have let a server
  stall just under the limit on both connection and body, so the two are
  covered by one deadline. New shared helper: `readStreamWithLimit`,
  which refuses an oversized chunk before buffering it.

### Known limitations (documented, deliberate)

- **NIP-44 extended length prefix**: NIP-44 now defines a 6-byte length
  prefix for plaintexts of 65536 bytes and above, with test vectors for
  the 65535/65536/65537 boundary. This library implements the 2-byte
  prefix only (plaintexts of 1..65535 bytes) and rejects larger ones
  cleanly at the padding check, as rust-nostr does (*"This codec
  currently supports the original two-byte length prefix only"*). The
  spec allows an implementation-defined maximum, so this is a supported
  limitation rather than a violation — but a peer that implements the
  extended prefix can send payloads this release cannot decrypt.
  Supporting them is tracked for a future minor release.
- **Constant-time guarantees**: the pure-Dart EC backends (`elliptic` for
  NIP-44 ECDH, `pointycastle` via `bip340` for signatures) are not
  constant-time, unlike libsecp256k1 (rust-nostr). Timing side-channels on
  secret-key operations are a residual risk inherent to pure-Dart crypto;
  applications with a strong threat model should isolate key operations.

### Tests

40+ new regression and adversarial tests: official NIP-44 invalid vectors
exercised with a *valid* pub2 (so the secret-key check cannot be masked),
forged private zap, signed/impersonated/tampered gift wraps, hand-crafted
malformed NIP-19 TLV payloads, plaintext size boundaries (65535/65536),
expired NIP-42/NIP-98 timestamps, and a hostile local HTTP server for the
fetch guards.

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
| `Event` mutable fields (`late`) | `Event` immutable (`final`); use `Event.copyWith(...)` or `Event.unsigned(...)` |
| `Filter.fromJson(Map)` | `Filter.fromMap(Map)` |
| `Filter.toJson()` → `Map` | `Filter.toMap()` |
| `Request('id', [filter])` | `Request(subscriptionId: 'id', filters: [filter])` |
| `Filter(e: [...])` | `Filter(eTags: [...])` |
| `Filter(p: [...])` | `Filter(pTags: [...])` |
| `Filter(a: [...])` | `Filter(aTags: [...])` |
| `Zap.request(amount: int)` | `Zap.request(amount: BigInt)` |
| `ZapRequestData.amount: int?` | `ZapRequestData.amount: BigInt?` |
| `MessageType.name` | `MessageType.label` |
| `generate64RandomHexChars()` | `generateRandomHex()` |

> `Event.fromJson` / `toJson` and `Filter.fromJson` / `toJson` now match
> the rest of the library: `fromJson(String)` returns an Event/Filter,
> `toJson()` returns a JSON string. The Map variants live on the new
> `fromMap` / `toMap` names. See `MIGRATION.md` §2 + §22 for details.
>
> `Event` is now fully immutable — every field is `final`. Use
> `Event.unsigned(...)` to build an event with a precomputed id and
> empty sig (NIP-17 rumors, NIP-13 mining probes), and `event.copyWith(...)`
> to derive a modified copy. The old "mutate `partialEvent.id = ...`"
> idiom no longer compiles. See `MIGRATION.md` §23.
>
> `Zap.request` / `anonymousRequest` / `privateRequest` now take
> `amount: BigInt?` (was `int?`). `ZapRequestData.amount` is also
> `BigInt?`. This keeps precision for amounts > 2^53 millisats when the
> library is compiled to JavaScript (Flutter Web). See `MIGRATION.md` §24.

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
| `Event.from(secretKey, kind, tags, content, createdAt)` | `Event.from({required kind, required content, required secretKey, tags?, createdAt?, …})` |

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
- **`MissingTagException` permissive mode** — every parser whose NIP
  defines spec-required tags (NIPs 22, 23, 29, 38, 53, 57, 58, 72, 89,
  94, 98) now accepts `{bool permissive = false}`; in permissive mode
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
  for `naddr`. 5000-char cap enforced on encode and decode. Added
  `decodeAny()` dispatcher.

**Exception contract — all errors are now `NostrException`**

Every public deserialization / decode entrypoint that previously could
leak a raw `FormatException`, `_TypeError`, or `package:bech32`
exception now wraps it as a `NostrException` subclass, matching the
documented contract in `error.dart`. Callers only need `on NostrException`.

- **`Bech32Entity.decode` / `decodeAny` / `encode`** — wrap
  `package:bech32` errors (`InvalidChecksum`, `MixedCase`,
  `TooShortChecksum`, `TooLong`, `InvalidSeparator`) and non-hex input
  as `DeserializationException`. The underlying message is suppressed
  in the wrapped error to avoid echoing candidate secrets to logs.
- **`Schnorr.derivePublicKey` / `sign` / `verify`** — non-hex inputs
  now throw `InvalidKeyException` instead of leaking `FormatException`
  from `hex.decode`.
- **`Event.fromJson`** — bad JSON or non-object payloads throw
  `DeserializationException`.
- **`Event.deserialize`** — validates the wire frame starts with
  `"EVENT"` and has the right shape; previously accepted any tag
  silently and threw `_TypeError` on shape mismatches.
- **`Close` / `Eose` / `Request` / `Message` / `CommandResult` .deserialize**
  — wrap `json.decode` failures and validate the frame tag + shape
  before any cast.
- **`Filter.fromJson`** — typed validation on every field; passing
  e.g. `kinds: "not a list"` now throws `DeserializationException`
  instead of `_TypeError`.
- **`PublicChat.parseChannel` / `parseMetadata`** — non-JSON or
  non-object content throws `DeserializationException`.
- **`ProofOfWork.countLeadingZeroes`** — non-hex input throws
  `DeserializationException` instead of `FormatException` from
  `int.parse`.
- **`GiftWrap.unwrap`** — wraps `json.decode` failure on the inner
  rumor payload as `DeserializationException`.
- **`ModeratedCommunity.parseApproval` / `AppHandler.parseHandlerInfo`
  / `Zap.parseReceipt`** — a JSON array (or any non-object) in a
  content / description slot no longer raises `_TypeError`; the
  optional embedded field is left null, matching the existing fail-soft
  contract.

**Error messages no longer echo candidate secrets**

- **`Keys(...)`** rejection no longer includes the input string —
  `package:bech32`'s `MixedCase` error message would otherwise leak
  the candidate (e.g. a confused caller passing their nsec) into logs.
- **`InvalidNostrUriException`** message no longer embeds the input
  (the raw value remains on the typed `.input` field for consumers
  that genuinely need it).

**Performance**

- **NIP-13** `mine` no longer Schnorr-signs every nonce iteration.
  Mining is hash-bound; computing the candidate event id from the
  canonical serialization is ~1000× faster than signing. The winning
  nonce is signed once at the end. Previously high-difficulty PoW was
  effectively unreachable.
- **NIP-19** `encodeShareableIdentifiers` no longer O(n²) in relay
  count. Rebuilt the TLV with a `StringBuffer` instead of repeated
  string concat — 100 000 relays went from ~80 s to ~300 ms (after
  which the 5000-char length cap rejects).

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
- fix(nip44): stale error message expectations in test vectors — the
  decrypt-fail vectors 004–008 were exercising a vestigial helper
  that always tripped a fake version check; they now go through
  `Encryption.decrypt` and validate canonical MAC + padding errors
- fix(nip28): safe null handling instead of force-unwraps on malformed events
- fix(nip05): `isValidName` now allows hyphens and dots per spec
- fix(nip05): `parse` wraps malformed-JSON content as
  `DeserializationException` and no longer echoes the content in the
  error message
- fix(nip19): silent uint32 truncation on `kind` parameter of
  `encodeShareableIdentifiers` — `kind = 2^32` would round-trip to
  `0`. Now rejects out-of-range kinds with `InvalidArgumentException`
- fix(nip57): `Zap.request` / `anonymousRequest` / `privateRequest`
  reject negative `amount` values (spec is unsigned millisats)
- fix(nip01): `NoteData.thread` typed as non-nullable `Thread` (was
  `Thread?`) — `Note.parse` was always returning a non-null sentinel,
  contradicting the declared type. See MIGRATION.md.
- fix(nip29): `parseMetadata` now reports `isPrivate`, `isClosed`,
  and `isBroadcast` flag presence in addition to `isOpen` / `isPublic`
- fix(nip23): replaced private `_getTagValue` helpers with shared `findTagValue`
- fix: copy-paste doc errors in `Eose` and `Nip20`

**Constants**

- `Repost.kindRepost` (= 6) and `Repost.kindGenericRepost` (= 16)
  added so callers can avoid magic numbers when parsing NIP-18 events.

**Dependencies**

- `pointycastle` constraint loosened to `>=3.7.3 <5.0.0` — picks up
  v4.0.0 (now resolved) which drops the discontinued `js` transitive
  package.

**Spec tightening**

- **NIP-51** (`UserList.parse`) now rejects events whose `kind` is
  outside the list ranges (`10000-10999` or `30000-39999`) with
  `InvalidKindException`. Previously it accepted any kind silently
  and would happily mangle a NIP-23 article into a list.

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
