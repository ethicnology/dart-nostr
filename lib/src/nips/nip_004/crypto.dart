import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

import '../../crypto/kepler.dart';

class Nip04 {
  static Map<String, List<List<int>>> gMapByteSecret = {};

  // Encrypt data using self private key in nostr format ( with trailing ?iv=)
  static String encryptMessage(
      String privateString, String publicString, String plainText) {
    Uint8List uintInputText = Utf8Encoder().convert(plainText);
    final encryptedString =
        encryptMessageRaw(privateString, publicString, uintInputText);
    return encryptedString;
  }

  static String encryptMessageRaw(
      String privateString, String publicString, Uint8List uintInputText) {
    final secretIV = Kepler.byteSecret(privateString, publicString);
    final key = Uint8List.fromList(secretIV[0]);

    // generate iv  https://stackoverflow.com/questions/63630661/aes-engine-not-initialised-with-pointycastle-securerandom
    FortunaRandom fr = FortunaRandom();
    final sGen = Random.secure();
    fr.seed(KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => sGen.nextInt(255)))));
    final iv = fr.nextBytes(16);

    CipherParameters params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv), null);

    PaddedBlockCipherImpl cipherImpl =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));

    cipherImpl.init(
        true, // means to encrypt
        params as PaddedBlockCipherParameters<CipherParameters?,
            CipherParameters?>);

    // allocate space
    final Uint8List outputEncodedText = Uint8List(uintInputText.length + 16);

    var offset = 0;
    while (offset < uintInputText.length - 16) {
      offset += cipherImpl.processBlock(
          uintInputText, offset, outputEncodedText, offset);
    }

    //add padding
    offset +=
        cipherImpl.doFinal(uintInputText, offset, outputEncodedText, offset);
    final Uint8List finalEncodedText = outputEncodedText.sublist(0, offset);

    String stringIv = base64.encode(iv);
    String outputPlainText = base64.encode(finalEncodedText);
    outputPlainText = "$outputPlainText?iv=$stringIv";
    return outputPlainText;
  }

  // pointy castle source https://github.com/PointyCastle/pointycastle/blob/master/tutorials/aes-cbc.md
  // https://github.com/bcgit/pc-dart/blob/master/tutorials/aes-cbc.md
  // 3 https://github.com/Dhuliang/flutter-bsv/blob/42a2d92ec6bb9ee3231878ffe684e1b7940c7d49/lib/src/aescbc.dart

  /// Decrypt data using self private key
  static String decrypt(
      String privateString, String publicString, String b64encoded,
      [String b64IV = ""]) {
    Uint8List encdData = base64.decode(b64encoded);
    final rawData = decryptRaw(privateString, publicString, encdData, b64IV);
    return Utf8Decoder().convert(rawData.toList());
  }

  static Uint8List decryptRaw(
      String privateString, String publicString, Uint8List cipherText,
      [String b64IV = ""]) {
    List<List<int>> byteSecret = gMapByteSecret[publicString] ?? [];
    if (byteSecret.isEmpty) {
      byteSecret = Kepler.byteSecret(privateString, publicString);
      gMapByteSecret[publicString] = byteSecret;
    }
    final secretIV = byteSecret;
    final key = Uint8List.fromList(secretIV[0]);
    final iv = b64IV.length > 6
        ? base64.decode(b64IV)
        : Uint8List.fromList(secretIV[1]);

    CipherParameters params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv), null);

    PaddedBlockCipherImpl cipherImpl =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));

    cipherImpl.init(
        false,
        params as PaddedBlockCipherParameters<CipherParameters?,
            CipherParameters?>);
    final Uint8List finalPlainText =
        Uint8List(cipherText.length); // allocate space

    var offset = 0;
    while (offset < cipherText.length - 16) {
      offset +=
          cipherImpl.processBlock(cipherText, offset, finalPlainText, offset);
    }
    //remove padding
    offset += cipherImpl.doFinal(cipherText, offset, finalPlainText, offset);
    return finalPlainText.sublist(0, offset);
  }
}
