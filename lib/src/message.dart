import 'dart:convert';

import 'package:nostr/nostr.dart';

// Used to deserialize any kind of message that a nostr client or relay can transmit.
class Message {
  late dynamic message;
  late MessageType messageType;

  String get type => messageType.name;

// nostr message deserializer
  Message.deserialize(String payload) {
    dynamic data = jsonDecode(payload);
    if (!MessageType.values.map((e) => e.name).contains(data[0])) {
      throw 'Unsupported payload (or NIP)';
    }

    messageType = MessageType.fromName(data[0]);
    switch (messageType) {
      case MessageType.event:
        message = Event.deserialize(data);
        // ignore: deprecated_member_use_from_same_package
        if (message.kind == 4) message = EncryptedDirectMessage(message);
        break;
      case MessageType.ok:
        message = Nip20.deserialize(data);
        break;
      case MessageType.req:
        message = Request.deserialize(data);
        break;
      case MessageType.close:
        message = Close.deserialize(data);
        break;
      default:
        message = jsonEncode(data.sublist(1));
        break;
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

  static fromName(String name) => MessageType.values.byName(name.toLowerCase());
}
