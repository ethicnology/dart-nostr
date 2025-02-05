import 'dart:convert';

import 'package:nostr/src/filter.dart';

/// Used to request events and subscribe to new updates.
class Request {
  /// subscription_id is a random string that should be used to represent a subscription.
  late String subscriptionId;

  /// filters is a JSON object that determines what events will be sent in that subscription
  late List<Filter> filters;

  Request({required this.subscriptionId, this.filters = const []});

  /// Serialize to nostr request message
  /// - ["REQ", subscription_id, filter JSON, filter JSON, ...]
  String serialize() {
    final theFilters = filters.map((item) => item.toJson()).toList();

    return json.encode(
      [
        "REQ",
        subscriptionId,
        if (filters.isEmpty) Filter() else ...theFilters,
      ],
    );
  }

  /// Deserialize a nostr request message
  /// - '["REQ", subscriptionId, filter JSON, filter JSON, ...]'
  Request.deserialize(String input) {
    final payload = json.decode(input);

    // Ensure we have at least ["REQ", <someId>]
    if (payload.length < 2) {
      throw 'Message too short to be a REQ message';
    }

    if (payload[0] != "REQ") {
      throw 'Not a REQ message (first element must be "REQ")';
    }

    subscriptionId = payload[1];
    filters = [];

    // Remaining items (from index 2 onward) are filters
    if (payload.length > 2) {
      for (var i = 2; i < payload.length; i++) {
        filters.add(Filter.fromJson(payload[i]));
      }
    }
  }
}
