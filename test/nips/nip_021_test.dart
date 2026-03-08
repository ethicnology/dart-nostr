import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Nip21 URI Tests', () {
    test('Parse valid npub URI', () {
      expect(
          Nip21.decode(
              'nostr:npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9'),
          equals(
              'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9'));
    });

    test('Parse valid nprofile URI', () {
      expect(
          Nip21.decode(
              'nostr:nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p'),
          equals(
              'nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p'));
    });

    test('Generate npub URI', () {
      expect(
          Nip21.encode(
              'npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9'),
          equals(
              'nostr:npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9'));
    });

    test('Invalid Nostr URI parsing', () {
      expect(() => Nip21.decode('noprefix'), throwsA(isA<Exception>()));
    });

    test('encode rejects nsec identifiers', () {
      expect(
        () => Nip21.encode('nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
