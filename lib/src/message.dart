import 'dart:convert';

import 'package:nostr/nostr.dart';

// Used to deserialize any kind of message that a nostr client or relay can transmit.
class Message {
  late dynamic message;
  late MessageType messageType;

  String get type => messageType.name;

// nostr message deserializer
  Message.deserialize(String payload) {
    final dynamic data = json.decode(payload);
    if (!MessageType.values.map((e) => e.name).contains(data[0])) {
      throw Exception('Unsupported payload (or NIP)');
    }

    messageType = MessageType.from(data[0]);
    switch (messageType) {
      case MessageType.event:
        message = Event.deserialize(payload);
        // ignore: deprecated_member_use_from_same_package
        if (message.kind == 4) message = EncryptedDirectMessage(message);
      case MessageType.ok:
        message = Nip20.deserialize(payload);
      case MessageType.req:
        message = Request.deserialize(payload);
      case MessageType.close:
        message = Close.deserialize(payload);
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
  notice("NOTICE"),
  eose("EOSE"),
  ok("OK"),
  auth("AUTH");

  final String name;
  const MessageType(this.name);

  static MessageType from(String name) =>
      MessageType.values.byName(name.toLowerCase());
}
