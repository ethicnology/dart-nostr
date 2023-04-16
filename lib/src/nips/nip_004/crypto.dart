import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

import '../../crypto/kepler.dart';

class Nip4 {
  static Map<String, List<List<int>>> gMapByteSecret = {};
  // pointy castle source https://github.com/PointyCastle/pointycastle/blob/master/tutorials/aes-cbc.md
  // https://github.com/bcgit/pc-dart/blob/master/tutorials/aes-cbc.md
  // 3 https://github.com/Dhuliang/flutter-bsv/blob/42a2d92ec6bb9ee3231878ffe684e1b7940c7d49/lib/src/aescbc.dart

  // Encrypt data using self private key in nostr format ( with trailing ?iv=)
  static String cipher(
    String privkey,
    String pubkey,
    String plaintext,
  ) {
    Uint8List uintInputText = Utf8Encoder().convert(plaintext);
    final secretIV = Kepler.byteSecret(privkey, pubkey);
    final key = Uint8List.fromList(
      secretIV[0],
    );

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

  // Decrypt data using self private key
  static String decipher(
    String privkey,
    String pubkey,
    String ciphertext, [
    String nonce = "",
  ]) {
    Uint8List cipherText = base64.decode(ciphertext);
    List<List<int>> byteSecret = gMapByteSecret[pubkey] ?? [];
    if (byteSecret.isEmpty) {
      byteSecret = Kepler.byteSecret(privkey, pubkey);
      gMapByteSecret[pubkey] = byteSecret;
    }
    final secretIV = byteSecret;
    final key = Uint8List.fromList(secretIV[0]);
    final iv = nonce.length > 6
        ? base64.decode(nonce)
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
    Uint8List result = finalPlainText.sublist(0, offset);
    return Utf8Decoder().convert(result.toList());
  }
}
