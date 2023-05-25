import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip019', () {
    test('encode', () {
      String encodedPrivkey = Nip19.encodePrivkey(
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12");
      String encodedPubkey = Nip19.encodePubkey(
          "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d");
      String encodedNote = Nip19.encodeNote(
          "2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1");

      expect(encodedPrivkey,
          'nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp');
      expect(encodedPubkey,
          'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6');
      expect(encodedNote,
          'note1yuuuenwrl22r44z8x78zxnh3xfd8dupr595mfqakl6x2k3a8j0ssj0w27g');
    });

    test('decode', () {
      String privkey = Nip19.decodePrivkey(
          "nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp");
      String pubkey = Nip19.decodePubkey(
          "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6");
      String note = Nip19.decodeNote(
          "note1yuuuenwrl22r44z8x78zxnh3xfd8dupr595mfqakl6x2k3a8j0ssj0w27g");

      expect(privkey,
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12');
      expect(pubkey,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d');
      expect(note,
          '2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1');
    });
  });
}
