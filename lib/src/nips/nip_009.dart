import 'package:nostr/nostr.dart';

/// Event deletion requests — [NIP-09](https://github.com/nostr-protocol/nips/blob/master/09.md)
///
/// A kind 5 event requesting deletion of previously published events.
/// Tags may reference events by ID ("e"), addressable events ("a"),
/// and optionally indicate the kinds being deleted ("k").
///
/// Example:
/// ```json
/// {
///   "kind": 5,
///   "pubkey": "32-bytes hex-encoded public key",
///   "tags": [
///     ["e", "dcd59..464a2"],
///     ["a", "30023:pubkey:d-identifier"],
///     ["k", "1"]
///   ],
///   "content": "these posts were published by accident"
/// }
/// ```
class Nip9 {
  /// Converts a list of event IDs to `["e", id]` tags.
  static List<List<String>> toTags(List<String> events) {
    return events.map((id) => ["e", id]).toList();
  }

  /// Converts a list of addressable event coordinates to `["a", coord]` tags.
  static List<List<String>> toATags(List<String> coords) {
    return coords.map((coord) => ["a", coord]).toList();
  }

  /// Converts a list of kind numbers to `["k", kind]` tags.
  static List<List<String>> toKTags(List<int> kinds) {
    return kinds.map((k) => ["k", k.toString()]).toList();
  }

  /// Encodes a deletion request event.
  ///
  /// [eventIds] references regular events by ID.
  /// [addressableCoords] references replaceable/addressable events by coordinate.
  /// [kinds] optionally indicates which kinds are being deleted.
  static Event encode({
    required String secretKey,
    List<String> eventIds = const [],
    List<String> addressableCoords = const [],
    List<int> kinds = const [],
    String content = '',
  }) {
    return Event.from(
      kind: 5,
      tags: [
        ...toTags(eventIds),
        ...toATags(addressableCoords),
        ...toKTags(kinds),
      ],
      content: content,
      secretKey: secretKey,
    );
  }

  /// Extracts event IDs from `e` tags.
  static List<String> tagsToList(List<List<String>> tags) {
    return tags
        .where((tag) => tag[0] == "e")
        .map((tag) => tag[1])
        .toList();
  }

  /// Extracts addressable event coordinates from `a` tags.
  static List<String> tagsToAddressableCoords(List<List<String>> tags) {
    return tags
        .where((tag) => tag[0] == "a")
        .map((tag) => tag[1])
        .toList();
  }

  /// Decodes a kind-5 event into a [DeletionRequest].
  ///
  /// Throws [InvalidKindException] if the event kind is not 5.
  static DeletionRequest decode(Event event) {
    if (event.kind != 5) throw InvalidKindException(event.kind, [5]);
    return DeletionRequest(
      pubkey: event.pubkey,
      eventIds: tagsToList(event.tags),
      addressableCoords: tagsToAddressableCoords(event.tags),
      reason: event.content,
      createdAt: event.createdAt,
    );
  }
}

/// Represents a NIP-09 deletion request event.
class DeletionRequest {
  /// Public key of the deletion request author.
  final String pubkey;

  /// Event IDs requested for deletion (from `e` tags).
  final List<String> eventIds;

  /// Addressable event coordinates requested for deletion (from `a` tags).
  final List<String> addressableCoords;

  /// Optional human-readable reason for deletion.
  final String reason;

  /// Unix timestamp of the deletion request.
  final int createdAt;

  /// Creates a [DeletionRequest] with the given fields.
  const DeletionRequest({
    required this.pubkey,
    required this.createdAt,
    this.eventIds = const [],
    this.addressableCoords = const [],
    this.reason = '',
  });
}

typedef Deletion = Nip9;
