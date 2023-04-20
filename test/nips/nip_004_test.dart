import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

String bobPubkey =
  "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1";
String alicePubkey =
  "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181";
String bobPrivkey =
  "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
String alicePrivkey =
  "773dc29ff81f7680eeca5d530f528e8c572979b46abc8bfd1586b73a6a98ab4d";

void main() {
  group('EncryptedDirectMessage', () {
    test('EncryptedDirectMessage.quick', () {
      // DM from bob to alice
      String plaintext = "vi veri universum vivus vici";
      List<List<String>> tags = [
        ['p', alicePubkey]
      ];

      EncryptedDirectMessage event =
        EncryptedDirectMessage.quick(bobPrivkey, alicePubkey, plaintext);

      expect(event.receiverPubkey, alicePubkey);
      expect(event.getPlaintext(alicePrivkey), plaintext);
      expect(event.pubkey, bobPubkey);
      expect(event.kind, 4);
      expect(event.tags, tags);
      expect(event.subscriptionId, null);
    });

    test('EncryptedDirectMessage Receive', () {
      String receivedEvent =
        '["EVENT", "181555e0fec2139d27ac80a5a46801415394e61d67be7f626631760dc5997bc0", {"id": "2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1", "pubkey": "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181", "created_at": 1680475069, "kind": 4, "tags": [["p", "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1"]], "content": "hH1HlQWY3dz7IzJlgnEgW1WNtA0KlvGgo/OC4mep/R4I6PMqJuvZ35j4OFHkMvqb?iv=jbkXPH2esn5DIP3BodpsTQ==", "sig": "ba2d80d8be4612e8438447d38373e9b014b28172d49b7b6afeff462bc25bd4edc69c6e2c145dde052de54f47f4e36d74151fad3d08d21e3cad9563edc64adcca"}]';

      Message m = Message.deserialize(receivedEvent);
      Event event = m.message;
      expect(event.id,
        "2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1");
      expect(event.pubkey, alicePubkey);
      expect(event.createdAt, 1680475069);
      expect(event.kind, 4);
      expect(event.tags, [
        ["p", bobPubkey]
      ]);
      String content = (event as EncryptedDirectMessage).getPlaintext(bobPrivkey);
      expect(content, "Secret message from alice to bob!");
      expect(event.sig,
        "ba2d80d8be4612e8438447d38373e9b014b28172d49b7b6afeff462bc25bd4edc69c6e2c145dde052de54f47f4e36d74151fad3d08d21e3cad9563edc64adcca");
      expect(event.subscriptionId,
        "181555e0fec2139d27ac80a5a46801415394e61d67be7f626631760dc5997bc0");
    });
  });
}
