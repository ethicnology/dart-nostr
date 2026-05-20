/// Base error for all nostr package errors.
///
/// All errors thrown by this package extend [NostrException],
/// allowing callers to catch all nostr errors with a single type.
class NostrException implements Exception {
  final String message;
  const NostrException(this.message);

  @override
  String toString() => 'NostrException: $message';
}

// ---------------------------------------------------------------------------
// Event-level errors
// ---------------------------------------------------------------------------

/// Reason an event failed validation. Used by [EventValidationException]
/// so consumers can dispatch on the specific check that failed instead
/// of regex-matching the message string.
enum EventValidationReason {
  /// The canonical-serialization SHA-256 doesn't match the claimed `id`.
  idMismatch,

  /// The Schnorr signature is not valid for the `pubkey` over the `id`.
  invalidSignature,

  /// `created_at` is not a sane Unix timestamp (≤ 0 or ≥ year 9999).
  invalidTimestamp,

  /// `pubkey` or `sig` is not a hex string of the expected length.
  malformedSignature,
}

/// Thrown when an event fails validation (bad id, signature, or timestamp).
///
/// Inspect [reason] to learn which check failed.
class EventValidationException extends NostrException {
  final EventValidationReason reason;
  const EventValidationException(super.message, this.reason);
}

// ---------------------------------------------------------------------------
// Deserialization / parsing
// ---------------------------------------------------------------------------

/// Thrown when a message payload cannot be parsed or deserialized.
class DeserializationException extends NostrException {
  const DeserializationException(super.message);
}

/// Thrown when an event kind does not match the expected NIP.
class InvalidKindException extends NostrException {
  final int kind;
  final List<int> expected;

  InvalidKindException(this.kind, this.expected)
      : super('Expected kind ${expected.join(" or ")}, got $kind');
}

/// Thrown when a required tag is missing from an event.
class MissingTagException extends NostrException {
  /// The name of the missing tag (e.g. `"x"`, `"d"`). For tags where any
  /// of several letters satisfies the requirement, the value is slash-
  /// joined (e.g. `"E/A/I"`).
  final String tag;

  MissingTagException(this.tag) : super('Missing required tag: $tag');
}

/// Thrown when a key (secret or public) is invalid or malformed.
class InvalidKeyException extends NostrException {
  const InvalidKeyException(super.message);
}

// ---------------------------------------------------------------------------
// Crypto errors
// ---------------------------------------------------------------------------

/// Discriminator for [CryptoException]. Lets consumers act on the
/// specific failure mode (e.g. distinguish "ciphertext was tampered"
/// from "library is too old to read this version").
enum CryptoErrorCode {
  /// HMAC tag did not match. Ciphertext was tampered or wrong key.
  invalidMac,

  /// Padding violates NIP-44 v2 layout (length byte, calc-padded check).
  invalidPadding,

  /// Header byte indicates a version no implementation should produce
  /// (`0x00 = reserved`, `0x01 = deprecated`).
  unknownEncryptionVersion,

  /// Header byte is a defined version we don't support (e.g. future v3).
  unsupportedEncryptionVersion,

  /// Total payload size is outside the spec's bounds.
  invalidPayloadSize,

  /// Conversation key is not 32 bytes.
  invalidConversationKeyLength,

  /// Nonce is not 32 bytes.
  invalidNonceLength,

  /// Plaintext length is outside `[1, 65535]`.
  invalidPlaintextLength,

  /// secp256k1 public key has an unrecognized prefix or wrong length.
  invalidPublicKey,

  /// NIP-59: the gift wrap event failed signature/id validation.
  invalidGiftWrapSignature,

  /// NIP-59: the outer event is not kind 1059.
  notGiftWrapKind,

  /// NIP-59: the decrypted inner event is not kind 13 (seal).
  unwrappedNotSealKind,

  /// NIP-59: the seal's pubkey does not match the rumor's pubkey
  /// (impersonation guard).
  sealAuthorMismatch,

  /// NIP-59: the rumor came back with a non-empty signature. Rumors MUST
  /// be unsigned per spec — a signed rumor risks leaking the author.
  rumorMustBeUnsigned,

  /// NIP-59: the seal (kind 13) carries tags. Per spec, seal events MUST
  /// have an empty tags array.
  sealMustHaveEmptyTags,
}

/// Thrown when an encryption or decryption operation fails.
///
/// Inspect [code] for the specific failure mode (preferred over
/// matching the [message] string).
class CryptoException extends NostrException {
  final CryptoErrorCode code;
  const CryptoException(super.message, this.code);
}

// ---------------------------------------------------------------------------
// Field-level structural errors
// ---------------------------------------------------------------------------

/// Thrown when a parsed field doesn't match the value the caller
/// expected — e.g. NIP-98 `u` tag vs the actual request URL.
class FieldMismatchException extends NostrException {
  /// Name of the field (e.g. `'url'`, `'method'`, `'payload'`).
  final String field;
  final String expected;
  final String actual;

  FieldMismatchException(this.field, this.expected, this.actual)
      : super('$field mismatch: expected "$expected", got "$actual"');
}

/// Thrown when an event's `created_at` is outside an acceptable window.
///
/// [deltaSeconds] is signed: positive when the event is in the past
/// (`now - createdAt > 0`), negative when it's in the future.
class TimestampOutOfWindowException extends NostrException {
  final int deltaSeconds;
  final int maxPastSeconds;
  final int maxFutureSeconds;

  TimestampOutOfWindowException({
    required this.deltaSeconds,
    required this.maxPastSeconds,
    required this.maxFutureSeconds,
  }) : super(deltaSeconds > maxPastSeconds
            ? 'Event too old: $deltaSeconds seconds (max $maxPastSeconds)'
            : 'Event too far in the future: ${-deltaSeconds} seconds '
                '(max $maxFutureSeconds)');

  /// True when the event is older than the past window allows.
  bool get tooOld => deltaSeconds > maxPastSeconds;

  /// True when the event is more than the future window in the future.
  bool get tooEarly => deltaSeconds < -maxFutureSeconds;
}

// ---------------------------------------------------------------------------
// NIP-19 / NIP-21 (bech32 + nostr: URI) structural errors
// ---------------------------------------------------------------------------

/// Reason a `nostr:` URI string was rejected.
enum NostrUriRejection {
  /// Doesn't start with `nostr:`.
  missingScheme,

  /// Identifier prefix is forbidden (currently `nsec`).
  forbiddenPrefix,

  /// Identifier prefix is not one of the NIP-19 entities allowed by
  /// NIP-21 (`npub`, `note`, `nprofile`, `nevent`, `naddr`).
  unknownPrefix,
}

/// Thrown when a `nostr:` URI is malformed or contains a forbidden
/// identifier per NIP-21.
class InvalidNostrUriException extends NostrException {
  final NostrUriRejection reason;
  final String input;

  InvalidNostrUriException(this.reason, this.input)
      : super(_describe(reason));

  // The raw input is deliberately NOT embedded in the message — if a
  // caller accidentally passes an nsec (or any other secret) here, the
  // message would otherwise leak it through logs. The raw value is still
  // available on the `.input` field for consumers that need it.
  static String _describe(NostrUriRejection r) {
    switch (r) {
      case NostrUriRejection.missingScheme:
        return 'Invalid Nostr URI: must start with "nostr:"';
      case NostrUriRejection.forbiddenPrefix:
        return 'nsec must not be used in nostr: URIs';
      case NostrUriRejection.unknownPrefix:
        return 'Identifier must be one of npub, note, nprofile, nevent, '
            'naddr';
    }
  }
}

/// Thrown when a bech32 string has a different prefix than the caller
/// requires (e.g. an `npub` passed where `nsec` was expected).
class WrongPrefixException extends NostrException {
  final String got;
  final List<String> expected;

  WrongPrefixException(this.got, this.expected)
      : super('Expected bech32 prefix in $expected, got "$got"');
}

/// Thrown when a NIP-19 shareable identifier (`nprofile`/`nevent`/`naddr`)
/// is missing a TLV the spec or library requires.
///
/// For `naddr`: type 2 = author pubkey, type 3 = event kind.
class MissingTlvException extends NostrException {
  final int tlvType;
  final String description;

  MissingTlvException(this.tlvType, this.description)
      : super('Missing required TLV type $tlvType ($description)');
}

/// Thrown when a NIP-19 decode method is called with a payload that
/// belongs to a different decoder. (E.g. passing `nprofile` to
/// `decode()` instead of `decodeShareableIdentifiers()`.)
class WrongDecodeMethodException extends NostrException {
  /// Name of the method the caller should have used.
  final String useInstead;

  WrongDecodeMethodException(this.useInstead)
      : super('Use $useInstead instead');
}

// ---------------------------------------------------------------------------
// Argument / spec-shape errors
// ---------------------------------------------------------------------------

/// Thrown when a builder is called with arguments that don't satisfy
/// the spec's structural rules (e.g. NIP-58 `award` with zero awardees).
///
/// Use [parameter] to identify the offending parameter and [constraint]
/// to read the rule that was violated. Both are also folded into the
/// [message] for log readability.
class InvalidArgumentException extends NostrException {
  final String parameter;
  final String constraint;

  InvalidArgumentException(this.parameter, this.constraint)
      : super('$parameter $constraint');
}

/// Reason a NIP-72 approval was rejected at build time.
enum ApprovalScopeReason {
  /// Neither `approvedEventId` nor `approvedEventCoord` was supplied.
  noTarget,

  /// Both `approvedEventId` and `approvedEventCoord` were supplied.
  bothTargets,

  /// `approvedEventId` was supplied (so the approval references the
  /// post via an `e` tag) but `approvedEventJson` was omitted. Spec
  /// MUSTs the JSON in this case.
  missingEventJson,
}

/// Thrown by NIP-72 `approval` when its scoping rules are violated.
class ApprovalScopeException extends NostrException {
  final ApprovalScopeReason reason;

  ApprovalScopeException(this.reason) : super(_describe(reason));

  static String _describe(ApprovalScopeReason r) {
    switch (r) {
      case ApprovalScopeReason.noTarget:
        return 'approval requires exactly one of approvedEventId or '
            'approvedEventCoord';
      case ApprovalScopeReason.bothTargets:
        return 'approval cannot include both approvedEventId and '
            'approvedEventCoord — pick one';
      case ApprovalScopeReason.missingEventJson:
        return 'approval with e tag MUST include the approved event JSON '
            '(NIP-72)';
    }
  }
}

/// Thrown when an identifier (NIP-05, etc.) is structurally invalid.
class InvalidIdentifierException extends NostrException {
  final String identifier;
  final String reason;

  InvalidIdentifierException(this.identifier, this.reason)
      : super('Invalid identifier "$identifier": $reason');
}

// ---------------------------------------------------------------------------
// NIP-98 (HTTP auth) — header-level errors
// ---------------------------------------------------------------------------

/// Reason a NIP-98 `Authorization` header could not be decoded.
enum AuthHeaderError {
  /// The base64 payload was malformed.
  badBase64,

  /// The decoded payload was not valid JSON.
  invalidJson,
}

/// Thrown when a NIP-98 `Authorization: Nostr <base64>` header is
/// structurally broken (bad base64 or bad JSON inside).
class MalformedAuthHeaderException extends NostrException {
  final AuthHeaderError code;
  final Object cause;

  MalformedAuthHeaderException(this.code, this.cause)
      : super(code == AuthHeaderError.badBase64
            ? 'Malformed auth header: $cause'
            : 'Invalid JSON in auth header: $cause');
}
