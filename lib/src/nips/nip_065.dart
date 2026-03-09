import 'package:nostr/nostr.dart';

/// Relay List Metadata — [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md)
///
/// A kind 10002 replaceable event advertising a user's preferred relays
/// with optional read/write markers.
class Nip65 {
  /// Creates a kind 10002 relay list event.
  ///
  /// Each [RelayMetadata] entry becomes an `r` tag:
  /// - `["r", url]` if both read and write
  /// - `["r", url, "read"]` if read-only
  /// - `["r", url, "write"]` if write-only
  static Event encode({
    required List<RelayMetadata> relays,
    required String secretKey,
  }) {
    final tags = relays.map((r) {
      if (r.read && r.write) return ["r", r.url];
      if (r.read) return ["r", r.url, "read"];
      return ["r", r.url, "write"];
    }).toList();

    return Event.from(
      kind: 10002,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Decodes a kind 10002 event into a list of [RelayMetadata].
  ///
  /// Throws [InvalidKindException] if the event is not kind 10002.
  static List<RelayMetadata> decode(Event event) {
    if (event.kind != 10002) {
      throw InvalidKindException(event.kind, [10002]);
    }
    final List<RelayMetadata> relays = [];
    for (final tag in event.tags) {
      if (tag[0] != 'r' || tag.length < 2) continue;
      final url = tag[1];
      if (tag.length == 2) {
        relays.add(RelayMetadata(url: url, read: true, write: true));
      } else if (tag[2] == 'read') {
        relays.add(RelayMetadata(url: url, read: true, write: false));
      } else if (tag[2] == 'write') {
        relays.add(RelayMetadata(url: url, read: false, write: true));
      }
    }
    return relays;
  }
}

/// A relay entry with read/write capabilities.
class RelayMetadata {
  /// The relay WebSocket URL.
  final String url;

  /// Whether to read events from this relay.
  final bool read;

  /// Whether to write events to this relay.
  final bool write;

  /// Creates a [RelayMetadata].
  const RelayMetadata({
    required this.url,
    required this.read,
    required this.write,
  });
}

typedef RelayList = Nip65;
