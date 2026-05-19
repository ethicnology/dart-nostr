import 'package:nostr/nostr.dart';

/// Relay List Metadata — [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md)
///
/// A kind 10002 replaceable event advertising a user's preferred relays
/// with optional read/write markers.
class RelayList {
  /// Event kind for relay list metadata.
  static const int kindRelayList = 10002;

  /// Creates a kind 10002 relay list event.
  ///
  /// Each [RelayMetadataData] entry becomes an `r` tag:
  /// - `["r", url]` if both read and write
  /// - `["r", url, "read"]` if read-only
  /// - `["r", url, "write"]` if write-only
  static Event create({
    required List<RelayMetadataData> relays,
    required String secretKey,
  }) {
    final tags = relays.map((r) {
      if (r.read && r.write) return ["r", r.url];
      if (r.read) return ["r", r.url, "read"];
      return ["r", r.url, "write"];
    }).toList();

    return Event.from(
      kind: kindRelayList,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Decodes a kind 10002 event into a list of [RelayMetadataData].
  ///
  /// Per NIP-65: when the marker is omitted, the relay is both read and
  /// write. Unknown markers fall back to the same default rather than
  /// silently dropping the relay — spec says "If the marker is omitted,
  /// the relay is used for both purposes" without prescribing what to do
  /// with malformed markers, so we keep the relay rather than lose it.
  ///
  /// Throws [InvalidKindException] if the event is not kind 10002.
  static List<RelayMetadataData> parse(Event event) {
    if (event.kind != kindRelayList) {
      throw InvalidKindException(event.kind, [kindRelayList]);
    }
    final List<RelayMetadataData> relays = [];
    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'r') continue;
      final url = tag[1];
      final marker = tag.length > 2 ? tag[2] : '';
      switch (marker) {
        case 'read':
          relays.add(RelayMetadataData(url: url, read: true, write: false));
        case 'write':
          relays.add(RelayMetadataData(url: url, read: false, write: true));
        default:
          relays.add(RelayMetadataData(url: url, read: true, write: true));
      }
    }
    return relays;
  }
}

/// A relay entry with read/write capabilities.
class RelayMetadataData {
  /// The relay WebSocket URL.
  final String url;

  /// Whether to read events from this relay.
  final bool read;

  /// Whether to write events to this relay.
  final bool write;

  /// Creates a [RelayMetadataData].
  const RelayMetadataData({
    required this.url,
    required this.read,
    required this.write,
  });
}

typedef Nip65 = RelayList;
typedef RelayMetadata = RelayMetadataData;
