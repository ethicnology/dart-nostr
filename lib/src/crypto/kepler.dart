// credit: https://github.com/tjcampanella/kepler/blob/master/lib/src/kepler.dart

import 'package:convert/convert.dart';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'operator.dart';

class Kepler {
  /// return a Bytes data secret
  static List<List<int>> byteSecret(String privateString, String publicString) {
    final secret = rawSecret(privateString, publicString);
    assert(secret.x != null && secret.y != null);
    final xs = secret.x!.toBigInteger()!.toRadixString(16);
    final ys = secret.y!.toBigInteger()!.toRadixString(16);
    final hexX = leftPadding(xs, 64);
    final hexY = leftPadding(ys, 64);
    final secretBytes = Uint8List.fromList(hex.decode('$hexX$hexY'));
    return [secretBytes.sublist(0, 32), secretBytes.sublist(32, 40)];
  }

  /// return a ECPoint data secret
  static ECPoint rawSecret(String privateString, String publicString) {
    final privateKey = loadPrivateKey(privateString);
    final publicKey = loadPublicKey(publicString);
    assert(privateKey.d != null && publicKey.Q != null);
    return scalarMultiple(privateKey.d!, publicKey.Q!);
  }

  static String leftPadding(String s, int width) {
    const paddingData = '000000000000000';
    final paddingWidth = width - s.length;
    if (paddingWidth < 1) {
      return s;
    }
    return "${paddingData.substring(0, paddingWidth)}$s";
  }

  /// return a privateKey from hex string
  static ECPrivateKey loadPrivateKey(String storedkey) {
    final d = BigInt.parse(storedkey, radix: 16);
    final param = ECCurve_secp256k1();
    return ECPrivateKey(d, param);
  }

  /// return a publicKey from hex string
  static ECPublicKey loadPublicKey(String storedkey) {
    final param = ECCurve_secp256k1();
    if (storedkey.length < 120) {
      List<int> codeList = [];
      for (var idx = 0; idx < storedkey.length - 1; idx += 2) {
        final hexStr = storedkey.substring(idx, idx + 2);
        codeList.add(int.parse(hexStr, radix: 16));
      }
      final Q = param.curve.decodePoint(codeList);
      return ECPublicKey(Q, param);
    } else {
      final x = BigInt.parse(storedkey.substring(0, 64), radix: 16);
      final y = BigInt.parse(storedkey.substring(64), radix: 16);
      final Q = param.curve.createPoint(x, y);
      return ECPublicKey(Q, param);
    }
  }
}
