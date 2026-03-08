/// A utility class to handle Nostr URIs according to NIP-21 specification.
/// Provides encode, decode functionalities for Nostr URIs.
class Nip21 {
  static const String _prefix = 'nostr:';

  /// Parses a `nostr:` URI and extracts the identifier.
  ///
  /// Throws an [Exception] if the prefix `nostr:` is missing
  static String decode(String uri) {
    if (!uri.startsWith(_prefix)) {
      throw Exception('Invalid Nostr URI: must start with "nostr:"');
    }

    return uri.substring(_prefix.length);
  }

  /// Generates a `nostr:` URI from a given NIP-19 identifier.
  ///
  /// Throws if the identifier starts with "nsec" — secret keys must never
  /// be shared as URIs per the NIP-21 spec.
  static String encode(String content) {
    if (content.startsWith('nsec')) {
      throw Exception('nsec must not be used in nostr: URIs');
    }
    return _prefix + content;
  }
}
