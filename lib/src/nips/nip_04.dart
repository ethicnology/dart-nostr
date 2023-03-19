/// implementation of NIP-04
/// https://github.com/nostr-protocol/nips/blob/master/04.md
///
import 'dart:convert' as convert;
import 'dart:convert';
import 'dart:math';
import "dart:typed_data";

import 'package:bip340/bip340.dart';
import 'package:crypto/crypto.dart';
import 'package:kepler/kepler.dart';
import "package:pointycastle/export.dart";

String myEncrypt(String privateString, String publicString, String plainText) {
  Uint8List uintInputText = convert.Utf8Encoder().convert(plainText);
  final encryptedString =
      myEncryptRaw(privateString, publicString, uintInputText);
  return encryptedString;
}

String myEncryptRaw(
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
      params
          as PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>);

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

  String stringIv = convert.base64.encode(iv);
  String outputPlainText = convert.base64.encode(finalEncodedText);
  outputPlainText = "$outputPlainText?iv=$stringIv";
  return outputPlainText;
}

String addEscapeChars(String str) {
  String temp = "";
  //temp = temp.replaceAll("\\", "\\\\");
  temp = str.replaceAll("\"", "\\\"");
  return temp.replaceAll("\n", "\\n");
}

String unEscapeChars(String str) {
  String temp = str.replaceAll("\"", "\\\"");
  temp = temp.replaceAll("\n", "\\n");
  return temp;
}

String mySign(String privateKey, String msg) {
  String randomSeed = getRandomPrivKey();
  randomSeed = randomSeed.substring(0, 32);
  return sign(privateKey, msg, randomSeed);
}

String getRandomPrivKey() {
  FortunaRandom fr = FortunaRandom();
  final sGen = Random.secure();
  fr.seed(KeyParameter(
      Uint8List.fromList(List.generate(32, (_) => sGen.nextInt(255)))));

  BigInt randomNumber = fr.nextBigInteger(256);
  String strKey = randomNumber.toRadixString(16);
  if (strKey.length < 64) {
    int numZeros = 64 - strKey.length;
    for (int i = 0; i < numZeros; i++) {
      strKey = "0$strKey";
    }
  }
  return strKey;
}

String getShaId(String pubkey, String createdAt, String kind, String strTags,
    String content) {
  String buf = '[0,"$pubkey",$createdAt,$kind,[$strTags],"$content"]';
  var bufInBytes = utf8.encode(buf);
  var value = sha256.convert(bufInBytes);
  return value.toString();
}

String getNip4Message(String privateKey, String toPublicKey, String message,
    [DateTime? createdAt]) {
  String userPublicKey = getPublicKey(privateKey);
  String otherPubkey02 = "02$toPublicKey";
  String encryptedMessageToSend =
      addEscapeChars(myEncrypt(privateKey, otherPubkey02, message));
  // String strTags = node.getTagStrForChannelReply(channel, replyTo, exename);
  int timestamp;
  if (createdAt != null) {
    timestamp = createdAt.millisecondsSinceEpoch ~/ 1000;
  } else {
    timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
  String strTags = '["p","$toPublicKey"]';
  String replyKind = "4";
  String id = getShaId(userPublicKey, timestamp.toString(), replyKind, strTags,
      encryptedMessageToSend);
  String sig = mySign(privateKey, id);

  String toSendMessage =
      '["EVENT",{"id":"$id","pubkey":"$userPublicKey","created_at":$timestamp,"kind":$replyKind,"tags":[$strTags],"content":"$encryptedMessageToSend","sig":"$sig"}]';
  return toSendMessage;
}
