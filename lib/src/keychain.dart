import 'package:bip340/bip340.dart' as bip340;
import 'package:nostr/nostr.dart';

/// A keychain encapsulates a public key and a private key, which are used for tasks such as encrypting and decrypting messages, or creating and verifying digital signatures.
class Keychain {
  /// An hex-encoded (64 chars) private key used to decrypt messages or create digital signatures, and it must be kept secret.
  late String private;

  /// A hex-encoded (64 chars) public key used to encrypt messages or verify digital signatures, and it can be shared with anyone.
  late String public;

  /// Instantiate a Keychain from a private key using HEX or BECH32 encoding
  Keychain(String privateKeyHexOrBech32) {
    if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(privateKeyHexOrBech32)) {
      private = privateKeyHexOrBech32.toLowerCase();
      public = bip340.getPublicKey(private);
      return;
    }

    try {
      final nsec = Nip19.decode(payload: privateKeyHexOrBech32);
      if (nsec.prefix != Nip19Prefix.nsec) {
        throw Exception('bech32 must have prefix "nsec", got ${nsec.prefix}');
      }
      private = nsec.data;
      public = bip340.getPublicKey(private);
    } catch (e) {
      throw Exception('Expects HEX or valid Bech32 "nsec".: $e');
    }
  }

  /// Wrap the default constructor with a named parameter for those who enjoy them
  factory Keychain.from({required String privateKeyHexOrBech32}) {
    return Keychain(privateKeyHexOrBech32);
  }

  /// Instantiate a Keychain from random bytes
  Keychain.generate() {
    private = generate64RandomHexChars();
    public = bip340.getPublicKey(private);
  }

  /// Encapsulate dart-bip340 sign() so you don't need to add bip340 as a dependency
  String sign({required String message}) {
    final aux = generate64RandomHexChars();
    return bip340.sign(private, message, aux);
  }

  /// Encapsulate dart-bip340 verify() so you don't need to add bip340 as a dependency
  static bool verify({
    required String pubkey,
    required String message,
    required String signature,
  }) {
    return bip340.verify(pubkey, message, signature);
  }
}
