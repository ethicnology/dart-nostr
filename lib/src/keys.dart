import 'package:bip340/bip340.dart' as bip340;
import 'package:nostr/src/nips/nip_019.dart';
import 'package:nostr/src/schnorr.dart';
import 'package:nostr/src/utils.dart';

/// Keys encapsulates a public key and a secret key, which are used for tasks such as encrypting and decrypting messages, or creating and verifying digital signatures.
class Keys {
  /// An hex-encoded (64 chars) secret key used to decrypt messages or create digital signatures, and it must be kept secret.
  late String secret;

  /// A hex-encoded (64 chars) public key used to encrypt messages or verify digital signatures, and it can be shared with anyone.
  late String public;

  /// Bech32-encoded secret key (nsec1...)
  String get nsec => Nip19.encode(prefix: Nip19Prefix.nsec, data: secret);

  /// Bech32-encoded public key (npub1...)
  String get npub => Nip19.encode(prefix: Nip19Prefix.npub, data: public);

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
    secret = generateRandomHex();
    public = bip340.getPublicKey(secret);
  }

  /// Encapsulate dart-bip340 sign() so you don't need to add bip340 as a dependency
  String sign({required String message}) =>
      Schnorr.sign(secretKey: secret, message: message);
}
