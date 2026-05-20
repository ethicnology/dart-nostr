import 'package:nostr/src/error.dart';
import 'package:nostr/src/nips/nip_019.dart';
import 'package:nostr/src/schnorr.dart';
import 'package:nostr/src/utils.dart';

/// Encapsulates a Nostr key pair (secret and public key).
///
/// Keys are used for tasks such as encrypting and decrypting messages,
/// or creating and verifying digital signatures.
class Keys {
  /// A hex-encoded (64 chars) secret key used to decrypt messages or
  /// create digital signatures. It must be kept secret.
  late final String secret;

  /// A hex-encoded (64 chars) public key used to encrypt messages or
  /// verify digital signatures. It can be shared with anyone.
  late final String public;

  /// Returns the Bech32-encoded secret key (`nsec1...`).
  String get nsec => Bech32Entity.encode(prefix: Nip19Prefix.nsec, data: secret);

  /// Returns the Bech32-encoded public key (`npub1...`).
  String get npub => Bech32Entity.encode(prefix: Nip19Prefix.npub, data: public);

  /// Instantiates [Keys] from a secret key in HEX or Bech32 (`nsec`) encoding.
  ///
  /// Throws an [InvalidKeyException] if the key is not a valid hex string
  /// and cannot be decoded as a Bech32 `nsec`.
  Keys(String secretKey) {
    if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(secretKey)) {
      secret = secretKey.toLowerCase();
      public = Schnorr.derivePublicKey(secret);
      return;
    }

    try {
      final nsec = Bech32Entity.decode(payload: secretKey);
      if (nsec.prefix != Nip19Prefix.nsec) {
        throw InvalidKeyException(
          'bech32 must have prefix "nsec", got ${nsec.prefix}',
        );
      }
      secret = nsec.data;
      public = Schnorr.derivePublicKey(secret);
    } on InvalidKeyException {
      rethrow;
    } on Object {
      // Deliberately do not surface the underlying error message — bech32
      // failure modes (MixedCase, InvalidChecksum, …) sometimes echo the
      // raw input back, which would leak the candidate secret into logs.
      throw const InvalidKeyException(
        'Expects HEX or valid Bech32 "nsec"',
      );
    }
  }

  /// Generates a new random key pair.
  Keys.generate() {
    secret = generateRandomHex();
    public = Schnorr.derivePublicKey(secret);
  }

  /// Signs a 32-byte hex-encoded [message] using Schnorr (BIP-340).
  ///
  /// This is a convenience wrapper around [Schnorr.sign] so callers
  /// do not need to depend on the `bip340` package directly.
  String sign({required String message}) =>
      Schnorr.sign(secretKey: secret, message: message);
}
