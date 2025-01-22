import 'package:nostr/nostr.dart';

/// Event Deletion
///
/// A special event with kind 5, meaning "deletion request," is defined as having a list of one or more tags referencing events the author is requesting to delete.
/// Each tag entry should follow this format:
/// - ["e", "event ID"] for referencing events by ID.
/// - ["a", "kind:pubkey:d-identifier"] for replaceable events up to the deletion timestamp.
/// The `content` field may contain a reason for the deletion.
///
/// Example:
/// ```json
/// {
///   "kind": 5,
///   "pubkey": "32-bytes hex-encoded public key",
///   "tags": [
///     ["e", "dcd59..464a2"],
///     ["e", "968c5..ad7a4"],
///     ["a", "kind:pubkey:d-identifier"]
///   ],
///   "content": "these posts were published by accident"
/// }
/// ```
class Nip9 {
  /// Converts a list of event IDs into a list of tags with "e" entries.
  ///
  /// ```dart
  /// List<String> events = ["event1", "event2"];
  /// List<List<String>> tags = Nip9.toTags(events);
  /// ```
  static List<List<String>> toTags(List<String> events) {
    List<List<String>> result = [];
    for (var event in events) {
      result.add(["e", event]);
    }
    return result;
  }

  /// Encodes a deletion request event from event IDs, reason, and keys.
  ///
  /// ```dart
  /// Event event = Nip9.encode(["event1", "event2"], "Reason", "pubkey", "privkey");
  /// ```
  static Event encode(
    List<String> eventIds,
    String content,
    String pubkey,
    String privkey,
  ) {
    return Event.from(
      kind: 5,
      tags: toTags(eventIds),
      content: content,
      pubkey: pubkey,
      privkey: privkey,
    );
  }

  /// Converts an Event to a Nip9DeletionRequest instance.
  ///
  /// ```dart
  /// Nip9DeletionRequest deleteEvent = Nip9.toDeleteEvent(event);
  /// ```
  static Nip9DeletionRequest toDeleteEvent(Event event) {
    return Nip9DeletionRequest(
      event.pubkey,
      tagsToList(event.tags),
      event.content,
      event.createdAt,
    );
  }

  /// Extracts event IDs from tags.
  ///
  /// ```dart
  /// List<List<String>> tags = [["e", "event1"], ["e", "event2"]];
  /// List<String> eventIds = Nip9.tagsToList(tags);
  /// ```
  static List<String> tagsToList(List<List<String>> tags) {
    List<String> deleteEvents = [];
    for (var tag in tags) {
      if (tag[0] == "e") deleteEvents.add(tag[1]);
    }
    return deleteEvents;
  }

  /// Decodes a deletion request event into a Nip9DeletionRequest.
  ///
  /// ```dart
  /// Nip9DeletionRequest deleteEvent = Nip9.decode(event);
  /// ```
  static Nip9DeletionRequest decode(Event event) {
    if (event.kind == 5) return toDeleteEvent(event);
    throw Exception("${event.kind} is not nip9 compatible");
  }
}

/// Represents a deletion request event.
class Nip9DeletionRequest {
  /// Public key of the deletion request author.
  String pubkey;

  /// List of event IDs requested for deletion.
  List<String> deleteEvents;

  /// Reason for deletion (may be empty).
  String reason;

  /// Timestamp of the deletion request.
  int deleteTime;

  /// Constructor for Nip9DeletionRequest.
  Nip9DeletionRequest(
      this.pubkey, this.deleteEvents, this.reason, this.deleteTime);
}
