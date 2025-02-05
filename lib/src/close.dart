import 'dart:convert';

/// Used to stop previous subscriptions.
class Close {
  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  /// Default constructor
  Close(this.subscriptionId);

  /// Serialize to nostr close message
  /// - ["CLOSE", subscription_id]
  String serialize() => json.encode(["CLOSE", subscriptionId]);

  /// Deserialize a nostr close message
  /// - ["CLOSE", subscription_id]
  Close.deserialize(String payload) {
    final data = json.decode(payload);
    if (data.length != 2) throw Exception('Invalid length for CLOSE message');
    subscriptionId = data[1];
  }
}
