import 'dart:convert';

import 'package:nostr/nostr.dart';

// Used to deserialize any kind of message that a nostr client or relay can transmit.
class Message {
  late String type;
  late MessageType concreteType;
  late dynamic message;

// nostr message deserializer
  Message.deserialize(String payload) {
    dynamic data = jsonDecode(payload);
    if (MessageType.values.map<String>((e) => e.rawType).contains(data[0]) ==
        false) {
      throw 'Unsupported payload (or NIP)';
    }

    type = data[0];
    concreteType = MessageType.byRawType(data[0]);
    switch (concreteType) {
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

  const MessageType(this.rawType);
  final String rawType;
  static MessageType byRawType(String name) {
    return MessageType.values.byName(name.toLowerCase());
  }
}
