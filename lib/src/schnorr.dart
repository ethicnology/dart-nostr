import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:nostr/src/error.dart';
import 'package:nostr/src/utils.dart';

/// Provides Schnorr signature operations (BIP-340) for the Nostr protocol.
///
/// This class wraps the `bip340` package so callers do not need to add it
/// as a direct dependency, and so internal callers (Event, Keys) get the
/// consistent length validation below.
class Schnorr {
  /// The secp256k1 group order `n` — secret keys must be scalars in
  /// `[1, n - 1]` per BIP-340.
  static final BigInt _groupOrder = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  /// Decodes [value] as hex and asserts a [expectedBytes] length. Throws
  /// [InvalidKeyException] for both non-hex inputs and wrong lengths so
  /// callers only have to catch one type.
  static void _assertHexBytes(String value, int expectedBytes, String label) {
    try {
      if (hex.decode(value).length != expectedBytes) {
        throw InvalidKeyException(
          '$label must be $expectedBytes-bytes hex encoded',
        );
      }
    } on InvalidKeyException {
      rethrow;
    } on FormatException {
      throw InvalidKeyException(
        '$label must be $expectedBytes-bytes hex encoded',
      );
    }
  }

  /// Asserts that [secretKey] is a valid secp256k1 secret key: 32-byte hex
  /// encoding a scalar in `[1, n - 1]` (BIP-340 / NIP-44 requirement).
  ///
  /// Throws [InvalidKeyException] otherwise. Every entrypoint that consumes
  /// a secret key (`derivePublicKey`, `sign`, NIP-44 ECDH) routes through
  /// this so out-of-range scalars (0, n, > n) can never produce a
  /// non-canonical public key, an invalid signature, or a garbage ECDH
  /// shared point.
  static void assertValidSecretKey(String secretKey) {
    _assertHexBytes(secretKey, 32, 'secretKey');
    final d = BigInt.parse(secretKey, radix: 16);
    if (d < BigInt.one || d >= _groupOrder) {
      throw const InvalidKeyException(
        'secretKey must be a scalar in range [1, secp256k1.n - 1]',
      );
    }
  }

  /// Derives the BIP-340 x-only public key (32-byte hex) from a 32-byte
  /// hex-encoded [secretKey].
  ///
  /// Throws [InvalidKeyException] if [secretKey] is not 32-byte hex or is
  /// outside the valid scalar range `[1, n - 1]`.
  static String derivePublicKey(String secretKey) {
    assertValidSecretKey(secretKey);
    return bip340.getPublicKey(secretKey);
  }

  /// Signs a 32-byte hex-encoded [message] with the given [secretKey].
  ///
  /// An optional 32-byte hex-encoded [aux] random value can be supplied;
  /// if omitted, one is generated automatically.
  ///
  /// Throws an [InvalidKeyException] if [secretKey], [message], or [aux]
  /// is not a valid 32-byte hex string, or if [secretKey] is outside the
  /// valid scalar range `[1, n - 1]`.
  static String sign({
    required String secretKey,
    required String message,
    String? aux,
  }) {
    aux ??= generateRandomHex();
    assertValidSecretKey(secretKey);
    _assertHexBytes(message, 32, 'message');
    _assertHexBytes(aux, 32, 'aux');
    return bip340.sign(secretKey, message, aux);
  }

  /// Verifies that [signature] is a valid Schnorr signature for [message]
  /// created by [publicKey].
  ///
  /// Returns `true` if the signature is valid, `false` otherwise.
  ///
  /// Throws an [InvalidKeyException] if any of the inputs have an
  /// incorrect byte length or are not valid hex.
  static bool verify({
    required String publicKey,
    required String message,
    required String signature,
  }) {
    _assertHexBytes(publicKey, 32, 'publicKey');
    _assertHexBytes(message, 32, 'message');
    _assertHexBytes(signature, 64, 'signature');
    return bip340.verify(publicKey, message, signature);
  }
}
