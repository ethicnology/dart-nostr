import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Eose', () {
    test('Constructor', () {
      final String subscriptionId = generate64RandomHexChars();
      final eose = Eose(subscriptionId);
      expect(eose.subscriptionId, subscriptionId);
    });

    test('Eose.serialize', () {
      final String subscriptionId = generate64RandomHexChars();
      final String serialized = '["EOSE","$subscriptionId"]';
      final eose = Eose(subscriptionId);
      expect(eose.serialize(), serialized);
    });

    test('Eose.deserialize', () {
      final String subscriptionId = generate64RandomHexChars();
      final serialized = json.encode(["EOSE", subscriptionId]);
      final eose = Eose.deserialize(serialized);
      expect(eose.subscriptionId, subscriptionId);
    });
  });
}
