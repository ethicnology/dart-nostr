import 'dart:convert';

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
/// …
class Nip20 {
  late String eventId;
  late bool status;
  late String message;

  /// Default constructor
  Nip20(this.eventId, this.status, this.message);

  /// Serialize to nostr close message
  /// - ["OK", "event_id", true|false, "message"]
  String serialize() => jsonEncode(["OK", eventId, status, message]);

  /// Deserialize a nostr close message
  /// - ["OK", "event_id", true|false, "message"]
  Nip20.deserialize(input) {
    assert(input.length == 4);
    eventId = input[1];
    status = input[2];
    message = input[3];
  }
}
