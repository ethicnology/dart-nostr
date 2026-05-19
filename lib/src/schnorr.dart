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
  /// Derives the BIP-340 x-only public key (32-byte hex) from a 32-byte
  /// hex-encoded [secretKey].
  ///
  /// Throws [InvalidKeyException] if [secretKey] is not 32-byte hex.
  static String derivePublicKey(String secretKey) {
    if (hex.decode(secretKey).length != 32) {
      throw const InvalidKeyException(
        'secretKey must be 32-bytes hex encoded',
      );
    }
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

    if (hex.decode(secretKey).length != 32) {
      throw const InvalidKeyException("secretKey must be 32-bytes hex encoded");
    }
    if (hex.decode(message).length != 32) {
      throw const InvalidKeyException(
        "message must be 32-bytes hex encoded (a hash of the actual message)",
      );
    }
    if (hex.decode(aux).length != 32) {
      throw const InvalidKeyException("aux must be 32-bytes hex encoded");
    }

    return bip340.sign(secretKey, message, aux);
  }

  /// Verifies that [signature] is a valid Schnorr signature for [message]
  /// created by [publicKey].
  ///
  /// Returns `true` if the signature is valid, `false` otherwise.
  ///
  /// Throws an [InvalidKeyException] if any of the inputs have an
  /// incorrect byte length.
  static bool verify({
    required String publicKey,
    required String message,
    required String signature,
  }) {
    if (hex.decode(publicKey).length != 32) {
      throw const InvalidKeyException("publicKey must be 32-bytes hex encoded");
    }
    if (hex.decode(message).length != 32) {
      throw const InvalidKeyException(
        "message must be 32-bytes hex encoded (a hash of the actual message)",
      );
    }
    if (hex.decode(signature).length != 64) {
      throw const InvalidKeyException("signature must be 64-bytes hex encoded");
    }
    return bip340.verify(publicKey, message, signature);
  }
}
