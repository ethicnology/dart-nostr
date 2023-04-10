import 'dart:convert';

import 'package:nostr/src/filter.dart';

class Ok {
  late String string;

  Ok(this.string);

  /// Serialize to nostr OK message
  /// - ["OK", string, bool, string]
  String serialize() {
    var header = jsonEncode(["OK", string]);
    return '${header}';
  }

  /// Deserialize a nostr OK message
  /// - ["OK", string]
  Ok.deserialize(input) {
    string = input[1];
  }

  bool isValid() {
    return true;
  }
}
