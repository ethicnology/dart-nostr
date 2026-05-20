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
  const Request({required this.subscriptionId, this.filters = const []});

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
        if (filters.isEmpty) const Filter() else ...theFilters,
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
    final Object? data;
    try {
      data = json.decode(payload);
    } on FormatException catch (e) {
      throw DeserializationException('REQ payload is not valid JSON: $e');
    }

    if (data is! List) {
      throw const DeserializationException(
        'REQ must be a JSON array',
      );
    }
    if (data.length < 2) {
      throw const DeserializationException(
        'Message too short to be a REQ message',
      );
    }
    if (data[0] != "REQ") {
      throw const DeserializationException(
        'Not a REQ message (first element must be "REQ")',
      );
    }
    if (data[1] is! String) {
      throw const DeserializationException(
        'REQ subscription id must be a string',
      );
    }

    final subscriptionId = data[1] as String;
    final filters = <Filter>[];

    for (var i = 2; i < data.length; i++) {
      final entry = data[i];
      if (entry is! Map<String, dynamic>) {
        throw DeserializationException(
          'REQ filter at index $i must be a JSON object',
        );
      }
      filters.add(Filter.fromJson(entry));
    }

    return Request(subscriptionId: subscriptionId, filters: filters);
  }
}
