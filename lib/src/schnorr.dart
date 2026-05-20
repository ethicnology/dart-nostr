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

  /// Derives the BIP-340 x-only public key (32-byte hex) from a 32-byte
  /// hex-encoded [secretKey].
  ///
  /// Throws [InvalidKeyException] if [secretKey] is not 32-byte hex.
  static String derivePublicKey(String secretKey) {
    _assertHexBytes(secretKey, 32, 'secretKey');
    return bip340.getPublicKey(secretKey);
  }

  /// Signs a 32-byte hex-encoded [message] with the given [secretKey].
  ///
  /// An optional 32-byte hex-encoded [aux] random value can be supplied;
  /// if omitted, one is generated automatically.
  ///
  /// Throws an [InvalidKeyException] if [secretKey], [message], or [aux]
  /// is not a valid 32-byte hex string.
  static String sign({
    required String secretKey,
    required String message,
    String? aux,
  }) {
    aux ??= generateRandomHex();
    _assertHexBytes(secretKey, 32, 'secretKey');
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
