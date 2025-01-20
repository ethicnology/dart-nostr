import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

/// Unit Tests for Nip13
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
}
