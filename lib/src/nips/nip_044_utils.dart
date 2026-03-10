import 'dart:convert';
import 'dart:typed_data';
import 'package:nostr/src/error.dart';
import 'package:pointycastle/export.dart';

/// Derives ChaCha20 key, ChaCha20 nonce, and HMAC key from a conversation key and nonce.
///
/// [conversationKey] must be exactly 32 bytes.
/// [nonce] must be exactly 32 bytes.
///
/// Throws [CryptoException] if the key or nonce length is invalid.
Map<String, List<int>> deriveMessageKeys(
  List<int> conversationKey,
  List<int> nonce,
) {
  if (conversationKey.length != 32) {
    throw const CryptoException('Invalid conversation key length');
  }
  if (nonce.length != 32) {
    throw const CryptoException('Invalid nonce length');
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

/// Pads [plaintext] to the next power-of-two-derived length.
///
/// The first two bytes of the output encode the original length in big-endian.
/// Throws [CryptoException] if the plaintext length is outside 1..65535.
List<int> pad(List<int> plaintext) {
  final unpaddedLen = plaintext.length;
  if (unpaddedLen < 1 || unpaddedLen > 65535) {
    throw const CryptoException('Invalid plaintext length');
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

/// Calculates the padded length for a given unpadded length.
int calcPaddedLen(int unpaddedLen) {
  final nextPower = 1 << ((unpaddedLen - 1).bitLength);
  final chunk = nextPower <= 256 ? 32 : nextPower ~/ 8;
  if (unpaddedLen <= 32) {
    return 32;
  } else {
    return chunk * ((unpaddedLen - 1) ~/ chunk + 1);
  }
}

/// Encrypts or decrypts [data] using ChaCha20 (IETF variant, 96-bit nonce).
///
/// [forEncryption] selects encryption (`true`) or decryption (`false`).
List<int> chacha20(
  List<int> key,
  List<int> nonce,
  List<int> data,
  bool forEncryption, // encryption (true) or decryption (false).
) {
  final keyParam = KeyParameter(Uint8List.fromList(key));
  final params = ParametersWithIV(keyParam, Uint8List.fromList(nonce));
  final input = Uint8List.fromList(data);
  final output = Uint8List(input.length);

  final cipher = ChaCha7539Engine();
  cipher.init(forEncryption, params);
  cipher.processBytes(input, 0, input.length, output, 0);

  return output;
}

/// Constructs a NIP-44 v2 base64-encoded payload from [nonce], [ciphertext], and [mac].
String constructPayload(List<int> nonce, List<int> ciphertext, List<int> mac) {
  final List<int> payloadBytes = [
    0x02, // Version
    ...nonce,
    ...ciphertext,
    ...mac,
  ];
  return base64.encode(payloadBytes);
}

/// Performs HKDF-extract using HMAC-SHA256.
///
/// [ikm] is the input keying material.
/// [salt] is the optional salt value.
///
/// Returns a 32-byte pseudorandom key.
List<int> hkdfExtract({required List<int> ikm, required List<int> salt}) {
  final u8salt = Uint8List.fromList(salt);
  final u8ikm = Uint8List.fromList(ikm);
  final hmacSha256 = HMac(SHA256Digest(), 64)..init(KeyParameter(u8salt));
  return hmacSha256.process(u8ikm);
}

/// Performs HKDF-expand using HMAC-SHA256.
///
/// [prk] is the pseudorandom key from HKDF-extract.
/// [info] is the context and application-specific information.
/// [length] is the desired output length in bytes.
///
/// Returns the output keying material of the requested [length].
List<int> hkdfExpand({
  required List<int> prk,
  required List<int> info,
  required int length,
}) {
  const hashLen = 32;
  final int n = (length + hashLen - 1) ~/ hashLen;
  final okm = <int>[];
  var previous = <int>[];
  final u8prk = Uint8List.fromList(prk);

  for (var i = 1; i <= n; i++) {
    final hmacSha256 = HMac(SHA256Digest(), 64)..init(KeyParameter(u8prk));
    final data = Uint8List.fromList([
      ...previous,
      ...info,
      i,
    ]);
    previous = hmacSha256.process(data);
    okm.addAll(previous);
  }
  return Uint8List.fromList(okm.sublist(0, length));
}

/// Removes padding from a padded plaintext.
///
/// Throws [CryptoException] if the padding is invalid.
List<int> unpad(List<int> padded) {
  final int unpaddedLen = (padded[0] << 8) + padded[1];
  if (unpaddedLen == 0 || unpaddedLen > padded.length - 2) {
    throw const CryptoException('Invalid padding');
  }
  return padded.sublist(2, 2 + unpaddedLen);
}

/// Computes HMAC-SHA256 over the concatenation of [nonce] and [ciphertext].
///
/// [key] is the HMAC key.
List<int> calculateMac(List<int> key, List<int> nonce, List<int> ciphertext) {
  final u8key = Uint8List.fromList(key);
  final hmacSha256 = HMac(SHA256Digest(), 64)..init(KeyParameter(u8key));
  return hmacSha256.process(Uint8List.fromList([...nonce, ...ciphertext]));
}

/// Parses a NIP-44 base64 payload into its components.
///
/// Throws [CryptoException] if the version is unknown/unsupported or the
/// payload size is invalid.
Map<String, dynamic> parsePayload(String payload) {
  if (payload.isEmpty || payload[0] == '#') {
    throw const CryptoException('Unknown version');
  }

  if (payload.length < 132 || payload.length > 87472) {
    throw const CryptoException('Invalid payload size');
  }

  final data = base64.decode(payload);

  if (data[0] != 0x02) {
    throw const CryptoException('Unsupported version');
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

/// Verifies that the HMAC-SHA256 tag matches the expected [mac].
///
/// Uses constant-time comparison per NIP-44 spec to prevent timing attacks.
/// Throws [CryptoException] if the MAC does not match.
void verifyMac(
  List<int> hmacKey,
  List<int> nonce,
  List<int> ciphertext,
  List<int> mac,
) {
  final calculatedMac = calculateMac(hmacKey, nonce, ciphertext);
  if (calculatedMac.length != mac.length || !_constantTimeEqual(calculatedMac, mac)) {
    throw const CryptoException('Invalid MAC');
  }
}

/// Constant-time comparison of two byte lists.
/// Returns true if equal, false otherwise.
/// Does NOT short-circuit on mismatch — always compares all bytes.
bool _constantTimeEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  int result = 0;
  for (int i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}

/// Ensures a public key has the correct compressed prefix.
///
/// Throws [CryptoException] if the public key format is unrecognizable.
String checkPublicKey(String publicKey) {
  if (publicKey.length == 66 &&
      (publicKey.startsWith('02') || publicKey.startsWith('03'))) {
    return publicKey;
  } else if (publicKey.length > 66 && publicKey.startsWith('04')) {
    return publicKey;
  } else if (publicKey.length == 64) {
    return '02$publicKey';
  }
  throw const CryptoException('Invalid Public Key');
}
