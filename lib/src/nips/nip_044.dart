import 'dart:convert';
import 'dart:typed_data';
import 'package:elliptic/ecdh.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nostr/nostr.dart';

/// Versioned keypair-based encryption (NIP-44 v2).
///
/// Uses secp256k1 ECDH + HKDF-extract("nip44-v2") as conversation key,
/// then ChaCha20 + HMAC-SHA256 for per-message encryption.
///
/// This format MUST be used in the context of a signed event (NIP-01).
class Nip44 {
  static Future<String> encrypt({
    required String plaintext,
    required String senderSecretKey,
    required String recipientPublicKey,
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
            publicKeyHex: recipientPublicKey,
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

  static Future<String> decrypt({
    required String payload,
    required String recipientSecretKey,
    required String senderPublicKey,
    // Optional pre-computed conversation key (for testing with spec vectors).
    // When provided, the ECDH + HKDF derivation steps are skipped entirely.
    List<int>? conversationKey,
  }) async {
    // Derive conversation key unless a pre-computed one is provided (test hook)
    final convKey = conversationKey ??
        deriveConversationKey(
          sharedSecret: computeSharedSecret(
            secretKeyHex: recipientSecretKey,
            publicKeyHex: senderPublicKey,
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

  static List<int> computeSharedSecret({
    required String secretKeyHex,
    required String publicKeyHex,
  }) {
    final ec = getS256();
    final secretKey = PrivateKey.fromHex(ec, secretKeyHex);
    final publicKey = PublicKey.fromHex(ec, checkPublicKey(publicKeyHex));
    return computeSecret(secretKey, publicKey);
  }

  static List<int> deriveConversationKey({required List<int> sharedSecret}) {
    return hkdfExtract(
      ikm: sharedSecret,
      salt: Uint8List.fromList(utf8.encode('nip44-v2')),
    );
  }
}

typedef Encryption = Nip44;
