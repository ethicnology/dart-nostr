import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
// Internal import: hand-crafts a TLV payload the public encoder refuses
// to build, to exercise the decode-side validation NIP-21 relies on.
import 'package:nostr/src/nips/nip_019_utils.dart';
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
        () => Nip21.encode(
            'nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp'),
        throwsA(isA<Exception>()),
      );
    });

    test('decode rejects malformed bech32 behind an allowed prefix', () {
      // Regression: a prefix match alone used to be enough — any garbage
      // starting with "npub" was accepted. rust-nostr validates the full
      // NIP-19 payload (checksum, charset, length).
      expect(
        () => Nip21.decode('nostr:npub1thisisnotvalidbech32'),
        throwsA(isA<NostrException>()),
      );
      expect(
        () => Nip21.encode('npub1thisisnotvalidbech32'),
        throwsA(isA<NostrException>()),
      );
      // Valid bech32 but wrong payload size (2 bytes instead of 32).
      expect(
        () => Nip21.decode('nostr:npub140xserft56'),
        throwsA(isA<NostrException>()),
      );
    });

    test('rejects an nprofile carrying no public key', () {
      // Well-formed bech32 and a valid TLV stream, but no type-0 entry:
      // the URI points at no profile at all. The prefix-scoped NIP-19
      // validation is what makes this reachable from here.
      final nprofile = bech32Encode(
        Nip19Prefix.nprofile,
        '01' '0d' '7773733a2f2f722e782e636f6d', // relay only, "wss://r.x.com"
      );
      expect(
        () => Nip21.encode(nprofile),
        throwsA(isA<NostrException>()),
      );
      expect(
        () => Nip21.decode('nostr:$nprofile'),
        throwsA(isA<NostrException>()),
      );
    });
  });

  group('rust-nostr cross-implementation vectors', () {
    late Map<String, dynamic> vectors;

    setUpAll(() {
      final data = json.decode(
          File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
      vectors = data['nip21'];
    });

    test('valid URIs decode correctly', () {
      for (final v in vectors['valid']) {
        expect(Nip21.decode(v['uri']), v['decoded']);
      }
    });

    test('nsec URI is rejected by encode', () {
      final nsecUri = vectors['invalid_nsec'] as String;
      final nsecPayload = nsecUri.replaceFirst('nostr:', '');
      expect(() => Nip21.encode(nsecPayload), throwsA(isA<NostrException>()));
    });
  });
}
