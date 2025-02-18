import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:nostr/nostr.dart';

/// Keys encapsulates a public key and a secret key, which are used for tasks such as encrypting and decrypting messages, or creating and verifying digital signatures.
class Keys {
  /// An hex-encoded (64 chars) secret key used to decrypt messages or create digital signatures, and it must be kept secret.
  late String secret;

  /// A hex-encoded (64 chars) public key used to encrypt messages or verify digital signatures, and it can be shared with anyone.
  late String public;

  // String get nsec => Nip19.encode(prefix: Nip19Prefix.nsec, data: secret);
  // String get npub => Nip19.encode(prefix: Nip19Prefix.npub, data: public);

  /// Instantiate a Keys from a secret key using HEX or BECH32 encoding
  Keys(String secretKey) {
    if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(secretKey)) {
      secret = secretKey.toLowerCase();
      public = bip340.getPublicKey(secret);
      return;
    }

    try {
      final nsec = Nip19.decode(payload: secretKey);
      if (nsec.prefix != Nip19Prefix.nsec) {
        throw Exception('bech32 must have prefix "nsec", got ${nsec.prefix}');
      }
      secret = nsec.data;
      public = bip340.getPublicKey(secret);
    } catch (e) {
      throw Exception('Expects HEX or valid Bech32 "nsec".: $e');
    }
  }

  /// Wrap the default constructor with a named parameter for those who enjoy them
  factory Keys.from({required String secretKey}) {
    return Keys(secretKey);
  }

  /// Instantiate a Keys from random bytes
  Keys.generate() {
    secret = generate64RandomHexChars();
    public = bip340.getPublicKey(secret);
  }

  /// Encapsulate dart-bip340 sign() so you don't need to add bip340 as a dependency
  String sign({required String message}) {
    final aux = generate64RandomHexChars();
    if (hex.decode(message).length != 32) {
      throw Exception(
          "message must also be 32-bytes (a hash of the actual message)");
    }
    return bip340.sign(secret, message, aux);
  }

  /// Encapsulate dart-bip340 verify() so you don't need to add bip340 as a dependency
  static bool verify({
    required String pubkey,
    required String message,
    required String signature,
  }) {
    if (hex.decode(pubkey).length != 32) {
      throw Exception(
          "pubkey must be 32-bytes hex encoded (a hash of the actual message)");
    }
    if (hex.decode(message).length != 32) {
      throw Exception(
          "message must be 32-bytes hex encoded (a hash of the actual message)");
    }
    if (hex.decode(signature).length != 64) {
      throw Exception("signature must be 64-bytes hex encoded");
    }
    return bip340.verify(pubkey, message, signature);
  }
}
