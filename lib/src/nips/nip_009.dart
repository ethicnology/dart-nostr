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
class Deletion {
  /// Event kind for deletion requests.
  static const int kindDeletion = 5;

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

  /// Creates a deletion request event.
  ///
  /// [eventIds] references regular events by ID.
  /// [addressableCoords] references replaceable/addressable events by coordinate.
  /// [kinds] optionally indicates which kinds are being deleted.
  ///
  /// Per NIP-09 spec, a deletion request MUST reference at least one
  /// event — supply [eventIds] or [addressableCoords] (or both).
  /// Throws [InvalidArgumentException] when both are empty.
  static Event create({
    required String secretKey,
    List<String> eventIds = const [],
    List<String> addressableCoords = const [],
    List<int> kinds = const [],
    String content = '',
  }) {
    if (eventIds.isEmpty && addressableCoords.isEmpty) {
      throw InvalidArgumentException(
        'eventIds/addressableCoords',
        'must contain at least one entry — per NIP-09 a deletion request '
            'MUST reference at least one event',
      );
    }
    return Event.from(
      kind: kindDeletion,
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
        .where((tag) => tag.length >= 2 && tag[0] == "e")
        .map((tag) => tag[1])
        .toList();
  }

  /// Extracts addressable event coordinates from `a` tags.
  static List<String> tagsToAddressableCoords(List<List<String>> tags) {
    return tags
        .where((tag) => tag.length >= 2 && tag[0] == "a")
        .map((tag) => tag[1])
        .toList();
  }

  /// Parses a kind-5 event into a [DeletionRequestData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 5.
  static DeletionRequestData parse(Event event) {
    if (event.kind != kindDeletion) {
      throw InvalidKindException(event.kind, [kindDeletion]);
    }
    final kindStrings = findAllTagValues(event.tags, 'k');
    final kinds = <int>[];
    for (final k in kindStrings) {
      final parsed = int.tryParse(k);
      if (parsed != null) kinds.add(parsed);
    }
    return DeletionRequestData(
      pubkey: event.pubkey,
      eventIds: tagsToList(event.tags),
      addressableCoords: tagsToAddressableCoords(event.tags),
      kinds: kinds,
      reason: event.content,
      createdAt: event.createdAt,
    );
  }
}

/// Represents a NIP-09 deletion request event.
class DeletionRequestData {
  /// Public key of the deletion request author.
  final String pubkey;

  /// Event IDs requested for deletion (from `e` tags).
  final List<String> eventIds;

  /// Addressable event coordinates requested for deletion (from `a` tags).
  final List<String> addressableCoords;

  /// Kind numbers being deleted (from `k` tags).
  final List<int> kinds;

  /// Optional human-readable reason for deletion.
  final String reason;

  /// Unix timestamp of the deletion request.
  final int createdAt;

  /// Creates a [DeletionRequestData] with the given fields.
  const DeletionRequestData({
    required this.pubkey,
    required this.createdAt,
    this.eventIds = const [],
    this.addressableCoords = const [],
    this.kinds = const [],
    this.reason = '',
  });
}

typedef Nip9 = Deletion;
typedef DeletionRequest = DeletionRequestData;
