import 'dart:convert';

import 'package:nostr/nostr.dart';

void main() async {
  final String subscriptionId = generate64RandomHexChars();
  final close1 = Close(subscriptionId);
  assert(close1.subscriptionId == subscriptionId);

  final close2 = Close(subscriptionId);
  assert(close2.serialize() == '["CLOSE","$subscriptionId"]');

  final close3 = Close.deserialize(json.encode(["CLOSE", subscriptionId]));
  assert(close3.subscriptionId == subscriptionId);
}
