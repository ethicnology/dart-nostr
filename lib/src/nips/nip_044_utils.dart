import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/export.dart';

// ignore: non_constant_identifier_names
final HMAC_SHA256_64 = HMac(SHA256Digest(), 64);

Map<String, List<int>> deriveMessageKeys(
  List<int> conversationKey,
  List<int> nonce,
) {
  if (conversationKey.length != 32) {
    throw FormatException('Invalid conversation key length');
  }
  if (nonce.length != 32) {
    throw FormatException('Invalid nonce length');
  }

  final hkdfOutput = hkdfExpand(
    prk: conversationKey,
    info: nonce,
    length: 76,
  );

  return {
    'chachaKey': hkdfOutput.sublist(0, 32),
    'chachaNonce': hkdfOutput.sublist(32, 44), // Should be 12 bytes
    'hmacKey': hkdfOutput.sublist(44, 76),
  };
}

List<int> pad(List<int> plaintext) {
  final unpaddedLen = plaintext.length;
  if (unpaddedLen < 1 || unpaddedLen > 65535) {
    throw Exception('Invalid plaintext length');
  }

  final paddedLen = calcPaddedLen(unpaddedLen);
  final padded = Uint8List(paddedLen + 2);

  // First two bytes are the length in big-endian
  padded[0] = (unpaddedLen >> 8) & 0xFF;
  padded[1] = unpaddedLen & 0xFF;

  padded.setRange(2, 2 + unpaddedLen, plaintext);

  // The rest is zeros by default
  return padded;
}

int calcPaddedLen(int unpaddedLen) {
  final nextPower = 1 << ((unpaddedLen - 1).bitLength);
  final chunk = nextPower <= 256 ? 32 : nextPower ~/ 8;
  if (unpaddedLen <= 32) {
    return 32;
  } else {
    return chunk * ((unpaddedLen - 1) ~/ chunk + 1);
  }
}

Future<List<int>> encryptChaCha20(
  List<int> key,
  List<int> nonce,
  List<int> data,
) async {
  final algorithm = crypto.Chacha20(macAlgorithm: crypto.MacAlgorithm.empty);
  final skey = crypto.SecretKey(key);
  final secretBox = await algorithm.encrypt(
    data,
    secretKey: skey,
    nonce: nonce,
  );

  return secretBox.cipherText;
}

Future<List<int>> decryptChaCha20(
  List<int> key,
  List<int> nonce,
  List<int> ciphertext,
) async {
  final algorithm = crypto.Chacha20(macAlgorithm: crypto.MacAlgorithm.empty);
  final skey = crypto.SecretKey(key);
  final secretBox = crypto.SecretBox(
    ciphertext,
    nonce: nonce,
    mac: crypto.Mac.empty,
  );

  final plaintext = await algorithm.decrypt(
    secretBox,
    secretKey: skey,
  );

  return plaintext;
}

String constructPayload(List<int> nonce, List<int> ciphertext, List<int> mac) {
  List<int> payloadBytes = [
    0x02, // Version
    ...nonce,
    ...ciphertext,
    ...mac,
  ];
  return base64.encode(payloadBytes);
}

List<int> hkdfExtract({required List<int> ikm, required List<int> salt}) {
  final u8salt = Uint8List.fromList(salt);
  final u8ikm = Uint8List.fromList(ikm);
  final hmacSha256 = HMAC_SHA256_64..init(KeyParameter(u8salt));
  return hmacSha256.process(u8ikm);
}

List<int> hkdfExpand({
  required List<int> prk,
  required List<int> info,
  required int length,
}) {
  var hashLen = 32;
  int n = (length + hashLen - 1) ~/ hashLen;
  var okm = <int>[];
  var previous = <int>[];
  final u8prk = Uint8List.fromList(prk);

  for (var i = 1; i <= n; i++) {
    final hmacSha256 = HMAC_SHA256_64..init(KeyParameter(u8prk));
    var data = Uint8List.fromList([
      ...previous,
      ...info,
      i,
    ]);
    previous = hmacSha256.process(data);
    okm.addAll(previous);
  }
  return Uint8List.fromList(okm.sublist(0, length));
}

List<int> unpad(List<int> padded) {
  int unpaddedLen = (padded[0] << 8) + padded[1];
  if (unpaddedLen == 0 || unpaddedLen > padded.length - 2) {
    throw Exception('Invalid padding');
  }
  return padded.sublist(2, 2 + unpaddedLen);
}

List<int> calculateMac(List<int> key, List<int> nonce, List<int> ciphertext) {
  final u8key = Uint8List.fromList(key);
  final hmacSha256 = HMAC_SHA256_64..init(KeyParameter(u8key));
  return hmacSha256.process(Uint8List.fromList([...nonce, ...ciphertext]));
}

Map<String, dynamic> parsePayload(String payload) {
  if (payload.isEmpty || payload[0] == '#') {
    throw Exception('Unknown version');
  }

  if (payload.length < 132 || payload.length > 87472) {
    throw Exception('Invalid payload size');
  }

  final data = base64.decode(payload);

  if (data[0] != 0x02) {
    throw Exception('Unsupported version');
  }

  final nonce = data.sublist(1, 33);
  final mac = data.sublist(data.length - 32);
  final ciphertext = data.sublist(33, data.length - 32);

  return {
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };
}

void verifyMac(
  List<int> hmacKey,
  List<int> nonce,
  List<int> ciphertext,
  List<int> mac,
) {
  final calculatedMac = calculateMac(hmacKey, nonce, ciphertext);
  if (hex.encode(calculatedMac) != hex.encode(mac)) {
    throw Exception('Invalid MAC');
  }
}

String checkPublicKey(String publicKey) {
  if (publicKey.length == 66 &&
      (publicKey.startsWith('02') || publicKey.startsWith('03'))) {
    return publicKey;
  } else if (publicKey.length > 66 && publicKey.startsWith('04')) {
    return publicKey;
  } else if (publicKey.length == 64) {
    return '02$publicKey';
  }
  throw Exception('Invalid Public Key');
}
