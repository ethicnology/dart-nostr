import 'dart:convert';

import 'package:nostr/nostr.dart';

// Used to deserialize any kind of message that a nostr client or relay can transmit.
class Message {
  late String type;
  late dynamic message;

// nostr message deserializer
  Message.deserialize(String payload) {
    dynamic data = jsonDecode(payload);
    List<String> messages = ["EVENT", "REQ", "CLOSE", "NOTICE", "EOSE", "OK", "AUTH"];
    if (data == null || !messages.contains(data[0])) {
      if (data != null) {
        print('"${data[0]}" is an unsupported payload (or NIP)');
      }
      message = null;
      return;
    }

    type = data[0];
    switch (type) {
      case "EVENT":
        message = Event.deserialize(data);
        break;
      case "EOSE":
        message = Eose.deserialize(data);
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
