import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Close', () {
    test('Constructor', () {
      final subscriptionId = generateRandomHex();
      final close = Close(subscriptionId);
      expect(close.subscriptionId, subscriptionId);
    });

    test('Close.serialize', () {
      final subscriptionId = generateRandomHex();
      final serialized = '["CLOSE","$subscriptionId"]';
      final close = Close(subscriptionId);
      expect(close.serialize(), serialized);
    });

    test('Request.deserialize', () {
      final subscriptionId = generateRandomHex();
      final serialized = json.encode(["CLOSE", subscriptionId]);
      final close = Close.deserialize(serialized);
      expect(close.subscriptionId, subscriptionId);
    });
  });
}
