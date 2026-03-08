import 'dart:math';

/// Proof of Work (NIP-13)
///
/// NIP-13 introduces Proof of Work (PoW) for nostr notes to deter spam. PoW is validated by counting the number of leading zero bits in a note's ID (difficulty).
///
/// Example:
/// An ID `000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d` has a difficulty of `36` with 36 leading zero bits.
///
/// Mining involves generating an ID with a desired difficulty by iteratively modifying a `nonce` tag.
class Nip13 {
  /// Calculates the number of leading zero bits in a hexadecimal string.
  ///
  /// ```dart
  /// int difficulty = Nip13.countLeadingZeroes("000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d");
  /// print(difficulty); // 36
  /// ```
  static int countLeadingZeroes(String hex) {
    int count = 0;
    for (int i = 0; i < hex.length; i++) {
      final int nibble = int.parse(hex[i], radix: 16);
      if (nibble == 0) {
        count += 4;
      } else {
        count += 4 - min(4, nibble.bitLength);
        break;
      }
    }
    return count;
  }
}

typedef ProofOfWork = Nip13;
