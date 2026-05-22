import 'dart:convert';

import 'package:nostr/src/error.dart';

/// Command results (OK messages) — [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
///
/// Relays send OK messages to indicate whether an event was accepted or rejected.
///
/// Format: `["OK", <event_id>, <true|false>, <message>]`
///
/// The message field is always present but may be empty on acceptance.
/// On rejection, the message follows the format `prefix: human-readable explanation`
/// with standardized prefixes: `duplicate`, `pow`, `blocked`, `rate-limited`,
/// `invalid`, `restricted`, `mute`, `error`.
class CommandResult {
  /// The event ID this result refers to.
  final String eventId;

  /// Whether the event was accepted (`true`) or rejected (`false`).
  final bool status;

  /// A human-readable message providing additional context.
  ///
  /// May be empty when [status] is `true`.
  /// When [status] is `false`, follows the format `prefix: explanation`.
  final String message;

  /// Creates a [CommandResult] with the given [eventId], [status], and [message].
  const CommandResult(this.eventId, this.status, this.message);

  /// Serialize to nostr OK message.
  ///
  /// Format: `["OK", "event_id", true|false, "message"]`
  String serialize() => json.encode(["OK", eventId, status, message]);

  /// Deserialize a nostr OK message.
  ///
  /// Format: `["OK", "event_id", true|false, "message"]`
  ///
  /// Throws [DeserializationException] if the payload is not a valid OK message.
  factory CommandResult.deserialize(String payload) {
    final Object? data;
    try {
      data = json.decode(payload);
    } on FormatException catch (e) {
      throw DeserializationException('OK payload is not valid JSON: $e');
    }
    if (data is! List ||
        data.length != 4 ||
        data[0] != 'OK' ||
        data[1] is! String ||
        data[2] is! bool ||
        data[3] is! String) {
      throw const DeserializationException(
        'OK must be ["OK", event_id, bool, message]',
      );
    }
    return CommandResult(data[1] as String, data[2] as bool, data[3] as String);
  }
}

typedef Nip20 = CommandResult;
