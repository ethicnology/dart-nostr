import 'dart:convert';

import 'package:nostr/nostr.dart';

// Used to deserialize any kind of message that a nostr client or relay can transmit.
class Message {
  late String type;
  late dynamic message;

// nostr message deserializer
  Message.deserialize(String payload) {
    dynamic data = jsonDecode(payload);
    var messages = ["EVENT", "REQ", "CLOSE", "NOTICE", "EOSE", "OK", "AUTH"];
    if (messages.contains(data[0]) == false) {
      throw 'Unsupported payload (or NIP)';
    }

    type = data[0];
    switch (type) {
      case "EVENT":
        message = Event.deserialize(data);
        if (message.kind == 4) message = EncryptedDirectMessage(message);
        break;
      case "REQ":
        message = Request.deserialize(data);
        break;
      case "CLOSE":
        message = Close.deserialize(data);
        break;
      default:
        message = jsonEncode(data.sublist(1));
        break;
    }
  }
}
