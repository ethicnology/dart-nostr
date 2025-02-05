import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Close', () {
    test('Constructor', () {
      final subscriptionId = generate64RandomHexChars();
      final close = Close(subscriptionId);
      expect(close.subscriptionId, subscriptionId);
    });

    test('Close.serialize', () {
      final subscriptionId = generate64RandomHexChars();
      final serialized = '["CLOSE","$subscriptionId"]';
      final close = Close(subscriptionId);
      expect(close.serialize(), serialized);
    });

    test('Request.deserialize', () {
      final subscriptionId = generate64RandomHexChars();
      final serialized = json.encode(["CLOSE", subscriptionId]);
      final close = Close.deserialize(serialized);
      expect(close.subscriptionId, subscriptionId);
    });
  });
}
