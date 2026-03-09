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
    final data = json.decode(payload);
    if (data.length != 4) {
      throw const DeserializationException('Invalid OK message length');
    }
    return CommandResult(data[1], data[2], data[3]);
  }
}

typedef Nip20 = CommandResult;
