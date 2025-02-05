import 'dart:convert';

/// Indicates "end of stored events"
///
/// this class is mostly for getting subscription id
class Eose {
  /// default constructor
  Eose(this.subscriptionId);

  /// subscription_id is a random string that should be used to represent a subscription.
  final String subscriptionId;

  /// Serialize to nostr close message
  /// - ["EOSE", subscription_id]
  String serialize() {
    return json.encode(["EOSE", subscriptionId]);
  }

  /// Deserialize a nostr close message
  /// - ["CLOSE", subscription_id]
  factory Eose.deserialize(String payload) {
    final data = json.decode(payload);
    if (data is! List<dynamic>) throw 'Invalid type for EOSE message';
    if (data.length != 2) throw 'Invalid length for EOSE message';
    return Eose(data[1]);
  }
}
