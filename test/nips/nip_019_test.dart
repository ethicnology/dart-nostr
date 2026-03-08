import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip019', () {
    test('encode', () {
      final nsec = Nip19.encode(
          prefix: Nip19Prefix.nsec,
          data:
              "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12");
      final npub = Nip19.encode(
          prefix: Nip19Prefix.npub,
          data:
              "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d");
      final note = Nip19.encode(
          prefix: Nip19Prefix.note,
          data:
              "2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1");

      expect(nsec,
          'nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp');
      expect(npub,
          'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6');
      expect(note,
          'note1yuuuenwrl22r44z8x78zxnh3xfd8dupr595mfqakl6x2k3a8j0ssj0w27g');
    });

    test('decode', () {
      final privkey = Nip19.decode(
          payload:
              "nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp");
      final pubkey = Nip19.decode(
          payload:
              "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6");
      final note = Nip19.decode(
          payload:
              "note1yuuuenwrl22r44z8x78zxnh3xfd8dupr595mfqakl6x2k3a8j0ssj0w27g");

      expect(privkey.prefix, Nip19Prefix.nsec);
      expect(privkey.data,
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12');
      expect(pubkey.prefix, Nip19Prefix.npub);
      expect(pubkey.data,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d');
      expect(note.prefix, Nip19Prefix.note);
      expect(note.data,
          '2739cccdc3fa943ad447378e234ef1325a76f023a169b483b6fe8cab47a793e1');
    });
  });

  test('decode nprofile', () {
    final x = Nip19.decodeShareableIdentifiers(
        payload:
            "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p");

    expect(x.prefix, Nip19Prefix.nprofile);
    expect(x.data,
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d');
    expect(x.relays[0], 'wss://r.x.com');
    expect(x.relays[1], 'wss://djbas.sadkb.com');
  });

  test('encode nprofile', () {
    final y = Nip19.encodeShareableIdentifiers(
      prefix: Nip19Prefix.nprofile,
      data:
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
      relays: ['wss://r.x.com', 'wss://djbas.sadkb.com'],
    );

    expect(y,
        'nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p');
  });
}
