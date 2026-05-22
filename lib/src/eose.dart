import 'dart:convert';

import 'package:nostr/src/error.dart';

/// Represents a Nostr EOSE (End Of Stored Events) message.
///
/// A relay sends an EOSE message to indicate that all stored events
/// matching a subscription have been sent. After this message, only
/// new events will be transmitted for the subscription.
class Eose {
  /// Creates an [Eose] message for the given [subscriptionId].
  const Eose(this.subscriptionId);

  /// The subscription identifier that this EOSE message refers to.
  final String subscriptionId;

  /// Serializes this EOSE message to the Nostr wire format.
  ///
  /// Returns a JSON-encoded string: `["EOSE", subscription_id]`.
  String serialize() {
    return json.encode(["EOSE", subscriptionId]);
  }

  /// Deserializes a Nostr EOSE message from a JSON-encoded [payload].
  ///
  /// The expected format is `["EOSE", subscription_id]`.
  ///
  /// Throws a [DeserializationException] if the payload is not a list
  /// or does not contain exactly two elements.
  factory Eose.deserialize(String payload) {
    final Object? data;
    try {
      data = json.decode(payload);
    } on FormatException catch (e) {
      throw DeserializationException('EOSE payload is not valid JSON: $e');
    }
    if (data is! List ||
        data.length != 2 ||
        data[0] != 'EOSE' ||
        data[1] is! String) {
      throw const DeserializationException(
        'EOSE must be ["EOSE", subscription_id]',
      );
    }
    return Eose(data[1] as String);
  }
}
