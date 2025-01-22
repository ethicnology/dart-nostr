import 'dart:convert';
import 'dart:typed_data';
import 'package:elliptic/ecdh.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nostr/nostr.dart';
import 'package:nostr/src/nips/nip_044_utils.dart';

/// NIP-44 encryption and decryption functions.
class Nip44 {
  static Future<String> encryptMessage(
    String plaintext,
    String senderPrivateKey,
    String recipientPublicKey, {
    Uint8List? customNonce,
    Uint8List? customConversationKey,
  }) async {
    // Step 1: Compute Shared Secret
    final sharedSecret = customConversationKey ??
        computeSharedSecret(senderPrivateKey, recipientPublicKey);

    // Step 2: Derive Conversation Key
    final conversationKey =
        customConversationKey ?? deriveConversationKey(sharedSecret);

    // Step 3: Generate or Use Custom Nonce
    final nonce = customNonce ?? generateRandomBytes(32);

    // Step 4: Derive Message Keys
    final keys = deriveMessageKeys(conversationKey, nonce);
    final chachaKey = keys['chachaKey']!;
    final chachaNonce = keys['chachaNonce']!;
    final hmacKey = keys['hmacKey']!;

    // Step 5: Pad Plaintext
    final paddedPlaintext = pad(utf8.encode(plaintext));

    // Step 6: Encrypt
    final ciphertext =
        await encryptChaCha20(chachaKey, chachaNonce, paddedPlaintext);

    // Step 7: Calculate MAC
    final mac = calculateMac(hmacKey, nonce, ciphertext);

    // Step 8: Construct Payload
    return constructPayload(nonce, ciphertext, mac);
  }

  static Future<String> decryptMessage(
    String payload,
    String recipientPrivateKey,
    String senderPublicKey, {
    Uint8List? customConversationKey,
  }) async {
    // Step 1: Compute Shared Secret
    final sharedSecret = customConversationKey ??
        computeSharedSecret(recipientPrivateKey, senderPublicKey);

    // Step 2: Derive Conversation Key
    final conversationKey =
        customConversationKey ?? deriveConversationKey(sharedSecret);

    // Step 3: Parse Payload
    final parsed = parsePayload(payload);
    final nonce = parsed['nonce'];
    final ciphertext = parsed['ciphertext'];
    final mac = parsed['mac'];

    // Step 4: Derive Message Keys
    final keys = deriveMessageKeys(conversationKey, nonce);
    final chachaKey = keys['chachaKey']!;
    final chachaNonce = keys['chachaNonce']!;
    final hmacKey = keys['hmacKey']!;

    // Step 5: Verify MAC
    verifyMac(hmacKey, nonce, ciphertext, mac);

    // Step 6: Decrypt
    final paddedPlaintext =
        await decryptChaCha20(chachaKey, chachaNonce, ciphertext);

    // Step 7: Unpad Plaintext
    final plaintextBytes = unpad(paddedPlaintext);

    return utf8.decode(plaintextBytes);
  }

  static Uint8List computeSharedSecret(
    String privateKeyHex,
    String publicKeyHex,
  ) {
    final ec = getS256();
    final privateKey = PrivateKey.fromHex(ec, privateKeyHex);
    final publicKey = PublicKey.fromHex(ec, checkPublicKey(publicKeyHex));
    final sec = computeSecret(privateKey, publicKey);
    return Uint8List.fromList(sec);
  }

  static Uint8List deriveConversationKey(Uint8List sharedSecret) {
    final salt = utf8.encode('nip44-v2');

    final conversationKey = hkdfExtract(
      ikm: sharedSecret,
      salt: Uint8List.fromList(salt),
    );

    return conversationKey;
  }
}
