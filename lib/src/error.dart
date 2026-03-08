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

/// Thrown when an event fails validation (bad id, signature, or timestamp).
class EventValidationException extends NostrException {
  const EventValidationException(super.message);
}

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
  final String tag;

  MissingTagException(this.tag) : super('Missing required tag: $tag');
}

/// Thrown when a key (secret or public) is invalid or malformed.
class InvalidKeyException extends NostrException {
  const InvalidKeyException(super.message);
}

/// Thrown when an encryption or decryption operation fails.
class CryptoException extends NostrException {
  const CryptoException(super.message);
}
