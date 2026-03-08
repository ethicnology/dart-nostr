import 'dart:convert';

/// Command results (OK messages), now part of [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
///
/// When submitting events to relays, clients currently have no way to know if an event was successfully committed to the database.
/// This NIP introduces the concept of command results which are like NOTICE's except provide more information about if an event was accepted or rejected.
///
/// Event successfully written to the database:
///
/// ["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, ""]
///
/// Event successfully written to the database because of a reason:
///
/// ["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, "pow: difficulty 25>=24"]
///
/// Event blocked due to ip filter:
///
/// ["OK", "b1a649ebe8...", false, "blocked: tor exit nodes not allowed"]
///
/// ...
class Nip20 {
  /// The event ID this result refers to.
  late String eventId;

  /// Whether the event was accepted (`true`) or rejected (`false`).
  late bool status;

  /// A human-readable message providing additional context.
  late String message;

  /// Creates a [Nip20] with the given [eventId], [status], and [message].
  Nip20(this.eventId, this.status, this.message);

  /// Serialize to nostr OK message.
  ///
  /// Format: `["OK", "event_id", true|false, "message"]`
  String serialize() => json.encode(["OK", eventId, status, message]);

  /// Deserialize a nostr OK message.
  ///
  /// Format: `["OK", "event_id", true|false, "message"]`
  Nip20.deserialize(String payload) {
    final data = json.decode(payload);
    assert(data.length == 4);
    eventId = data[1];
    status = data[2];
    message = data[3];
  }
}

typedef CommandResult = Nip20;
