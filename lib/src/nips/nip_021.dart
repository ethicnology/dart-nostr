import 'package:nostr/src/error.dart';

/// nostr: URI scheme — [NIP-21](https://github.com/nostr-protocol/nips/blob/master/21.md)
///
/// A utility class to handle Nostr URIs according to NIP-21 specification.
/// Provides encode, decode functionalities for Nostr URIs.
class NostrUri {
  static const String _prefix = 'nostr:';

  /// Identifiers allowed after `nostr:`. Spec: "the identifier MUST be
  /// the same as a NIP-19 identifier (except `nsec`, which MUST NOT be
  /// used)."
  static const _allowedPrefixes = ['npub', 'note', 'nprofile', 'nevent', 'naddr'];

  /// Parses a `nostr:` URI and extracts the identifier.
  ///
  /// Throws [NostrException] if the prefix `nostr:` is missing, if the
  /// identifier begins with `nsec` (forbidden by spec), or if the
  /// bech32 prefix is not one of `npub`, `note`, `nprofile`, `nevent`,
  /// `naddr`.
  static String decode(String uri) {
    if (!uri.startsWith(_prefix)) {
      throw InvalidNostrUriException(NostrUriRejection.missingScheme, uri);
    }

    final identifier = uri.substring(_prefix.length);
    _assertAllowedPrefix(identifier);
    return identifier;
  }

  /// Generates a `nostr:` URI from a given NIP-19 identifier.
  ///
  /// Throws [NostrException] if the identifier starts with `nsec` (secret
  /// keys must never be shared as URIs per spec) or with any prefix not in
  /// the spec's allowed set.
  static String encode(String content) {
    _assertAllowedPrefix(content);
    return _prefix + content;
  }

  static void _assertAllowedPrefix(String identifier) {
    if (identifier.startsWith('nsec')) {
      throw InvalidNostrUriException(
        NostrUriRejection.forbiddenPrefix,
        identifier,
      );
    }
    for (final p in _allowedPrefixes) {
      if (identifier.startsWith(p)) return;
    }
    throw InvalidNostrUriException(
      NostrUriRejection.unknownPrefix,
      identifier,
    );
  }
}

typedef Nip21 = NostrUri;
