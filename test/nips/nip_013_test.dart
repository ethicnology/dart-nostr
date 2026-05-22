import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  test('countLeadingZeroes calculates correct difficulty for IDs', () {
    expect(
      Nip13.countLeadingZeroes(
        "000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d",
      ),
      equals(36),
    );
    expect(Nip13.countLeadingZeroes("002f"), equals(10));
    expect(Nip13.countLeadingZeroes("f0"), equals(0));
  });

  group('rust-nostr cross-implementation vectors', () {
    late List<dynamic> vectors;

    setUpAll(() {
      final data = json.decode(
          File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
      vectors = data['nip13']['leading_zeros'];
    });

    test('leading zero bits match rust-nostr', () {
      for (final v in vectors) {
        expect(
          Nip13.countLeadingZeroes(v['hex']),
          v['bits'],
          reason: 'Failed for ${v['hex']}',
        );
      }
    });
  });

  group('NIP-13 nonce tag + target', () {
    test('nonceTag formats as spec', () {
      expect(Nip13.nonceTag(42, 16), ['nonce', '42', '16']);
    });

    test('targetFromTag reads third element', () {
      expect(
        Nip13.targetFromTag([
          ['p', 'pk'],
          ['nonce', '7', '20'],
        ]),
        20,
      );
    });

    test('targetFromTag returns null on missing nonce tag', () {
      expect(
          Nip13.targetFromTag([
            ['p', 'pk']
          ]),
          isNull);
    });

    test('targetFromTag returns null when nonce has no target', () {
      expect(
        Nip13.targetFromTag([
          ['nonce', '5'],
        ]),
        isNull,
      );
    });
  });

  group('NIP-13 mining', () {
    const secretKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

    test('mines an event meeting a small difficulty', () {
      // Difficulty 8 takes <256 tries on average → trivial in tests.
      final event = Nip13.mine(
        difficulty: 8,
        kind: 1,
        content: 'mined',
        secretKey: secretKey,
      );

      expect(event, isNotNull);
      expect(Nip13.countLeadingZeroes(event!.id), greaterThanOrEqualTo(8));
      expect(Nip13.meetsTarget(event), isTrue);

      // Target is committed in the nonce tag (spec MUST for verifiers).
      final target = Nip13.targetFromTag(event.tags);
      expect(target, 8);
    });

    test('meetsTarget returns false without a nonce tag', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: 'no pow',
        secretKey: secretKey,
      );
      expect(Nip13.meetsTarget(event), isFalse);
    });

    test('mine returns null when budget exhausted', () {
      // Difficulty 24 would take ~16M tries; budget of 16 makes that
      // statistically impossible inside the loop.
      final event = Nip13.mine(
        difficulty: 24,
        kind: 1,
        content: 'budgeted',
        secretKey: secretKey,
        maxIterations: 16,
      );
      expect(event, isNull);
    });
  });
}
