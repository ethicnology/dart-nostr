import 'package:nostr/nostr.dart';

/// Event Deletion Request (NIP-09)
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
  static Event encode(
    List<String> eventIds,
    String content,
    String secretKey, {
    List<String> addressableCoords = const [],
    List<int> kinds = const [],
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

  /// Converts an Event to a [DeletionRequest] model.
  static DeletionRequest toDeleteEvent(Event event) {
    return DeletionRequest(
      event.pubkey,
      tagsToList(event.tags),
      tagsToAddressableCoords(event.tags),
      event.content,
      event.createdAt,
    );
  }

  /// Decodes a kind-5 event into a [DeletionRequest].
  static DeletionRequest decode(Event event) {
    if (event.kind == 5) return toDeleteEvent(event);
    throw Exception("${event.kind} is not nip9 compatible");
  }
}

/// Represents a NIP-09 deletion request event.
class DeletionRequest {
  /// Public key of the deletion request author.
  String pubkey;

  /// Event IDs requested for deletion (from `e` tags).
  List<String> eventIds;

  /// Addressable event coordinates requested for deletion (from `a` tags).
  List<String> addressableCoords;

  /// Optional human-readable reason for deletion.
  String reason;

  /// Unix timestamp of the deletion request.
  int createdAt;

  DeletionRequest(
    this.pubkey,
    this.eventIds,
    this.addressableCoords,
    this.reason,
    this.createdAt,
  );
}

typedef Deletion = Nip9;
