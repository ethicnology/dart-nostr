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
}
