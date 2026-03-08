import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Deserializes any kind of message that a nostr client or relay can transmit.
class Message {
  late dynamic message;
  late MessageType messageType;

  String get type => messageType.label;

  /// Nostr message deserializer
  Message.deserialize(String payload) {
    final dynamic data = json.decode(payload);
    if (!MessageType.values.map((e) => e.label).contains(data[0])) {
      throw Exception('Unsupported payload (or NIP)');
    }

    messageType = MessageType.from(data[0]);
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
  }
}

enum MessageType {
  event("EVENT"),
  req("REQ"),
  close("CLOSE"),
  closed("CLOSED"),
  notice("NOTICE"),
  eose("EOSE"),
  ok("OK"),
  auth("AUTH");

  final String label;
  const MessageType(this.label);

  static MessageType from(String value) =>
      MessageType.values.firstWhere((e) => e.label == value);
}
