import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
// Internal import, like in nip_044_test.dart: needed to hand-craft
// malformed TLV payloads that the public encoder now (correctly) rejects.
import 'package:nostr/src/nips/nip_019_utils.dart';
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

  group('rust-nostr cross-implementation vectors', () {
    late Map<String, dynamic> vectors;

    setUpAll(() {
      vectors = json.decode(
          File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
    });

    test('nsec encode/decode matches rust-nostr', () {
      final nip19 = vectors['nip19']['nsec'];
      final encoded =
          Nip19.encode(prefix: Nip19Prefix.nsec, data: nip19['hex']);
      expect(encoded, nip19['bech32']);
      final decoded = Nip19.decode(payload: nip19['bech32']);
      expect(decoded.data, nip19['hex']);
      expect(decoded.prefix, Nip19Prefix.nsec);
    });

    test('npub encode/decode matches rust-nostr', () {
      final nip19 = vectors['nip19']['npub'];
      final encoded =
          Nip19.encode(prefix: Nip19Prefix.npub, data: nip19['hex']);
      expect(encoded, nip19['bech32']);
      final decoded = Nip19.decode(payload: nip19['bech32']);
      expect(decoded.data, nip19['hex']);
      expect(decoded.prefix, Nip19Prefix.npub);
    });

    test('note encode/decode matches rust-nostr', () {
      final nip19 = vectors['nip19']['note'];
      final encoded =
          Nip19.encode(prefix: Nip19Prefix.note, data: nip19['hex']);
      expect(encoded, nip19['bech32']);
      final decoded = Nip19.decode(payload: nip19['bech32']);
      expect(decoded.data, nip19['hex']);
      expect(decoded.prefix, Nip19Prefix.note);
    });

    test('nprofile decode matches rust-nostr', () {
      final nip19 = vectors['nip19']['nprofile'];
      final decoded =
          Nip19.decodeShareableIdentifiers(payload: nip19['bech32']);
      expect(decoded.prefix, Nip19Prefix.nprofile);
      expect(decoded.data, nip19['pubkey']);
      expect(decoded.relays, nip19['relays'].cast<String>());
    });
  });

  test('encode nprofile', () {
    final y = Nip19.encodeShareableIdentifiers(
      prefix: Nip19Prefix.nprofile,
      data: '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d',
      relays: ['wss://r.x.com', 'wss://djbas.sadkb.com'],
    );

    expect(y,
        'nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p');
  });

  group('naddr UTF-8 round-trip', () {
    // NIP-19 leaves the byte encoding for naddr type-0 unspecified, but
    // rust-nostr (`identifier.as_bytes()` on a Rust String) and nostr-tools
    // (`utf8Encoder.encode(addr.identifier)`) both use UTF-8. These tests
    // confirm dart-nostr matches that choice so naddr round-trips across
    // implementations.

    const author =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    const kind = 30023;

    test('ASCII identifier round-trips', () {
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: 'my-article-slug',
        author: author,
        kind: kind,
      );
      final decoded = Nip19.decodeShareableIdentifiers(payload: encoded);
      expect(decoded.data, 'my-article-slug');
      expect(decoded.author, author);
      expect(decoded.kind, kind);
    });

    test('Latin-1 identifier (café) round-trips', () {
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: 'café',
        author: author,
        kind: kind,
      );
      final decoded = Nip19.decodeShareableIdentifiers(payload: encoded);
      expect(decoded.data, 'café');
    });

    test('CJK identifier round-trips', () {
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: '日本',
        author: author,
        kind: kind,
      );
      final decoded = Nip19.decodeShareableIdentifiers(payload: encoded);
      expect(decoded.data, '日本');
    });

    test('emoji identifier round-trips', () {
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: 'fire-🔥',
        author: author,
        kind: kind,
      );
      final decoded = Nip19.decodeShareableIdentifiers(payload: encoded);
      expect(decoded.data, 'fire-🔥');
    });

    test('empty identifier (normal replaceable event) round-trips', () {
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: '',
        author: author,
        kind: kind,
      );
      final decoded = Nip19.decodeShareableIdentifiers(payload: encoded);
      expect(decoded.data, '');
    });
  });

  group('Nip19Prefix.from', () {
    test('resolves a known prefix name', () {
      expect(Nip19Prefix.from('npub'), Nip19Prefix.npub);
      expect(Nip19Prefix.from('nevent'), Nip19Prefix.nevent);
    });

    test('is case-insensitive', () {
      expect(Nip19Prefix.from('NADDR'), Nip19Prefix.naddr);
      expect(Nip19Prefix.from('Note'), Nip19Prefix.note);
    });

    test('throws for unknown prefix names', () {
      expect(() => Nip19Prefix.from('nbunker'), throwsA(isA<ArgumentError>()));
    });
  });

  group('Nip19.decodeAny', () {
    test('dispatches to shareable-identifier decoder for nprofile', () {
      const author =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.nprofile,
        data: author,
        relays: ['wss://relay.example'],
      );
      final decoded = Nip19.decodeAny(payload: encoded);
      expect(decoded.prefix, Nip19Prefix.nprofile);
      expect(decoded.data, author);
      expect(decoded.relays, ['wss://relay.example']);
    });

    test('handles plain npub / note payloads', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final encoded = Nip19.encode(prefix: Nip19Prefix.npub, data: pubkey);
      final decoded = Nip19.decodeAny(payload: encoded);
      expect(decoded.prefix, Nip19Prefix.npub);
      expect(decoded.data, pubkey);
      expect(decoded.relays, isEmpty);
      expect(decoded.author, isNull);
      expect(decoded.kind, isNull);
    });

    test('handles naddr with author + kind', () {
      const author =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final encoded = Nip19.encodeShareableIdentifiers(
        prefix: Nip19Prefix.naddr,
        data: 'my-article',
        author: author,
        kind: 30023,
      );
      final decoded = Nip19.decodeAny(payload: encoded);
      expect(decoded.prefix, Nip19Prefix.naddr);
      expect(decoded.data, 'my-article');
      expect(decoded.author, author);
      expect(decoded.kind, 30023);
    });
  });

  group('Adversarial decode inputs', () {
    test('decode throws on garbage non-bech32 string', () {
      expect(
        () => Bech32Entity.decode(payload: 'this is not bech32'),
        throwsA(isA<Exception>()),
      );
    });

    test('decode throws on empty string', () {
      expect(
        () => Bech32Entity.decode(payload: ''),
        throwsA(isA<Exception>()),
      );
    });

    test(
        'decodeShareableIdentifiers wraps inner errors in DeserializationException',
        () {
      // Passing an npub (no TLV body) to the TLV decoder should fail
      // gracefully with DeserializationException, not leak a RangeError.
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final npub = Bech32Entity.encode(prefix: Nip19Prefix.npub, data: pubkey);
      expect(
        () => Bech32Entity.decodeShareableIdentifiers(payload: npub),
        throwsA(isA<DeserializationException>()),
      );
    });

    test(
        'encode rejects shareable-identifier prefixes (must use shareable encoder)',
        () {
      expect(
        () => Bech32Entity.encode(
          prefix: Nip19Prefix.nprofile,
          data: '00' * 32,
        ),
        throwsA(isA<WrongDecodeMethodException>()),
      );
    });

    test('encodeShareableIdentifiers rejects non-shareable prefixes', () {
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.npub,
          data: '00' * 32,
        ),
        throwsA(isA<WrongPrefixException>()),
      );
    });

    test('encodeShareableIdentifiers naddr requires author', () {
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.naddr,
          data: 'slug',
          kind: 30023,
        ),
        throwsA(isA<MissingTlvException>()),
      );
    });

    test('encodeShareableIdentifiers naddr requires kind', () {
      const author =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.naddr,
          data: 'slug',
          author: author,
        ),
        throwsA(isA<MissingTlvException>()),
      );
    });

    test('decode enforces the 5000-char soft cap', () {
      // Build a payload over the cap by stuffing many long relay URLs
      // (relays in TLV are length-prefixed by 1 byte, so cap at 255).
      const author =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final manyRelays = List<String>.generate(
        50,
        (i) => 'wss://relay-${'x' * 200}-$i.example.com',
      );
      expect(
        () => Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.nprofile,
          data: author,
          relays: manyRelays,
        ),
        throwsA(isA<Exception>()), // either size cap or bech32 limit
      );
    });

    group('TLV values must fit the 1-byte length prefix', () {
      // Regression: a value above 255 bytes used to overflow the length
      // byte into a second one, silently corrupting the TLV stream (the
      // failure surfaced later as a confusing bech32 error).
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

      test('relay URL above 255 bytes throws InvalidArgumentException', () {
        expect(
          () => Bech32Entity.encodeShareableIdentifiers(
            prefix: Nip19Prefix.nprofile,
            data: pubkey,
            relays: ['wss://${'x' * 300}.com'],
          ),
          throwsA(isA<InvalidArgumentException>()),
        );
      });

      test('naddr d-tag above 255 bytes throws InvalidArgumentException', () {
        expect(
          () => Bech32Entity.encodeShareableIdentifiers(
            prefix: Nip19Prefix.naddr,
            data: 'd' * 300,
            author: pubkey,
            kind: 30023,
          ),
          throwsA(isA<InvalidArgumentException>()),
        );
      });

      test('relay URL of exactly 255 bytes round-trips (boundary)', () {
        final relay = 'wss://${'x' * 245}.com'; // 6 + 245 + 4 = 255 chars
        expect(relay.length, 255);
        final encoded = Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.nprofile,
          data: pubkey,
          relays: [relay],
        );
        final decoded =
            Bech32Entity.decodeShareableIdentifiers(payload: encoded);
        expect(decoded.relays, [relay]);
      });

      test('nprofile with a short data payload is rejected', () {
        expect(
          () => Bech32Entity.encodeShareableIdentifiers(
            prefix: Nip19Prefix.nprofile,
            data: 'abcd',
          ),
          throwsA(isA<InvalidArgumentException>()),
        );
      });
    });

    group('decode-side TLV validation (adversarial hand-crafted payloads)',
        () {
      // These payloads are well-formed bech32 (valid checksum) carrying
      // malformed TLV values — the kind of input a broken or hostile
      // sender can produce. rust-nostr rejects them via its typed fields.
      String craftNaddr(String tlvHex) =>
          bech32Encode(Nip19Prefix.naddr, tlvHex);

      test('naddr with a 2-byte author is rejected', () {
        final naddr = craftNaddr(
          '00' '04' '736c7567' // type 0, "slug"
          '02' '02' 'abcd' // type 2, 2-byte author — malformed
          '03' '04' '00007593', // type 3, kind 30099
        );
        expect(
          () => Bech32Entity.decodeShareableIdentifiers(payload: naddr),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('naddr with a 5-byte kind is rejected (no silent truncation)',
          () {
        final naddr = craftNaddr(
          '00' '04' '736c7567'
          '02' '20' '${'ab' * 32}' // valid 32-byte author
          '03' '05' '0000007593', // type 3, 5-byte kind — malformed
        );
        expect(
          () => Bech32Entity.decodeShareableIdentifiers(payload: naddr),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('nprofile with a 2-byte pubkey is rejected', () {
        final nprofile = bech32Encode(
          Nip19Prefix.nprofile,
          '00' '02' 'abcd',
        );
        expect(
          () => Bech32Entity.decodeShareableIdentifiers(payload: nprofile),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('nevent with a 31-byte event id is rejected', () {
        final nevent = bech32Encode(
          Nip19Prefix.nevent,
          '00' '1f' '${'ab' * 31}',
        );
        expect(
          () => Bech32Entity.decodeShareableIdentifiers(payload: nevent),
          throwsA(isA<DeserializationException>()),
        );
      });

      test('a spec-shaped naddr still decodes (no false positive)', () {
        const author =
            '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
        final encoded = Bech32Entity.encodeShareableIdentifiers(
          prefix: Nip19Prefix.naddr,
          data: 'slug',
          author: author,
          kind: 30023,
          relays: const ['wss://relay.example.com'],
        );
        final decoded =
            Bech32Entity.decodeShareableIdentifiers(payload: encoded);
        expect(decoded.data, 'slug');
        expect(decoded.author, author);
        expect(decoded.kind, 30023);
        expect(decoded.relays, ['wss://relay.example.com']);
      });
    });
  });
}
