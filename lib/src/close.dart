import 'dart:convert';

import 'package:nostr/src/error.dart';

/// Represents a Nostr CLOSE message used to stop previous subscriptions.
///
/// A relay sends or receives CLOSE messages to terminate an active
/// subscription identified by [subscriptionId].
class Close {
  /// The subscription identifier for the subscription to close.
  ///
  /// This is a random string that was used when the subscription was created.
  final String subscriptionId;

  /// Creates a [Close] message for the given [subscriptionId].
  Close(this.subscriptionId);

  /// Serializes this close message to the Nostr wire format.
  ///
  /// Returns a JSON-encoded string: `["CLOSE", subscription_id]`.
  String serialize() => json.encode(["CLOSE", subscriptionId]);

  /// Deserializes a Nostr CLOSE message from a JSON-encoded [payload].
  ///
  /// The expected format is `["CLOSE", subscription_id]`.
  ///
  /// Throws a [DeserializationException] if the payload length is not 2.
  factory Close.deserialize(String payload) {
    final data = json.decode(payload);
    if (data.length != 2) {
      throw const DeserializationException('Invalid length for CLOSE message');
    }
    return Close(data[1]);
  }
}
