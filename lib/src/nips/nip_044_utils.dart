import 'dart:convert';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

Map<String, Uint8List> deriveMessageKeys(
    Uint8List conversationKey, Uint8List nonce) {
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

Uint8List pad(Uint8List plaintext) {
  int unpaddedLen = plaintext.length;
  if (unpaddedLen < 1 || unpaddedLen > 65535) {
    throw Exception('Invalid plaintext length');
  }

  int paddedLen = calcPaddedLen(unpaddedLen);
  Uint8List padded = Uint8List(paddedLen + 2);

  // First two bytes are the length in big-endian
  padded[0] = (unpaddedLen >> 8) & 0xFF;
  padded[1] = unpaddedLen & 0xFF;

  padded.setRange(2, 2 + unpaddedLen, plaintext);

  // The rest is zeros by default
  return padded;
}

int calcPaddedLen(int unpaddedLen) {
  int nextPower = 1 << ((unpaddedLen - 1).bitLength);
  int chunk = nextPower <= 256 ? 32 : nextPower ~/ 8;
  if (unpaddedLen <= 32) {
    return 32;
  } else {
    return chunk * ((unpaddedLen - 1) ~/ chunk + 1);
  }
}

Future<Uint8List> encryptChaCha20(
    Uint8List key, Uint8List nonce, Uint8List data) async {
  final algorithm = Chacha20(macAlgorithm: MacAlgorithm.empty);
  final skey = SecretKey(key);
  final secretBox = await algorithm.encrypt(
    data,
    secretKey: skey,
    nonce: nonce,
  );

  return Uint8List.fromList(secretBox.cipherText);
}

Future<Uint8List> decryptChaCha20(
    Uint8List key, Uint8List nonce, Uint8List ciphertext) async {
  final algorithm = Chacha20(macAlgorithm: MacAlgorithm.empty);
  final skey = SecretKey(key);
  final secretBox = SecretBox(
    ciphertext,
    nonce: nonce,
    mac: Mac.empty,
  );

  final plaintext = await algorithm.decrypt(
    secretBox,
    secretKey: skey,
  );

  return Uint8List.fromList(plaintext);
}

String constructPayload(Uint8List nonce, Uint8List ciphertext, Uint8List mac) {
  Uint8List payloadBytes = Uint8List.fromList([
    0x02, // Version
    ...nonce,
    ...ciphertext,
    ...mac,
  ]);
  return base64.encode(payloadBytes);
}

Uint8List hkdfExtract({required Uint8List ikm, required Uint8List salt}) {
  var hmacSha256 = crypto.Hmac(crypto.sha256, salt);
  var prk = hmacSha256.convert(ikm).bytes;
  return Uint8List.fromList(prk);
}

Uint8List hkdfExpand({
  required Uint8List prk,
  required Uint8List info,
  required int length,
}) {
  var hashLen = 32;
  int n = (length + hashLen - 1) ~/ hashLen;
  var okm = <int>[];
  var previous = <int>[];

  for (var i = 1; i <= n; i++) {
    var hmacSha256 = crypto.Hmac(crypto.sha256, prk);
    var data = <int>[
      ...previous,
      ...info,
      i,
    ];
    previous = hmacSha256.convert(data).bytes;
    okm.addAll(previous);
  }
  return Uint8List.fromList(okm.sublist(0, length));
}

Uint8List unpad(Uint8List padded) {
  int unpaddedLen = (padded[0] << 8) + padded[1];
  if (unpaddedLen == 0 || unpaddedLen > padded.length - 2) {
    throw Exception('Invalid padding');
  }
  return padded.sublist(2, 2 + unpaddedLen);
}

Uint8List calculateMac(Uint8List key, Uint8List nonce, Uint8List ciphertext) {
  var hmacSha256 = crypto.Hmac(crypto.sha256, key);
  var mac = hmacSha256.convert([...nonce, ...ciphertext]).bytes;
  return Uint8List.fromList(mac);
}

Map<String, dynamic> parsePayload(String payload) {
  if (payload.isEmpty || payload[0] == '#') {
    throw Exception('Unknown version');
  }

  if (payload.length < 132 || payload.length > 87472) {
    throw Exception('Invalid payload size');
  }

  Uint8List data = base64.decode(payload);

  if (data[0] != 0x02) {
    throw Exception('Unsupported version');
  }

  Uint8List nonce = data.sublist(1, 33);
  Uint8List mac = data.sublist(data.length - 32);
  Uint8List ciphertext = data.sublist(33, data.length - 32);

  return {
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
  };
}

void verifyMac(
    Uint8List hmacKey, Uint8List nonce, Uint8List ciphertext, Uint8List mac) {
  Uint8List calculatedMac = calculateMac(hmacKey, nonce, ciphertext);
  if (!const ListEquality().equals(calculatedMac, mac)) {
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
