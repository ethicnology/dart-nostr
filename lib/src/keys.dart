import 'package:bip340/bip340.dart' as bip340;
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
  late String secret;

  /// A hex-encoded (64 chars) public key used to encrypt messages or
  /// verify digital signatures. It can be shared with anyone.
  late String public;

  /// Returns the Bech32-encoded secret key (`nsec1...`).
  String get nsec => Nip19.encode(prefix: Nip19Prefix.nsec, data: secret);

  /// Returns the Bech32-encoded public key (`npub1...`).
  String get npub => Nip19.encode(prefix: Nip19Prefix.npub, data: public);

  /// Instantiates [Keys] from a secret key in HEX or Bech32 (`nsec`) encoding.
  ///
  /// Throws an [InvalidKeyException] if the key is not a valid hex string
  /// and cannot be decoded as a Bech32 `nsec`.
  Keys(String secretKey) {
    if (RegExp(r'^[0-9A-Fa-f]{64}$').hasMatch(secretKey)) {
      secret = secretKey.toLowerCase();
      public = bip340.getPublicKey(secret);
      return;
    }

    try {
      final nsec = Nip19.decode(payload: secretKey);
      if (nsec.prefix != Nip19Prefix.nsec) {
        throw InvalidKeyException(
          'bech32 must have prefix "nsec", got ${nsec.prefix}',
        );
      }
      secret = nsec.data;
      public = bip340.getPublicKey(secret);
    } catch (e) {
      if (e is InvalidKeyException) rethrow;
      throw InvalidKeyException('Expects HEX or valid Bech32 "nsec".: $e');
    }
  }

  /// Named-parameter variant of the default constructor.
  factory Keys.from({required String secretKey}) {
    return Keys(secretKey);
  }

  /// Generates a new random key pair.
  Keys.generate() {
    secret = generateRandomHex();
    public = bip340.getPublicKey(secret);
  }

  /// Signs a 32-byte hex-encoded [message] using Schnorr (BIP-340).
  ///
  /// This is a convenience wrapper around [Schnorr.sign] so callers
  /// do not need to depend on the `bip340` package directly.
  String sign({required String message}) =>
      Schnorr.sign(secretKey: secret, message: message);
}
