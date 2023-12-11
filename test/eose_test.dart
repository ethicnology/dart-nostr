import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Eose', () {
    test('Constructor', () {
      String subscriptionId = generate64RandomHexChars();
      var eose = Eose(subscriptionId);
      expect(eose.subscriptionId, subscriptionId);
    });

    test('Eose.serialize', () {
      String subscriptionId = generate64RandomHexChars();
      String serialized = '["EOSE","$subscriptionId"]';
      var eose = Eose(subscriptionId);
      expect(eose.serialize(), serialized);
    });

    test('Eose.deserialize', () {
      String subscriptionId = generate64RandomHexChars();
      var serialized = ["EOSE", subscriptionId];
      var eose = Eose.deserialize(serialized);
      expect(eose.subscriptionId, subscriptionId);
    });
  });
}
