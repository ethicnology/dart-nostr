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
class Encryption {
  /// Encrypts [plaintext] from sender to recipient using NIP-44 v2.
  ///
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

    return utf8.decode(plaintextBytes);
  }

  /// Computes the ECDH shared secret between a secret key and a public key.
  ///
  /// [secretKeyHex] is the hex-encoded secret key.
  /// [publicKeyHex] is the hex-encoded public key.
  ///
  /// Returns the shared secret as a list of bytes.
  static List<int> computeSharedSecret({
    required String secretKeyHex,
    required String publicKeyHex,
  }) {
    final ec = getS256();
    final secretKey = PrivateKey.fromHex(ec, secretKeyHex);
    final publicKey = PublicKey.fromHex(ec, checkPublicKey(publicKeyHex));
    return computeSecret(secretKey, publicKey);
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
