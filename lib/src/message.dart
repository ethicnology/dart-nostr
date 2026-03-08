import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Deserializes any kind of message that a Nostr client or relay can transmit.
///
/// Use [Message.deserialize] to parse an incoming JSON payload into the
/// appropriate typed object accessible via [message].
class Message {
  /// The deserialized message object.
  ///
  /// The runtime type depends on [messageType]: for example, an
  /// [Event] for [MessageType.event], a [Request] for [MessageType.req], etc.
  final dynamic message;

  /// The type of the deserialized message (e.g. EVENT, REQ, CLOSE).
  final MessageType messageType;

  Message._(this.message, this.messageType);

  /// The uppercase label of the message type (e.g. `"EVENT"`).
  String get type => messageType.label;

  /// Deserializes a Nostr message from a JSON-encoded [payload].
  ///
  /// Throws a [DeserializationException] if the message type is not
  /// recognized.
  factory Message.deserialize(String payload) {
    final dynamic data = json.decode(payload);
    if (!MessageType.values.map((e) => e.label).contains(data[0])) {
      throw const DeserializationException('Unsupported payload (or NIP)');
    }

    final messageType = MessageType.from(data[0]);
    dynamic message;
    switch (messageType) {
      case MessageType.event:
        message = Event.deserialize(payload);
      case MessageType.ok:
        message = Nip20.deserialize(payload);
      case MessageType.req:
        message = Request.deserialize(payload);
      case MessageType.close:
        message = Close.deserialize(payload);
      case MessageType.closed:
        // ["CLOSED", <subscription_id>, <message>]
        message = {'subscriptionId': data[1], 'message': data[2]};
      case MessageType.eose:
        message = Eose.deserialize(payload);
      case MessageType.notice:
        message = json.encode(data.sublist(1));
      case MessageType.auth:
        message = json.encode(data.sublist(1));
    }
    return Message._(message, messageType);
  }
}

/// Enumerates the known Nostr message types.
enum MessageType {
  /// An EVENT message containing a signed event.
  event("EVENT"),

  /// A REQ message requesting events and subscribing to updates.
  req("REQ"),

  /// A CLOSE message stopping an existing subscription.
  close("CLOSE"),

  /// A CLOSED message indicating a subscription was ended by the relay.
  closed("CLOSED"),

  /// A NOTICE message containing a human-readable notice from the relay.
  notice("NOTICE"),

  /// An EOSE message indicating end of stored events.
  eose("EOSE"),

  /// An OK message indicating whether an event was accepted or rejected.
  ok("OK"),

  /// An AUTH message for relay authentication (NIP-42).
  auth("AUTH");

  /// The wire-format label for this message type (e.g. `"EVENT"`).
  final String label;

  const MessageType(this.label);

  /// Returns the [MessageType] matching the given [value] label.
  static MessageType from(String value) =>
      MessageType.values.firstWhere((e) => e.label == value);
}
