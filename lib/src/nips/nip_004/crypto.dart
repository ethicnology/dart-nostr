import 'dart:convert';
import 'dart:typed_data';
import 'package:nostr/nostr.dart';
import 'package:nostr/src/crypto/kepler.dart';
import 'package:pointycastle/export.dart';

/// NIP4 cipher
String cipher(
  String privkey,
  String pubkey,
  String payload,
  bool cipher, {
  String? nonce,
}) {
  // if cipher=false –> decipher –> nonce needed
  if (!cipher && nonce == null) throw Exception("missing nonce");

  // init variables
  Uint8List input, output, iv;
  if (!cipher && nonce != null) {
    input = base64.decode(payload);
    output = Uint8List(input.length);
    iv = base64.decode(nonce);
  } else {
    input = Utf8Encoder().convert(payload);
    output = Uint8List(input.length + 16);
    iv = Uint8List.fromList(generateRandomBytes(16));
  }

  // params
  List<List<int>> keplerSecret = Kepler.byteSecret(privkey, pubkey);
  var key = Uint8List.fromList(keplerSecret[0]);
  var params = PaddedBlockCipherParameters(
    ParametersWithIV(KeyParameter(key), iv),
    null,
  );
  var algo = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );

  // processing
  algo.init(cipher, params);
  var offset = 0;
  while (offset < input.length - 16) {
    offset += algo.processBlock(input, offset, output, offset);
  }
  offset += algo.doFinal(input, offset, output, offset);
  Uint8List result = output.sublist(0, offset);

  if (cipher) {
    String stringIv = base64.encode(iv);
    String plaintext = base64.encode(result);
    return "$plaintext?iv=$stringIv";
  } else {
    return Utf8Decoder().convert(result);
  }
}
