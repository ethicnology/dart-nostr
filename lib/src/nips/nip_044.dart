import 'dart:convert';
import 'dart:typed_data';
import 'package:elliptic/ecdh.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr/src/nips/nip_044_utils.dart';

/// Versioned encryption — [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md)
///
/// Uses secp256k1 ECDH + HKDF-extract("nip44-v2") as conversation key,
/// then ChaCha20 + HMAC-SHA256 for per-message encryption.
///
/// This format MUST be used in the context of a signed event (NIP-01).
///
/// Implementation notes:
/// - Only the original 2-byte length prefix is supported (plaintexts of
///   1..65535 bytes), matching rust-nostr and the official test vectors.
///   The 6-byte extended prefix for ≥ 65536-byte plaintexts from the
///   latest spec text is deliberately not implemented; such payloads are
///   rejected at the padding check.
/// - The ECDH scalar multiplication (package:elliptic) is not
///   constant-time, unlike libsecp256k1. This is an inherent pure-Dart
///   limitation to be aware of for strong threat models.
class Encryption {
  /// Encrypts [plaintext] from sender to recipient using NIP-44 v2.
  ///
  /// [plaintext] must be 1..65535 bytes once UTF-8 encoded (the 2-byte
  /// length prefix range; empty and longer inputs are rejected with
  /// [CryptoException] `invalidPlaintextLength`).
  /// [senderSecretKey] is the sender's hex-encoded secret key.
  /// [recipientPubkey] is the recipient's hex-encoded public key.
  /// [customNonce] is an optional 32-byte nonce (random if omitted).
  /// [conversationKey] is an optional pre-computed key (for testing with spec vectors).
  ///
  /// Returns a base64-encoded payload.
  static Future<String> encrypt({
    required String plaintext,
    required String senderSecretKey,
    required String recipientPubkey,
    List<int>? customNonce,
    // Optional pre-computed conversation key (for testing with spec vectors).
    // When provided, the ECDH + HKDF derivation steps are skipped entirely.
    List<int>? conversationKey,
  }) async {
    // Derive conversation key unless a pre-computed one is provided (test hook)
    final convKey = conversationKey ??
        deriveConversationKey(
          sharedSecret: computeSharedSecret(
            secretKeyHex: senderSecretKey,
            publicKeyHex: recipientPubkey,
          ),
        );

    final nonce = customNonce ?? Uint8List.fromList(generateRandomBytes(32));

    final keys = deriveMessageKeys(convKey, nonce);
    final chachaKey = keys['chachaKey']!;
    final chachaNonce = keys['chachaNonce']!;
    final hmacKey = keys['hmacKey']!;

    final paddedPlaintext = pad(utf8.encode(plaintext));
    final ciphertext = chacha20(chachaKey, chachaNonce, paddedPlaintext, true);
    final mac = calculateMac(hmacKey, nonce, ciphertext);

    return constructPayload(nonce, ciphertext, mac);
  }

  /// Decrypts a NIP-44 v2 [payload] from sender to recipient.
  ///
  /// [recipientSecretKey] is the recipient's hex-encoded secret key.
  /// [senderPubkey] is the sender's hex-encoded public key.
  /// [conversationKey] is an optional pre-computed key (for testing with spec vectors).
  ///
  /// Returns the decrypted plaintext string.
  static Future<String> decrypt({
    required String payload,
    required String recipientSecretKey,
    required String senderPubkey,
    // Optional pre-computed conversation key (for testing with spec vectors).
    // When provided, the ECDH + HKDF derivation steps are skipped entirely.
    List<int>? conversationKey,
  }) async {
    // Derive conversation key unless a pre-computed one is provided (test hook)
    final convKey = conversationKey ??
        deriveConversationKey(
          sharedSecret: computeSharedSecret(
            secretKeyHex: recipientSecretKey,
            publicKeyHex: senderPubkey,
          ),
        );

    final parsed = parsePayload(payload);
    final nonce = parsed['nonce'];
    final ciphertext = parsed['ciphertext'];
    final mac = parsed['mac'];

    final keys = deriveMessageKeys(convKey, nonce);
    final chachaKey = keys['chachaKey']!;
    final chachaNonce = keys['chachaNonce']!;
    final hmacKey = keys['hmacKey']!;

    verifyMac(hmacKey, nonce, ciphertext, mac);

    final paddedPlaintext = chacha20(chachaKey, chachaNonce, ciphertext, false);
    final plaintextBytes = unpad(paddedPlaintext);

    try {
      return utf8.decode(plaintextBytes);
    } on FormatException {
      // The spec requires UTF-8 plaintext. Surface a CryptoException
      // instead of a raw FormatException so the NostrException contract
      // holds. The offending bytes are not echoed (potentially sensitive).
      throw const CryptoException(
        'Decrypted plaintext is not valid UTF-8',
        CryptoErrorCode.invalidUtf8,
      );
    }
  }

  /// Computes the ECDH shared secret between a secret key and a public key.
  ///
  /// [secretKeyHex] is the hex-encoded secret key. Per NIP-44 (which defers
  /// to BIP-340) it MUST be a scalar in `[1, secp256k1.n - 1]` — out-of-range
  /// scalars (0, n, > n) are rejected with [InvalidKeyException] instead of
  /// silently producing a garbage shared point.
  /// [publicKeyHex] is the hex-encoded public key (x-only 32-byte, compressed
  /// 33-byte, or uncompressed 65-byte form). It MUST decode to a valid
  /// on-curve secp256k1 point.
  ///
  /// Returns the unhashed 32-byte x coordinate of the shared point.
  ///
  /// Throws [InvalidKeyException] for an out-of-range secret key and
  /// [CryptoException] for a malformed or off-curve public key. Errors from
  /// the underlying EC backend are normalized so callers only ever see
  /// [NostrException] subclasses — never a raw `EllipticException`, a
  /// thrown `String`, or a `FormatException`.
  static List<int> computeSharedSecret({
    required String secretKeyHex,
    required String publicKeyHex,
  }) {
    Schnorr.assertValidSecretKey(secretKeyHex);
    final ec = getS256();
    try {
      final secretKey = PrivateKey.fromHex(ec, secretKeyHex);
      final publicKey = PublicKey.fromHex(ec, checkPublicKey(publicKeyHex));
      return computeSecret(secretKey, publicKey);
    } on NostrException {
      rethrow;
    } on Object {
      // package:elliptic reports failures by throwing an EllipticException,
      // a plain String, or a FormatException (BigInt.parse) depending on
      // the code path. Normalize them all into the library's error
      // contract. The underlying messages are deliberately not echoed:
      // they can embed the offending key material.
      throw const CryptoException(
        'Invalid Public Key',
        CryptoErrorCode.invalidPublicKey,
      );
    }
  }

  /// Derives the NIP-44 v2 conversation key from a shared secret.
  ///
  /// Uses HKDF-extract with salt `"nip44-v2"`.
  static List<int> deriveConversationKey({required List<int> sharedSecret}) {
    return hkdfExtract(
      ikm: sharedSecret,
      salt: Uint8List.fromList(utf8.encode('nip44-v2')),
    );
  }
}

typedef Nip44 = Encryption;
