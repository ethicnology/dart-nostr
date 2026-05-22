import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Eose', () {
    test('Constructor', () {
      final String subscriptionId = generateRandomHex();
      final eose = Eose(subscriptionId);
      expect(eose.subscriptionId, subscriptionId);
    });

    test('Eose.serialize', () {
      final String subscriptionId = generateRandomHex();
      final String serialized = '["EOSE","$subscriptionId"]';
      final eose = Eose(subscriptionId);
      expect(eose.serialize(), serialized);
    });

    test('Eose.deserialize', () {
      final String subscriptionId = generateRandomHex();
      final serialized = json.encode(["EOSE", subscriptionId]);
      final eose = Eose.deserialize(serialized);
      expect(eose.subscriptionId, subscriptionId);
    });
  });
}
