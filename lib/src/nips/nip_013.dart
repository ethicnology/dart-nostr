import 'dart:math';

import 'package:nostr/nostr.dart';

/// Proof of work — [NIP-13](https://github.com/nostr-protocol/nips/blob/master/13.md)
///
/// NIP-13 introduces Proof of Work (PoW) for nostr notes to deter spam.
/// Difficulty is the number of leading zero bits in the event id. A
/// `nonce` tag commits to a target so verifiers can reject events whose
/// committed difficulty is below their policy.
///
/// Example tag: `["nonce", "<nonce-value>", "<target-difficulty>"]`
class ProofOfWork {
  /// Calculates the number of leading zero bits in a hexadecimal string.
  ///
  /// ```dart
  /// final difficulty = ProofOfWork.countLeadingZeroes(
  ///   "000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d",
  /// );
  /// // difficulty == 36
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

  /// Reads the committed target difficulty from a `nonce` tag, or `null`
  /// if absent or malformed.
  ///
  /// Per spec the third tag element is the target — it lets verifiers
  /// reject events whose author "got lucky" but didn't actually commit
  /// to a difficulty.
  static int? targetFromTag(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.length >= 3 && tag[0] == 'nonce') {
        return int.tryParse(tag[2]);
      }
    }
    return null;
  }

  /// Returns true if [event]'s actual difficulty meets or exceeds
  /// the committed target in its `nonce` tag.
  ///
  /// Returns false when the event has no `nonce` tag, when the tag is
  /// malformed, or when the committed target is higher than the id's
  /// leading zero count.
  static bool meetsTarget(Event event) {
    final target = targetFromTag(event.tags);
    if (target == null) return false;
    return countLeadingZeroes(event.id) >= target;
  }

  /// Builds a `nonce` tag with the given [nonce] value and [target] bits.
  static List<String> nonceTag(int nonce, int target) {
    return ['nonce', nonce.toString(), target.toString()];
  }

  /// Mines an event by iterating a `nonce` tag until the resulting event
  /// id has at least [difficulty] leading zero bits.
  ///
  /// [tags] are the event's other tags; a `nonce` tag is appended (or
  /// replaced) at each iteration. [maxIterations] caps the work — if no
  /// nonce yields the required difficulty within that budget, returns
  /// `null` rather than spinning forever.
  ///
  /// `created_at` is also bumped between iterations so consecutive mines
  /// of the same template don't collide on the same starting hash. If
  /// [createdAt] is supplied, mining starts there.
  ///
  /// This is a CPU-bound loop — for high difficulties on production
  /// devices, run it in an isolate.
  static Event? mine({
    required int difficulty,
    required int kind,
    required String content,
    required String secretKey,
    List<List<String>> tags = const [],
    int? createdAt,
    int maxIterations = 1 << 22, // ~4M attempts ≈ seconds on a laptop
  }) {
    if (difficulty < 0) {
      throw InvalidArgumentException('difficulty', 'must be non-negative');
    }
    var ts = createdAt ?? currentUnixTimestampSeconds();

    for (int nonce = 0; nonce < maxIterations; nonce++) {
      final candidateTags = <List<String>>[
        ...tags,
        nonceTag(nonce, difficulty),
      ];
      final event = Event.from(
        kind: kind,
        tags: candidateTags,
        content: content,
        secretKey: secretKey,
        createdAt: ts,
      );
      if (countLeadingZeroes(event.id) >= difficulty) {
        return event;
      }
      // Bump created_at occasionally to broaden the search space cheaply.
      if (nonce > 0 && nonce % 100000 == 0) ts++;
    }
    return null;
  }
}

typedef Nip13 = ProofOfWork;
