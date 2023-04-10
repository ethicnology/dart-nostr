import 'dart:convert';

import 'package:nostr/src/filter.dart';

class Ok {
  late String subscriptionId;

  Ok(this.subscriptionId);

  /// Serialize to nostr request message
  /// - ["REQ", subscription_id, filter JSON, filter JSON, ...]
  String serialize() {
    var header = jsonEncode(["OK", subscriptionId]);
    return '${header}';
  }

  /// Deserialize a nostr OK message
  /// - ["OK", subscription_id]
  Ok.deserialize(input) {
    assert(input.length == 2);
    subscriptionId = input[1];
  }

  bool isValid() {
    return true;
  }
}
