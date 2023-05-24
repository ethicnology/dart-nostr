import 'dart:convert';

/// Used to stop previous subscriptions.
class Close {
  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  /// Default constructor
  Close(this.subscriptionId);

  /// Serialize to nostr close message
  /// - ["CLOSE", subscription_id]
  String serialize() {
    return jsonEncode(["CLOSE", subscriptionId]);
  }

  /// Deserialize a nostr close message
  /// - ["CLOSE", subscription_id]
  Close.deserialize(input) {
    if (input.length != 2) throw 'Invalid length for CLOSE message';
    subscriptionId = input[1];
  }
}
