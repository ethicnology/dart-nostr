import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:nostr/nostr.dart';

class Schnorr {
  /// Encapsulate dart-bip340 sign() so you don't need to add bip340 as a dependency
  static String sign({
    required String secretKey,
    required String message,
    String? aux,
  }) {
    aux ??= generate64RandomHexChars();

    if (hex.decode(secretKey).length != 32) {
      throw Exception("secretKey must be 32-bytes hex encoded");
    }
    if (hex.decode(message).length != 32) {
      throw Exception(
        "message must be 32-bytes hex encoded (a hash of the actual message)",
      );
    }
    if (hex.decode(aux).length != 32) {
      throw Exception("aux must be 32-bytes hex encoded");
    }

    return bip340.sign(secretKey, message, aux);
  }

  /// Encapsulate dart-bip340 verify() so you don't need to add bip340 as a dependency
  static bool verify({
    required String publicKey,
    required String message,
    required String signature,
  }) {
    if (hex.decode(publicKey).length != 32) {
      throw Exception("publicKey must be 32-bytes hex encoded");
    }
    if (hex.decode(message).length != 32) {
      throw Exception(
        "message must be 32-bytes hex encoded (a hash of the actual message)",
      );
    }
    if (hex.decode(signature).length != 64) {
      throw Exception("signature must be 64-bytes hex encoded");
    }
    return bip340.verify(publicKey, message, signature);
  }
}
