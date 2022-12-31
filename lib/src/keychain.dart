import 'package:bip340/bip340.dart' as bip340;
import 'package:nostr/src/utils.dart';

/// A keychain encapsulates a public key and a private key, which are used for tasks such as encrypting and decrypting messages, or creating and verifying digital signatures.
class Keychain {
  /// An hex-encoded (64 chars) private key used to decrypt messages or create digital signatures, and it must be kept secret.
  late String private;

  /// A hex-encoded (64 chars) public key used to encrypt messages or verify digital signatures, and it can be shared with anyone.
  late String public;

  /// Instanciate a Keychain with a private key hex-encoded
  ///
  /// There is a pending issue in dart-bip340 lib where some private keys generates non padded pubkey (missing leading '0').
  /// If you input such private key, I can't let you instanciates Keychain with the current private key because it will messup all NOSTR signatures.
  /// I hope it will be fix asap: https://github.com/nbd-wtf/dart-bip340/issues/4
  Keychain(this.private) {
    assert(
      private.length == 64,
      "Private key should be 64 chars length (32 bytes hex encoded)",
    );
    public = bip340.getPublicKey(private);
    assert(
      public.length == 64,
      '''\n
      There is a pending issue in dart-bip340 lib where some private keys generates non padded pubkey (missing leading '0'). \n
      I can't let you instanciate Keychain with the current private key because it will messup all NOSTR signatures. \n
      I hope it will be fix asap so i can remove this assert. \n
      https://github.com/nbd-wtf/dart-bip340/issues/4
      ''',
    );
  }

  /// Instanciate a Keychain from random bytes
  Keychain.generate() {
    private = generate64RandomHexChars();
    public = bip340.getPublicKey(private);

    /// The function getPublicKey() does not pad the returned value with 0 if the calculated public key should have zeros at beginning
    /// https://github.com/nbd-wtf/dart-bip340/issues/4
    while (public.length != 64) {
      private = generate64RandomHexChars();
      public = bip340.getPublicKey(private);
    }
  }

  /// Encapsulate dart-bip340 sign() so you don't need to add bip340 as a dependency
  String sign(String message) {
    String aux = generate64RandomHexChars();
    return bip340.sign(private, message, aux);
  }

  /// Encapsulate dart-bip340 verify() so you don't need to add bip340 as a dependency
  static bool verify(
    String? pubkey,
    String message,
    String signature,
  ) {
    return bip340.verify(pubkey, message, signature);
  }
}
