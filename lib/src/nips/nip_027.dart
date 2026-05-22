import 'package:nostr/nostr.dart';

/// Text Note References — [NIP-27](https://github.com/nostr-protocol/nips/blob/master/27.md)
///
/// Events with readable text content (e.g. kind 1, 30023) may contain
/// inline references using `nostr:` URIs as defined by NIP-21.
/// Clients SHOULD parse these and render them as clickable links or
/// rich previews.
///
/// Example content:
/// ```text
/// Hello nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6!
/// ```
class TextNoteReference {
  /// Regex matching `nostr:` URIs (npub, note, nprofile, nevent, naddr).
  ///
  /// nsec is intentionally excluded — secret keys must never appear
  /// in published content.
  static final _pattern =
      RegExp('nostr:(npub|note|nprofile|nevent|naddr)1[a-z0-9]+');

  /// Extracts all `nostr:` mentions from [content].
  ///
  /// Returns a list of [Mention] objects with position info and decoded
  /// entity data. Malformed URIs are silently skipped.
  static List<Mention> extractMentions(String content) {
    final mentions = <Mention>[];

    for (final match in _pattern.allMatches(content)) {
      final uri = match.group(0)!;
      final bech32 = uri.substring(6); // strip "nostr:"

      try {
        final prefix = Nip19Prefix.from(
          bech32.substring(0, bech32.indexOf('1')),
        );

        String? hex;
        ShareableIdentifierData? shareable;

        if (prefix == Nip19Prefix.nprofile ||
            prefix == Nip19Prefix.nevent ||
            prefix == Nip19Prefix.naddr) {
          shareable = Bech32Entity.decodeShareableIdentifiers(
            payload: bech32,
          );
        } else {
          final decoded = Bech32Entity.decode(payload: bech32);
          hex = decoded.data;
        }

        mentions.add(Mention(
          start: match.start,
          end: match.end,
          uri: uri,
          prefix: prefix,
          hex: hex,
          shareable: shareable,
        ));
      } on Exception catch (_) {
        // Skip malformed URIs
      }
    }

    return mentions;
  }
}

/// A single `nostr:` mention found in event content.
class Mention {
  /// Start index in the content string.
  final int start;

  /// End index in the content string (exclusive).
  final int end;

  /// The full `nostr:` URI as it appears in content.
  final String uri;

  /// The NIP-19 prefix type.
  final Nip19Prefix prefix;

  /// The decoded hex data (for npub, note).
  /// `null` when the mention is a shareable identifier.
  final String? hex;

  /// The decoded shareable identifier data (for nprofile, nevent, naddr).
  /// `null` when the mention is a simple entity.
  final ShareableIdentifierData? shareable;

  /// Creates a [Mention].
  const Mention({
    required this.start,
    required this.end,
    required this.uri,
    required this.prefix,
    this.hex,
    this.shareable,
  });
}

typedef Nip27 = TextNoteReference;
