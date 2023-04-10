import 'dart:convert';

import 'package:nostr/src/filter.dart';

/// Used to request events and subscribe to new updates.
class Eose {
  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  Eose(this.subscriptionId);

  /// Serialize to nostr request message
  /// - ["REQ", subscription_id, filter JSON, filter JSON, ...]
  String serialize() {
    var header = jsonEncode(["EOSE", subscriptionId]);
    return '${header}';
  }

  /// Deserialize a nostr eose message
  /// - ["EOSE", subscription_id]
  Eose.deserialize(input) {
    assert(input.length == 2);
    subscriptionId = input[1];
  }

  bool isValid() {
    return true;
  }
}

