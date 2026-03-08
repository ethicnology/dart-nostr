import 'dart:convert';

import 'package:nostr/src/error.dart';
import 'package:nostr/src/filter.dart';

/// Represents a Nostr REQ message used to request events and subscribe
/// to new updates.
///
/// A REQ message contains a [subscriptionId] and one or more [filters]
/// that determine which events will be returned.
class Request {
  /// The subscription identifier for this request.
  ///
  /// This is a random string that uniquely identifies the subscription.
  final String subscriptionId;

  /// The list of filters that determine which events will be sent in
  /// this subscription.
  final List<Filter> filters;

  /// Creates a [Request] with the given [subscriptionId] and [filters].
  Request({required this.subscriptionId, this.filters = const []});

  /// Serializes this request to the Nostr wire format.
  ///
  /// Returns a JSON-encoded string:
  /// `["REQ", subscription_id, filter JSON, filter JSON, ...]`.
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

  /// Deserializes a Nostr REQ message from a JSON-encoded [payload].
  ///
  /// The expected format is:
  /// `["REQ", subscriptionId, filter JSON, filter JSON, ...]`.
  ///
  /// Throws a [DeserializationException] if the payload is too short
  /// or does not start with `"REQ"`.
  factory Request.deserialize(String payload) {
    final data = json.decode(payload);

    // Ensure we have at least ["REQ", <someId>]
    if (data.length < 2) {
      throw const DeserializationException('Message too short to be a REQ message');
    }

    if (data[0] != "REQ") {
      throw const DeserializationException(
        'Not a REQ message (first element must be "REQ")',
      );
    }

    final subscriptionId = data[1] as String;
    final filters = <Filter>[];

    // Remaining items (from index 2 onward) are filters
    if (data.length > 2) {
      for (var i = 2; i < data.length; i++) {
        filters.add(Filter.fromJson(data[i]));
      }
    }

    return Request(subscriptionId: subscriptionId, filters: filters);
  }
}
