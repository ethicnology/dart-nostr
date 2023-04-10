import 'dart:convert';

import 'package:nostr/src/filter.dart';

/// Message sent by relay when reaching end of events
class Eose {
  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  Eose(this.subscriptionId);

  /// Serialize to nostr EOSE message
  /// - ["EOSE", subscription_id]
  String serialize() {
    var header = jsonEncode(["EOSE", subscriptionId]);
    return '${header}';
  }

  /// Deserialize a nostr EOSE message
  /// - ["EOSE", subscription_id]
  Eose.deserialize(input) {
    assert(input.length == 2);
    subscriptionId = input[1];
  }

  bool isValid() {
    return true;
  }
}

