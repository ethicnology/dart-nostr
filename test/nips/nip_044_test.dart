import 'dart:convert';
import 'dart:typed_data';

import 'package:elliptic/elliptic.dart' as elliptic;
import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

Uint8List hexToBytes(String hex) {
  if (hex.startsWith('0x')) {
    hex = hex.substring(2);
  }
  if (hex.length % 2 != 0) {
    hex = '0$hex';
  }
  final length = hex.length ~/ 2;
  final bytes = Uint8List(length);
  for (int i = 0; i < length; i++) {
    final byteStr = hex.substring(i * 2, i * 2 + 2);
    bytes[i] = int.parse(byteStr, radix: 16);
  }
  return bytes;
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> assertConversationKeyGeneration(
  String privKeyHex,
  String pubKeyHex,
  String expectedConversationKeyHex,
) async {
  final sharedSecret = Nip44.computeSharedSecret(
    secretKeyHex: privKeyHex,
    publicKeyHex: pubKeyHex,
  );
  final conversationKey =
      Nip44.deriveConversationKey(sharedSecret: sharedSecret);

  final expectedConversationKey = hexToBytes(expectedConversationKeyHex);

  expect(conversationKey, equals(expectedConversationKey),
      reason: 'Conversation key does not match expected value');
}

Future<void> assertCryptPriv(
    String sk1Hex,
    String sk2Hex,
    String expectedConversationKeyHex,
    String nonceHex,
    String plaintext,
    String expectedCiphertext) async {
  // Compute public keys from secret keys
  final ec = elliptic.getS256();
  final sk1 = elliptic.PrivateKey.fromHex(ec, sk1Hex);
  final sk2 = elliptic.PrivateKey.fromHex(ec, sk2Hex);
  final pk1Hex = sk1.publicKey.toHex();
  final pk2Hex = sk2.publicKey.toHex();

  await assertConversationKeyGeneration(
    sk1Hex,
    pk2Hex,
    expectedConversationKeyHex,
  );

  final nonce = hexToBytes(nonceHex);

  final encryptedMessage = await Nip44.encrypt(
    plaintext: plaintext,
    senderSecretKey: sk1Hex,
    recipientPublicKey: pk2Hex,
    customNonce: nonce,
  );

  expect(encryptedMessage, equals(expectedCiphertext),
      reason: 'Encrypted message does not match expected value');

  final decryptedMessage = await Nip44.decrypt(
    payload: encryptedMessage,
    recipientSecretKey: sk2Hex,
    senderPublicKey: pk1Hex,
  );

  expect(decryptedMessage, equals(plaintext),
      reason: 'Decrypted message does not match plaintext');
}

Future<String> decryptMessageWithConversationKey(
  String payload,
  Uint8List conversationKey,
) async {
  final parsed = parsePayload(payload);
  final nonce = parsed['nonce'];
  final ciphertext = parsed['ciphertext'];
  final mac = parsed['mac'];
  final version = parsed['version'];

  if (version != 2) {
    throw FormatException('Unsupported version: $version');
  }

  final keys = deriveMessageKeys(conversationKey, nonce);
  final chachaKey = keys['chachaKey']!;
  final chachaNonce = keys['chachaNonce']!;
  final hmacKey = keys['hmacKey']!;

  verifyMac(hmacKey, nonce, ciphertext, mac);

  final paddedPlaintext = chacha20(chachaKey, chachaNonce, ciphertext, false);

  final plaintextBytes = unpad(paddedPlaintext);

  return utf8.decode(plaintextBytes);
}

Future<void> assertDecryptFail(
  String conversationKeyHex,
  String unused, // Placeholder to match function signature
  String ciphertext,
  String expectedErrorMessage,
) async {
  // Convert conversation key from hex
  final conversationKey = hexToBytes(conversationKeyHex);

  try {
    // Attempt to decrypt the message using the conversation key
    await decryptMessageWithConversationKey(
      ciphertext,
      conversationKey,
    );
    // If no exception is thrown, the test should fail
    fail('Expected decryption to fail, but it succeeded');
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    // Check that the error message contains the expected substring
    expect(e.toString(), contains(expectedErrorMessage),
        reason: 'Error message does not contain expected text');
  }
}

Future<void> assertConversationKeyFail(
  String privKeyHex,
  String pubKeyHex,
  String expectedErrorMessage,
) async {
  try {
    // Attempt to compute shared secret
    final sharedSecret = Nip44.computeSharedSecret(
        secretKeyHex: privKeyHex, publicKeyHex: pubKeyHex);
    // Attempt to derive conversation key
    Nip44.deriveConversationKey(sharedSecret: sharedSecret);
    // If no exception is thrown, the test should fail
    fail('Expected conversation key generation to fail, but it succeeded');
    // ignore: avoid_catches_without_on_clauses
  } catch (e) {
    // Check that the error message contains the expected substring
    expect(e.toString(), contains(expectedErrorMessage),
        reason: 'Error message does not contain expected text');
  }
}

Future<String> encryptMessageWithConversationKey(
  String plaintext,
  Uint8List conversationKey, {
  Uint8List? customNonce,
}) async {
  // Step 1: Generate or Use Custom Nonce
  final nonce = customNonce ?? Uint8List.fromList(generateRandomBytes(32));

  // Step 2: Derive Message Keys
  final keys = deriveMessageKeys(conversationKey, nonce);
  final chachaKey = keys['chachaKey']!;
  final chachaNonce = keys['chachaNonce']!;
  final hmacKey = keys['hmacKey']!;

  // Step 3: Pad Plaintext
  final paddedPlaintext = pad(utf8.encode(plaintext));

  // Step 4: Encrypt
  final ciphertext = chacha20(chachaKey, chachaNonce, paddedPlaintext, true);

  // Step 5: Calculate MAC
  final mac = calculateMac(hmacKey, nonce, ciphertext);

  // Step 6: Construct Payload
  return constructPayload(nonce, ciphertext, mac);
}

Future<void> assertCryptLong(
  String conversationKeyHex,
  String nonceHex,
  String pattern,
  int repeat,
  String expectedPlaintextSha256Hex,
  String expectedPayloadSha256Hex,
) async {
  // Convert inputs from hex
  final conversationKey = hexToBytes(conversationKeyHex);
  final nonce = hexToBytes(nonceHex);

  // Generate plaintext by repeating pattern
  final plaintext = pattern * repeat;

  // Compute SHA256 hash of plaintext
  final plaintextBytes = utf8.encode(plaintext);
  final actualPlaintextSha256 = sha256(plaintextBytes);
  final actualPlaintextSha256Hex =
      bytesToHex(Uint8List.fromList(actualPlaintextSha256));

  // Compare plaintext hash
  expect(actualPlaintextSha256Hex, equals(expectedPlaintextSha256Hex),
      reason: 'Plaintext SHA256 hash does not match expected value');

  // Encrypt plaintext
  final encryptedMessage = await encryptMessageWithConversationKey(
    plaintext,
    conversationKey,
    customNonce: nonce,
  );

  // Compute SHA256 hash of payload
  final payloadBytes = utf8.encode(encryptedMessage);
  final actualPayloadSha256 = sha256(payloadBytes);
  final actualPayloadSha256Hex =
      bytesToHex(Uint8List.fromList(actualPayloadSha256));

  // Compare payload hash
  expect(actualPayloadSha256Hex, equals(expectedPayloadSha256Hex),
      reason: 'Payload SHA256 hash does not match expected value');
}

void assertMessageKeyGeneration(
  String conversationKeyHex,
  String nonceHex,
  String expectedChachaKeyHex,
  String expectedChachaNonceHex,
  String expectedHmacKeyHex,
) {
  final conversationKey = hexToBytes(conversationKeyHex);
  final nonce = hexToBytes(nonceHex);

  final keys = deriveMessageKeys(conversationKey, nonce);
  final chachaKey = keys['chachaKey']!;
  final chachaNonce = keys['chachaNonce']!;
  final hmacKey = keys['hmacKey']!;

  final expectedChachaKey = hexToBytes(expectedChachaKeyHex);
  final expectedChachaNonce = hexToBytes(expectedChachaNonceHex);
  final expectedHmacKey = hexToBytes(expectedHmacKeyHex);

  expect(chachaKey, equals(expectedChachaKey),
      reason: 'ChaCha20 key does not match expected value');
  expect(chachaNonce, equals(expectedChachaNonce),
      reason: 'ChaCha20 nonce does not match expected value');
  expect(hmacKey, equals(expectedHmacKey),
      reason: 'HMAC key does not match expected value');
}

List<int> generateConversationKey(String privKeyHex, String pubKeyHex) {
  final sharedSecret = Nip44.computeSharedSecret(
      secretKeyHex: privKeyHex, publicKeyHex: pubKeyHex);
  final conversationKey =
      Nip44.deriveConversationKey(sharedSecret: sharedSecret);
  return conversationKey;
}

void assertConversationKeyGenerationPub(
    String privKeyHex, String pubKeyHex, String expectedConversationKeyHex) {
  final expectedConversationKey = hexToBytes(expectedConversationKeyHex);
  //final pk = '02$pubKeyHex';
  final actualConversationKey = generateConversationKey(privKeyHex, pubKeyHex);
  expect(actualConversationKey, equals(expectedConversationKey),
      reason: 'Conversation key does not match expected value');
}

void main() {
  test('TestCryptPriv001', () async {
    await assertCryptPriv(
      '0000000000000000000000000000000000000000000000000000000000000001',
      '0000000000000000000000000000000000000000000000000000000000000002',
      'c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d',
      '0000000000000000000000000000000000000000000000000000000000000001',
      'a',
      'AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb',
    );
  });

  test('TestCryptPriv002', () async {
    await assertCryptPriv(
      '0000000000000000000000000000000000000000000000000000000000000002',
      '0000000000000000000000000000000000000000000000000000000000000001',
      'c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d',
      'f00000000000000000000000000000f00000000000000000000000000000000f',
      '🍕🫃',
      'AvAAAAAAAAAAAAAAAAAAAPAAAAAAAAAAAAAAAAAAAAAPSKSK6is9ngkX2+cSq85Th16oRTISAOfhStnixqZziKMDvB0QQzgFZdjLTPicCJaV8nDITO+QfaQ61+KbWQIOO2Yj',
    );
  });

  test('TestCryptPriv003', () async {
    await assertCryptPriv(
      '5c0c523f52a5b6fad39ed2403092df8cebc36318b39383bca6c00808626fab3a',
      '4b22aa260e4acb7021e32f38a6cdf4b673c6a277755bfce287e370c924dc936d',
      '3e2b52a63be47d34fe0a80e34e73d436d6963bc8f39827f327057a9986c20a45',
      'b635236c42db20f021bb8d1cdff5ca75dd1a0cc72ea742ad750f33010b24f73b',
      '表ポあA鷗ŒéＢ逍Üßªąñ丂㐀𠀀',
      'ArY1I2xC2yDwIbuNHN/1ynXdGgzHLqdCrXUPMwELJPc7s7JqlCMJBAIIjfkpHReBPXeoMCyuClwgbT419jUWU1PwaNl4FEQYKCDKVJz+97Mp3K+Q2YGa77B6gpxB/lr1QgoqpDf7wDVrDmOqGoiPjWDqy8KzLueKDcm9BVP8xeTJIxs=',
    );
  });

  test('TestCryptPriv004', () async {
    await assertCryptPriv(
      '8f40e50a84a7462e2b8d24c28898ef1f23359fff50d8c509e6fb7ce06e142f9c',
      'b9b0a1e9cc20100c5faa3bbe2777303d25950616c4c6a3fa2e3e046f936ec2ba',
      'd5a2f879123145a4b291d767428870f5a8d9e5007193321795b40183d4ab8c2b',
      'b20989adc3ddc41cd2c435952c0d59a91315d8c5218d5040573fc3749543acaf',
      'ability🤝的 ȺȾ',
      'ArIJia3D3cQc0sQ1lSwNWakTFdjFIY1QQFc/w3SVQ6yvbG2S0x4Yu86QGwPTy7mP3961I1XqB6SFFTzqDZZavhxoWMj7mEVGMQIsh2RLWI5EYQaQDIePSnXPlzf7CIt+voTD',
    );
  });

  test('TestCryptPriv005', () async {
    await assertCryptPriv(
      '875adb475056aec0b4809bd2db9aa00cff53a649e7b59d8edcbf4e6330b0995c',
      '9c05781112d5b0a2a7148a222e50e0bd891d6b60c5483f03456e982185944aae',
      '3b15c977e20bfe4b8482991274635edd94f366595b1a3d2993515705ca3cedb8',
      '8d4442713eb9d4791175cb040d98d6fc5be8864d6ec2f89cf0895a2b2b72d1b1',
      'pepper👀їжак',
      'Ao1EQnE+udR5EXXLBA2Y1vxb6IZNbsL4nPCJWisrctGxY3AduCS+jTUgAAnfvKafkmpy15+i9YMwCdccisRa8SvzW671T2JO4LFSPX31K4kYUKelSAdSPwe9NwO6LhOsnoJ+',
    );
  });

  test('TestCryptPriv006', () async {
    await assertCryptPriv(
      'eba1687cab6a3101bfc68fd70f214aa4cc059e9ec1b79fdb9ad0a0a4e259829f',
      'dff20d262bef9dfd94666548f556393085e6ea421c8af86e9d333fa8747e94b3',
      '4f1538411098cf11c8af216836444787c462d47f97287f46cf7edb2c4915b8a5',
      '2180b52ae645fcf9f5080d81b1f0b5d6f2cd77ff3c986882bb549158462f3407',
      '( ͡° ͜ʖ ͡°)',
      'AiGAtSrmRfz59QgNgbHwtdbyzXf/PJhogrtUkVhGLzQHv4qhKQwnFQ54OjVMgqCea/Vj0YqBSdhqNR777TJ4zIUk7R0fnizp6l1zwgzWv7+ee6u+0/89KIjY5q1wu6inyuiv',
    );
  });

  test('TestCryptPriv007', () async {
    await assertCryptPriv(
      'd5633530f5bcfebceb5584cfbbf718a30df0751b729dd9a789b9f30c0587d74e',
      'b74e6a341fb134127272b795a08b59250e5fa45a82a2eb4095e4ce9ed5f5e214',
      '75fe686d21a035f0c7cd70da64ba307936e5ca0b20710496a6b6b5f573377bdd',
      'e4cd5f7ce4eea024bc71b17ad456a986a74ac426c2c62b0a15eb5c5c8f888b68',
      'مُنَاقَشَةُ سُبُلِ اِسْتِخْدَامِ اللُّغَةِ فِي النُّظُمِ الْقَائِمَةِ وَفِيم يَخُصَّ التَّطْبِيقَاتُ الْحاسُوبِيَّةُ،',
      'AuTNX3zk7qAkvHGxetRWqYanSsQmwsYrChXrXFyPiItoIBsWu1CB+sStla2M4VeANASHxM78i1CfHQQH1YbBy24Tng7emYW44ol6QkFD6D8Zq7QPl+8L1c47lx8RoODEQMvNCbOk5ffUV3/AhONHBXnffrI+0025c+uRGzfqpYki4lBqm9iYU+k3Tvjczq9wU0mkVDEaM34WiQi30MfkJdRbeeYaq6kNvGPunLb3xdjjs5DL720d61Flc5ZfoZm+CBhADy9D9XiVZYLKAlkijALJur9dATYKci6OBOoc2SJS2Clai5hOVzR0yVeyHRgRfH9aLSlWW5dXcUxTo7qqRjNf8W5+J4jF4gNQp5f5d0YA4vPAzjBwSP/5bGzNDslKfcAH',
    );
  });

  test('TestCryptPriv008', () async {
    await assertCryptPriv(
      'd5633530f5bcfebceb5584cfbbf718a30df0751b729dd9a789b9f30c0587d74e',
      'b74e6a341fb134127272b795a08b59250e5fa45a82a2eb4095e4ce9ed5f5e214',
      '75fe686d21a035f0c7cd70da64ba307936e5ca0b20710496a6b6b5f573377bdd',
      'e4cd5f7ce4eea024bc71b17ad456a986a74ac426c2c62b0a15eb5c5c8f888b68',
      'مُنَاقَشَةُ سُبُلِ اِسْتِخْدَامِ اللُّغَةِ فِي النُّظُمِ الْقَائِمَةِ وَفِيم يَخُصَّ التَّطْبِيقَاتُ الْحاسُوبِيَّةُ،',
      'AuTNX3zk7qAkvHGxetRWqYanSsQmwsYrChXrXFyPiItoIBsWu1CB+sStla2M4VeANASHxM78i1CfHQQH1YbBy24Tng7emYW44ol6QkFD6D8Zq7QPl+8L1c47lx8RoODEQMvNCbOk5ffUV3/AhONHBXnffrI+0025c+uRGzfqpYki4lBqm9iYU+k3Tvjczq9wU0mkVDEaM34WiQi30MfkJdRbeeYaq6kNvGPunLb3xdjjs5DL720d61Flc5ZfoZm+CBhADy9D9XiVZYLKAlkijALJur9dATYKci6OBOoc2SJS2Clai5hOVzR0yVeyHRgRfH9aLSlWW5dXcUxTo7qqRjNf8W5+J4jF4gNQp5f5d0YA4vPAzjBwSP/5bGzNDslKfcAH',
    );
  });

  test('TestCryptPriv009X', () async {
    await assertCryptPriv(
      'd5633530f5bcfebceb5584cfbbf718a30df0751b729dd9a789b9f30c0587d74e',
      'b74e6a341fb134127272b795a08b59250e5fa45a82a2eb4095e4ce9ed5f5e214',
      '75fe686d21a035f0c7cd70da64ba307936e5ca0b20710496a6b6b5f573377bdd',
      '38d1ca0abef9e5f564e89761a86cee04574b6825d3ef2063b10ad75899e4b023',
      'الكل في المجمو عة (5)',
      'AjjRygq++eX1ZOiXYahs7gRXS2gl0+8gY7EK11iZ5LAjbOTrlfrxak5Lki42v2jMPpLSicy8eHjsWkkMtF0i925vOaKG/ZkMHh9ccQBdfTvgEGKzztedqDCAWb5TP1YwU1PsWaiiqG3+WgVvJiO4lUdMHXL7+zKKx8bgDtowzz4QAwI=',
    );
  });

  test('TestCryptPriv010', () async {
    await assertCryptPriv(
      'd5633530f5bcfebceb5584cfbbf718a30df0751b729dd9a789b9f30c0587d74e',
      'b74e6a341fb134127272b795a08b59250e5fa45a82a2eb4095e4ce9ed5f5e214',
      '75fe686d21a035f0c7cd70da64ba307936e5ca0b20710496a6b6b5f573377bdd',
      '4f1a31909f3483a9e69c8549a55bbc9af25fa5bbecf7bd32d9896f83ef2e12e0',
      '𝖑𝖆𝖟𝖞 社會科學院語學研究所',
      'Ak8aMZCfNIOp5pyFSaVbvJryX6W77Pe9MtmJb4PvLhLgh/TsxPLFSANcT67EC1t/qxjru5ZoADjKVEt2ejdx+xGvH49mcdfbc+l+L7gJtkH7GLKpE9pQNQWNHMAmj043PAXJZ++fiJObMRR2mye5VHEANzZWkZXMrXF7YjuG10S1pOU=',
    );
  });

  test('TestCryptPriv011', () async {
    await assertCryptPriv(
      'd5633530f5bcfebceb5584cfbbf718a30df0751b729dd9a789b9f30c0587d74e',
      'b74e6a341fb134127272b795a08b59250e5fa45a82a2eb4095e4ce9ed5f5e214',
      '75fe686d21a035f0c7cd70da64ba307936e5ca0b20710496a6b6b5f573377bdd',
      'a3e219242d85465e70adcd640b564b3feff57d2ef8745d5e7a0663b2dccceb54',
      '🙈 🙉 🙊 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟 Powerلُلُصّبُلُلصّبُررً ॣ ॣh ॣ ॣ冗',
      'AqPiGSQthUZecK3NZAtWSz/v9X0u+HRdXnoGY7LczOtUf05aMF89q1FLwJvaFJYICZoMYgRJHFLwPiOHce7fuAc40kX0wXJvipyBJ9HzCOj7CgtnC1/cmPCHR3s5AIORmroBWglm1LiFMohv1FSPEbaBD51VXxJa4JyWpYhreSOEjn1wd0lMKC9b+osV2N2tpbs+rbpQem2tRen3sWflmCqjkG5VOVwRErCuXuPb5+hYwd8BoZbfCrsiAVLd7YT44dRtKNBx6rkabWfddKSLtreHLDysOhQUVOp/XkE7OzSkWl6sky0Hva6qJJ/V726hMlomvcLHjE41iKmW2CpcZfOedg==',
    );
  });

  test('TestCryptLong001', () async {
    await assertCryptLong(
      '8fc262099ce0d0bb9b89bac05bb9e04f9bc0090acc181fef6840ccee470371ed',
      '326bcb2c943cd6bb717588c9e5a7e738edf6ed14ec5f5344caa6ef56f0b9cff7',
      'x',
      65535,
      '09ab7495d3e61a76f0deb12cb0306f0696cbb17ffc12131368c7a939f12f56d3',
      '90714492225faba06310bff2f249ebdc2a5e609d65a629f1c87f2d4ffc55330a',
    );
  });

  test('TestCryptLong002', () async {
    await assertCryptLong(
      '56adbe3720339363ab9c3b8526ffce9fd77600927488bfc4b59f7a68ffe5eae0',
      'ad68da81833c2a8ff609c3d2c0335fd44fe5954f85bb580c6a8d467aa9fc5dd0',
      '!',
      65535,
      '6af297793b72ae092c422e552c3bb3cbc310da274bd1cf9e31023a7fe4a2d75e',
      '8013e45a109fad3362133132b460a2d5bce235fe71c8b8f4014793fb52a49844',
    );
  });

  test('TestCryptLong003', () async {
    await assertCryptLong(
      '7fc540779979e472bb8d12480b443d1e5eb1098eae546ef2390bee499bbf46be',
      '34905e82105c20de9a2f6cd385a0d541e6bcc10601d12481ff3a7575dc622033',
      '🦄',
      16383,
      'a249558d161b77297bc0cb311dde7d77190f6571b25c7e4429cd19044634a61f',
      'b3348422471da1f3c59d79acfe2fe103f3cd24488109e5b18734cdb5953afd15',
    );
  });

  test('TestConversationKeyFail001', () async {
    // sec1 higher than curve.n
    await assertConversationKeyFail(
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail002', () async {
    // sec1 is 0
    await assertConversationKeyFail(
      '0000000000000000000000000000000000000000000000000000000000000000',
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail003', () async {
    // pub2 is invalid, no sqrt, all-ff
    await assertConversationKeyFail(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364139',
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      'invalid public key X value',
    );
  });

  test('TestConversationKeyFail004', () async {
    // sec1 == curve.n
    await assertConversationKeyFail(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail005', () async {
    // pub2 is invalid, no sqrt
    await assertConversationKeyFail(
      '0000000000000000000000000000000000000000000000000000000000000002',
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail006', () async {
    // pub2 is point of order 3 on twist
    await assertConversationKeyFail(
      '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20',
      '0000000000000000000000000000000000000000000000000000000000000000',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail007', () async {
    // pub2 is point of order 13 on twist
    await assertConversationKeyFail(
      '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20',
      'eb1f7200aecaa86682376fb1c13cd12b732221e774f553b0a0857f88fa20f86d',
      'point is not on curve',
    );
  });

  test('TestConversationKeyFail008', () async {
    // pub2 is point of order 3319 on twist
    await assertConversationKeyFail(
      '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20',
      '709858a4c121e4a84eb59c0ded0261093c71e8ca29efeef21a6161c447bcaf9f',
      'point is not on curve',
    );
  });

  test('TestDecryptFail001', () async {
    await assertDecryptFail(
      'ca2527a037347b91bea0c8a30fc8d9600ffd81ec00038671e3a0f0cb0fc9f642',
      'n o b l e',
      '#Atqupco0WyaOW2IGDKcshwxI9xO8HgD/P8Ddt46CbxDbrhdG8VmJdU0MIDf06CUvEvdnr1cp1fiMtlM/GrE92xAc1K5odTpCzUB+mjXgbaqtntBUbTToSUoT0ovrlPwzGjyp',
      'Unknown version',
    );
  });

  test('TestDecryptFail002', () async {
    await assertDecryptFail(
      '36f04e558af246352dcf73b692fbd3646a2207bd8abd4b1cd26b234db84d9481',
      '⚠️',
      'AK1AjUvoYW3IS7C/BGRUoqEC7ayTfDUgnEPNeWTF/reBZFaha6EAIRueE9D1B1RuoiuFScC0Q94yjIuxZD3JStQtE8JMNacWFs9rlYP+ZydtHhRucp+lxfdvFlaGV/sQlqZz',
      'Unsupported version',
    );
  });

  test('TestDecryptFail003', () async {
    await assertDecryptFail(
      'ca2527a037347b91bea0c8a30fc8d9600ffd81ec00038671e3a0f0cb0fc9f642',
      'n o s t r',
      'Atфupco0WyaOW2IGDKcshwxI9xO8HgD/P8Ddt46CbxDbrhdG8VmJZE0UICD06CUvEvdnr1cp1fiMtlM/GrE92xAc1EwsVCQEgWEu2gsHUVf4JAa3TpgkmFc3TWsax0v6n/Wq',
      'Invalid character (at character 3)',
    );
  });

  test('TestDecryptFail004', () async {
    await assertDecryptFail(
      'cff7bd6a3e29a450fd27f6c125d5edeb0987c475fd1e8d97591e0d4d8a89763c',
      r'¯\_(ツ)_/¯',
      'Agn/l3ULCEAS4V7LhGFM6IGA17jsDUaFCKhrbXDANholyySBfeh+EN8wNB9gaLlg4j6wdBYh+3oK+mnxWu3NKRbSvQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      'Unsupported version: null',
    );
  });

  test('TestDecryptFail005', () async {
    await assertDecryptFail(
      'cfcc9cf682dfb00b11357f65bdc45e29156b69db424d20b3596919074f5bf957',
      '🥎',
      'AmWxSwuUmqp9UsQX63U7OQ6K1thLI69L7G2b+j4DoIr0oRWQ8avl4OLqWZiTJ10vIgKrNqjoaX+fNhE9RqmR5g0f6BtUg1ijFMz71MO1D4lQLQfW7+UHva8PGYgQ1QpHlKgR',
      'Unsupported version: null',
    );
  });

  test('TestDecryptFail006', () async {
    await assertDecryptFail(
      '5254827d29177622d40a7b67cad014fe7137700c3c523903ebbe3e1b74d40214',
      'elliptic-curve cryptography',
      'Anq2XbuLvCuONcr7V0UxTh8FAyWoZNEdBHXvdbNmDZHB573MI7R7rrTYftpqmvUpahmBC2sngmI14/L0HjOZ7lWGJlzdh6luiOnGPc46cGxf08MRC4CIuxx3i2Lm0KqgJ7vA',
      'Unsupported version: null',
    );
  });

  test('TestDecryptFail007', () async {
    await assertDecryptFail(
      'fea39aca9aa8340c3a78ae1f0902aa7e726946e4efcd7783379df8096029c496',
      'noble',
      'An1Cg+O1TIhdav7ogfSOYvCj9dep4ctxzKtZSniCw5MwRrrPJFyAQYZh5VpjC2QYzny5LIQ9v9lhqmZR4WBYRNJ0ognHVNMwiFV1SHpvUFT8HHZN/m/QarflbvDHAtO6pY16',
      'Unsupported version: null',
    );
  });

  test('TestDecryptFail008', () async {
    await assertDecryptFail(
      '0c4cffb7a6f7e706ec94b2e879f1fc54ff8de38d8db87e11787694d5392d5b3f',
      'censorship-resistant and global social network',
      'Am+f1yZnwnOs0jymZTcRpwhDRHTdnrFcPtsBzpqVdD6b2NZDaNm/TPkZGr75kbB6tCSoq7YRcbPiNfJXNch3Tf+o9+zZTMxwjgX/nm3yDKR2kHQMBhVleCB9uPuljl40AJ8kXRD0gjw+aYRJFUMK9gCETZAjjmrsCM+nGRZ1FfNsHr6Z',
      'Unsupported version: null',
    );
  });

  test('TestDecryptFail009', () async {
    await assertDecryptFail(
      '5cd2d13b9e355aeb2452afbd3786870dbeecb9d355b12cb0a3b6e9da5744cd35',
      '0',
      '',
      'Unknown version',
    );
  });

  test('TestDecryptFail010', () async {
    await assertDecryptFail(
      'd61d3f09c7dfe1c0be91af7109b60a7d9d498920c90cbba1e137320fdd938853',
      '1',
      'Ag==',
      'Invalid payload size',
    );
  });

  test('TestDecryptFail011', () async {
    await assertDecryptFail(
      '873bb0fc665eb950a8e7d5971965539f6ebd645c83c08cd6a85aafbad0f0bc47',
      '2',
      'AqxgToSh3H7iLYRJjoWAM+vSv/Y1mgNlm6OWWjOYUClrFF8=',
      'Invalid payload size',
    );
  });

  test('TestDecryptFail012', () async {
    await assertDecryptFail(
      '9f2fef8f5401ac33f74641b568a7a30bb19409c76ffdc5eae2db6b39d2617fbe',
      '3',
      'Ap/2SEZCVFIhYk6qx7nqJxM6TMI1ZoKmAzrO7vBDVJhhuZXWiM20i/tIsbjT0KxkJs2MZjh1oXNYMO9ggfk7i47WQA==',
      'Invalid payload size',
    );
  });

  test('TestConversationKey001', () {
    assertConversationKeyGenerationPub(
      '315e59ff51cb9209768cf7da80791ddcaae56ac9775eb25b6dee1234bc5d2268',
      'c2f9d9948dc8c7c38321e4b85c8558872eafa0641cd269db76848a6073e69133',
      '3dfef0ce2a4d80a25e7a328accf73448ef67096f65f79588e358d9a0eb9013f1',
    );
  });

  test('TestConversationKey002', () {
    assertConversationKeyGenerationPub(
      'a1e37752c9fdc1273be53f68c5f74be7c8905728e8de75800b94262f9497c86e',
      '03bb7947065dde12ba991ea045132581d0954f042c84e06d8c00066e23c1a800',
      '4d14f36e81b8452128da64fe6f1eae873baae2f444b02c950b90e43553f2178b',
    );
  });

  test('TestConversationKey003', () {
    assertConversationKeyGenerationPub(
      '98a5902fd67518a0c900f0fb62158f278f94a21d6f9d33d30cd3091195500311',
      'aae65c15f98e5e677b5050de82e3aba47a6fe49b3dab7863cf35d9478ba9f7d1',
      '9c00b769d5f54d02bf175b7284a1cbd28b6911b06cda6666b2243561ac96bad7',
    );
  });

  test('TestConversationKey004', () {
    assertConversationKeyGenerationPub(
      '86ae5ac8034eb2542ce23ec2f84375655dab7f836836bbd3c54cefe9fdc9c19f',
      '59f90272378089d73f1339710c02e2be6db584e9cdbe86eed3578f0c67c23585',
      '19f934aafd3324e8415299b64df42049afaa051c71c98d0aa10e1081f2e3e2ba',
    );
  });

  test('TestConversationKey005', () {
    assertConversationKeyGenerationPub(
      '2528c287fe822421bc0dc4c3615878eb98e8a8c31657616d08b29c00ce209e34',
      'f66ea16104c01a1c532e03f166c5370a22a5505753005a566366097150c6df60',
      'c833bbb292956c43366145326d53b955ffb5da4e4998a2d853611841903f5442',
    );
  });

  test('TestConversationKey006', () {
    assertConversationKeyGenerationPub(
      '49808637b2d21129478041813aceb6f2c9d4929cd1303cdaf4fbdbd690905ff2',
      '74d2aab13e97827ea21baf253ad7e39b974bb2498cc747cdb168582a11847b65',
      '4bf304d3c8c4608864c0fe03890b90279328cd24a018ffa9eb8f8ccec06b505d',
    );
  });

  test('TestConversationKey007', () {
    assertConversationKeyGenerationPub(
      'af67c382106242c5baabf856efdc0629cc1c5b4061f85b8ceaba52aa7e4b4082',
      'bdaf0001d63e7ec994fad736eab178ee3c2d7cfc925ae29f37d19224486db57b',
      'a3a575dd66d45e9379904047ebfb9a7873c471687d0535db00ef2daa24b391db',
    );
  });

  test('TestConversationKey008', () {
    assertConversationKeyGenerationPub(
      '0e44e2d1db3c1717b05ffa0f08d102a09c554a1cbbf678ab158b259a44e682f1',
      '1ffa76c5cc7a836af6914b840483726207cb750889753d7499fb8b76aa8fe0de',
      'a39970a667b7f861f100e3827f4adbf6f464e2697686fe1a81aeda817d6b8bdf',
    );
  });

  test('TestConversationKey009', () {
    assertConversationKeyGenerationPub(
      '5fc0070dbd0666dbddc21d788db04050b86ed8b456b080794c2a0c8e33287bb6',
      '31990752f296dd22e146c9e6f152a269d84b241cc95bb3ff8ec341628a54caf0',
      '72c21075f4b2349ce01a3e604e02a9ab9f07e35dd07eff746de348b4f3c6365e',
    );
  });

  test('TestConversationKey010', () {
    assertConversationKeyGenerationPub(
      '1b7de0d64d9b12ddbb52ef217a3a7c47c4362ce7ea837d760dad58ab313cba64',
      '24383541dd8083b93d144b431679d70ef4eec10c98fceef1eff08b1d81d4b065',
      'dd152a76b44e63d1afd4dfff0785fa07b3e494a9e8401aba31ff925caeb8f5b1',
    );
  });

  test('TestConversationKey011', () {
    assertConversationKeyGenerationPub(
      'df2f560e213ca5fb33b9ecde771c7c0cbd30f1cf43c2c24de54480069d9ab0af',
      'eeea26e552fc8b5e377acaa03e47daa2d7b0c787fac1e0774c9504d9094c430e',
      '770519e803b80f411c34aef59c3ca018608842ebf53909c48d35250bd9323af6',
    );
  });

  test('TestConversationKey012', () {
    assertConversationKeyGenerationPub(
      'cffff919fcc07b8003fdc63bc8a00c0f5dc81022c1c927c62c597352190d95b9',
      'eb5c3cca1a968e26684e5b0eb733aecfc844f95a09ac4e126a9e58a4e4902f92',
      '46a14ee7e80e439ec75c66f04ad824b53a632b8409a29bbb7c192e43c00bb795',
    );
  });

  test('TestConversationKey013', () {
    assertConversationKeyGenerationPub(
      '64ba5a685e443e881e9094647ddd32db14444bb21aa7986beeba3d1c4673ba0a',
      '50e6a4339fac1f3bf86f2401dd797af43ad45bbf58e0801a7877a3984c77c3c4',
      '968b9dbbfcede1664a4ca35a5d3379c064736e87aafbf0b5d114dff710b8a946',
    );
  });

  test('TestConversationKey014', () {
    assertConversationKeyGenerationPub(
      'dd0c31ccce4ec8083f9b75dbf23cc2878e6d1b6baa17713841a2428f69dee91a',
      'b483e84c1339812bed25be55cff959778dfc6edde97ccd9e3649f442472c091b',
      '09024503c7bde07eb7865505891c1ea672bf2d9e25e18dd7a7cea6c69bf44b5d',
    );
  });

  test('TestConversationKey015', () {
    assertConversationKeyGenerationPub(
      'af71313b0d95c41e968a172b33ba5ebd19d06cdf8a7a98df80ecf7af4f6f0358',
      '2a5c25266695b461ee2af927a6c44a3c598b8095b0557e9bd7f787067435bc7c',
      'fe5155b27c1c4b4e92a933edae23726a04802a7cc354a77ac273c85aa3c97a92',
    );
  });

  test('TestConversationKey016', () {
    assertConversationKeyGenerationPub(
      '6636e8a389f75fe068a03b3edb3ea4a785e2768e3f73f48ffb1fc5e7cb7289dc',
      '514eb2064224b6a5829ea21b6e8f7d3ea15ff8e70e8555010f649eb6e09aec70',
      'ff7afacd4d1a6856d37ca5b546890e46e922b508639214991cf8048ddbe9745c',
    );
  });

  test('TestConversationKey017', () {
    assertConversationKeyGenerationPub(
      '94b212f02a3cfb8ad147d52941d3f1dbe1753804458e6645af92c7b2ea791caa',
      'f0cac333231367a04b652a77ab4f8d658b94e86b5a8a0c472c5c7b0d4c6a40cc',
      'e292eaf873addfed0a457c6bd16c8effde33d6664265697f69f420ab16f6669b',
    );
  });

  test('TestConversationKey018', () {
    assertConversationKeyGenerationPub(
      'aa61f9734e69ae88e5d4ced5aae881c96f0d7f16cca603d3bed9eec391136da6',
      '4303e5360a884c360221de8606b72dd316da49a37fe51e17ada4f35f671620a6',
      '8e7d44fd4767456df1fb61f134092a52fcd6836ebab3b00766e16732683ed848',
    );
  });

  test('TestConversationKey019', () {
    assertConversationKeyGenerationPub(
      '5e914bdac54f3f8e2cba94ee898b33240019297b69e96e70c8a495943a72fc98',
      '5bd097924f606695c59f18ff8fd53c174adbafaaa71b3c0b4144a3e0a474b198',
      'f5a0aecf2984bf923c8cd5e7bb8be262d1a8353cb93959434b943a07cf5644bc',
    );
  });

  test('TestConversationKey020', () {
    assertConversationKeyGenerationPub(
      '8b275067add6312ddee064bcdbeb9d17e88aa1df36f430b2cea5cc0413d8278a',
      '65bbbfca819c90c7579f7a82b750a18c858db1afbec8f35b3c1e0e7b5588e9b8',
      '2c565e7027eb46038c2263563d7af681697107e975e9914b799d425effd248d6',
    );
  });

  test('TestConversationKey021', () {
    assertConversationKeyGenerationPub(
      '1ac848de312285f85e0f7ec208aac20142a1f453402af9b34ec2ec7a1f9c96fc',
      '45f7318fe96034d23ee3ddc25b77f275cc1dd329664dd51b89f89c4963868e41',
      'b56e970e5057a8fd929f8aad9248176b9af87819a708d9ddd56e41d1aec74088',
    );
  });

  test('TestConversationKey022', () {
    assertConversationKeyGenerationPub(
      '295a1cf621de401783d29d0e89036aa1c62d13d9ad307161b4ceb535ba1b40e6',
      '840115ddc7f1034d3b21d8e2103f6cb5ab0b63cf613f4ea6e61ae3d016715cdd',
      'b4ee9c0b9b9fef88975773394f0a6f981ca016076143a1bb575b9ff46e804753',
    );
  });

  test('TestConversationKey023', () {
    assertConversationKeyGenerationPub(
      'a28eed0fe977893856ab9667e06ace39f03abbcdb845c329a1981be438ba565d',
      'b0f38b950a5013eba5ab4237f9ed29204a59f3625c71b7e210fec565edfa288c',
      '9d3a802b45bc5aeeb3b303e8e18a92ddd353375710a31600d7f5fff8f3a7285b',
    );
  });

  test('TestConversationKey024', () {
    assertConversationKeyGenerationPub(
      '7ab65af72a478c05f5c651bdc4876c74b63d20d04cdbf71741e46978797cd5a4',
      'f1112159161b568a9cb8c9dd6430b526c4204bcc8ce07464b0845b04c041beda',
      '943884cddaca5a3fef355e9e7f08a3019b0b66aa63ec90278b0f9fdb64821e79',
    );
  });

  test('TestConversationKey025', () {
    assertConversationKeyGenerationPub(
      '95c79a7b75ba40f2229e85756884c138916f9d103fc8f18acc0877a7cceac9fe',
      'cad76bcbd31ca7bbda184d20cc42f725ed0bb105b13580c41330e03023f0ffb3',
      '81c0832a669eea13b4247c40be51ccfd15bb63fcd1bba5b4530ce0e2632f301b',
    );
  });

  test('TestConversationKey026', () {
    assertConversationKeyGenerationPub(
      'baf55cc2febd4d980b4b393972dfc1acf49541e336b56d33d429bce44fa12ec9',
      '0c31cf87fe565766089b64b39460ebbfdedd4a2bc8379be73ad3c0718c912e18',
      '37e2344da9ecdf60ae2205d81e89d34b280b0a3f111171af7e4391ded93b8ea6',
    );
  });

  test('TestConversationKey027', () {
    assertConversationKeyGenerationPub(
      '6eeec45acd2ed31693c5256026abf9f072f01c4abb61f51cf64e6956b6dc8907',
      'e501b34ed11f13d816748c0369b0c728e540df3755bab59ed3327339e16ff828',
      'afaa141b522ddb27bb880d768903a7f618bb8b6357728cae7fb03af639b946e6',
    );
  });

  test('TestConversationKey028', () {
    assertConversationKeyGenerationPub(
      '261a076a9702af1647fb343c55b3f9a4f1096273002287df0015ba81ce5294df',
      'b2777c863878893ae100fb740c8fab4bebd2bf7be78c761a75593670380a6112',
      '76f8d2853de0734e51189ced523c09427c3e46338b9522cd6f74ef5e5b475c74',
    );
  });

  test('TestConversationKey029', () {
    assertConversationKeyGenerationPub(
      'ed3ec71ca406552ea41faec53e19f44b8f90575eda4b7e96380f9cc73c26d6f3',
      '86425951e61f94b62e20cae24184b42e8e17afcf55bafa58645efd0172624fae',
      'f7ffc520a3a0e9e9b3c0967325c9bf12707f8e7a03f28b6cd69ae92cf33f7036',
    );
  });

  test('TestConversationKey030', () {
    assertConversationKeyGenerationPub(
      '5a788fc43378d1303ac78639c59a58cb88b08b3859df33193e63a5a3801c722e',
      'a8cba2f87657d229db69bee07850fd6f7a2ed070171a06d006ec3a8ac562cf70',
      '7d705a27feeedf78b5c07283362f8e361760d3e9f78adab83e3ae5ce7aeb6409',
    );
  });

  test('TestConversationKey031', () {
    assertConversationKeyGenerationPub(
      '63bffa986e382b0ac8ccc1aa93d18a7aa445116478be6f2453bad1f2d3af2344',
      'b895c70a83e782c1cf84af558d1038e6b211c6f84ede60408f519a293201031d',
      '3a3b8f00d4987fc6711d9be64d9c59cf9a709c6c6481c2cde404bcc7a28f174e',
    );
  });

  test('TestConversationKey032', () {
    assertConversationKeyGenerationPub(
      'e4a8bcacbf445fd3721792b939ff58e691cdcba6a8ba67ac3467b45567a03e5c',
      'b54053189e8c9252c6950059c783edb10675d06d20c7b342f73ec9fa6ed39c9d',
      '7b3933b4ef8189d347169c7955589fc1cfc01da5239591a08a183ff6694c44ad',
    );
  });

  test('TestConversationKey033', () {
    // sec1 = n-2, pub2: random, 0x02
    assertConversationKeyGenerationPub(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364139',
      '0000000000000000000000000000000000000000000000000000000000000002',
      '8b6392dbf2ec6a2b2d5b1477fc2be84d63ef254b667cadd31bd3f444c44ae6ba',
    );
  });

  test('TestConversationKey034', () {
    // sec1 = 2, pub2: rand
    assertConversationKeyGenerationPub(
      '0000000000000000000000000000000000000000000000000000000000000002',
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdeb',
      'be234f46f60a250bef52a5ee34c758800c4ca8e5030bf4cc1a31d37ba2104d43',
    );
  });

  test('TestConversationKey035', () {
    // sec1 == pub2
    assertConversationKeyGenerationPub(
      '0000000000000000000000000000000000000000000000000000000000000001',
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
      '3b4610cb7189beb9cc29eb3716ecc6102f1247e8f3101a03a1787d8908aeb54e',
    );
  });

  test('TestMessageKeyGeneration001', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'e1e6f880560d6d149ed83dcc7e5861ee62a5ee051f7fde9975fe5d25d2a02d72',
      'f145f3bed47cb70dbeaac07f3a3fe683e822b3715edb7c4fe310829014ce7d76',
      'c4ad129bb01180c0933a160c',
      '027c1db445f05e2eee864a0975b0ddef5b7110583c8c192de3732571ca5838c4',
    );
  });

  test('TestMessageKeyGeneration002', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'e1d6d28c46de60168b43d79dacc519698512ec35e8ccb12640fc8e9f26121101',
      'e35b88f8d4a8f1606c5082f7a64b100e5d85fcdb2e62aeafbec03fb9e860ad92',
      '22925e920cee4a50a478be90',
      '46a7c55d4283cb0df1d5e29540be67abfe709e3b2e14b7bf9976e6df994ded30',
    );
  });

  test('TestMessageKeyGeneration003', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'cfc13bef512ac9c15951ab00030dfaf2626fdca638dedb35f2993a9eeb85d650',
      '020783eb35fdf5b80ef8c75377f4e937efb26bcbad0e61b4190e39939860c4bf',
      'd3594987af769a52904656ac',
      '237ec0ccb6ebd53d179fa8fd319e092acff599ef174c1fdafd499ef2b8dee745',
    );
  });

  test('TestMessageKeyGeneration004', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'ea6eb84cac23c5c1607c334e8bdf66f7977a7e374052327ec28c6906cbe25967',
      'ff68db24b34fa62c78ac5ffeeaf19533afaedf651fb6a08384e46787f6ce94be',
      '50bb859aa2dde938cc49ec7a',
      '06ff32e1f7b29753a727d7927b25c2dd175aca47751462d37a2039023ec6b5a6',
    );
  });

  test('TestMessageKeyGeneration005', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '8c2e1dd3792802f1f9f7842e0323e5d52ad7472daf360f26e15f97290173605d',
      '2f9daeda8683fdeede81adac247c63cc7671fa817a1fd47352e95d9487989d8b',
      '400224ba67fc2f1b76736916',
      '465c05302aeeb514e41c13ed6405297e261048cfb75a6f851ffa5b445b746e4b',
    );
  });

  test('TestMessageKeyGeneration006', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '05c28bf3d834fa4af8143bf5201a856fa5fac1a3aee58f4c93a764fc2f722367',
      '1e3d45777025a035be566d80fd580def73ed6f7c043faec2c8c1c690ad31c110',
      '021905b1ea3afc17cb9bf96f',
      '74a6e481a89dcd130aaeb21060d7ec97ad30f0007d2cae7b1b11256cc70dfb81',
    );
  });

  test('TestMessageKeyGeneration007', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '5e043fb153227866e75a06d60185851bc90273bfb93342f6632a728e18a07a17',
      '1ea72c9293841e7737c71567d8120145a58991aaa1c436ef77bf7adb83f882f1',
      '72f69a5a5f795465cee59da8',
      'e9daa1a1e9a266ecaa14e970a84bce3fbbf329079bbccda626582b4e66a0d4c9',
    );
  });

  test('TestMessageKeyGeneration009', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '7be7338eaf06a87e274244847fe7a97f5c6a91f44adc18fcc3e411ad6f786dbf',
      '881e7968a1f0c2c80742ee03cd49ea587e13f22699730f1075ade01931582bf6',
      '6e69be92d61c04a276021565',
      '901afe79e74b19967c8829af23617d7d0ffbf1b57190c096855c6a03523a971b',
    );
  });

  test('TestMessageKeyGeneration010', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '94571c8d590905bad7becd892832b472f2aa5212894b6ce96e5ba719c178d976',
      'f80873dd48466cb12d46364a97b8705c01b9b4230cb3ec3415a6b9551dc42eef',
      '3dda53569cfcb7fac1805c35',
      'e9fc264345e2839a181affebc27d2f528756e66a5f87b04bf6c5f1997047051e',
    );
  });

  test('TestMessageKeyGeneration011', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '13a6ee974b1fd759135a2c2010e3cdda47081c78e771125e4f0c382f0284a8cb',
      'bc5fb403b0bed0d84cf1db872b6522072aece00363178c98ad52178d805fca85',
      '65064239186e50304cc0f156',
      'e872d320dde4ed3487958a8e43b48aabd3ced92bc24bb8ff1ccb57b590d9701a',
    );
  });

  test('TestMessageKeyGeneration012', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '082fecdb85f358367b049b08be0e82627ae1d8edb0f27327ccb593aa2613b814',
      '1fbdb1cf6f6ea816349baf697932b36107803de98fcd805ebe9849b8ad0e6a45',
      '2e605e1d825a3eaeb613db9c',
      'fae910f591cf3c7eb538c598583abad33bc0a03085a96ca4ea3a08baf17c0eec',
    );
  });

  test('TestMessageKeyGeneration013', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '4c19020c74932c30ec6b2d8cd0d5bb80bd0fc87da3d8b4859d2fb003810afd03',
      '1ab9905a0189e01cda82f843d226a82a03c4f5b6dbea9b22eb9bc953ba1370d4',
      'cbb2530ea653766e5a37a83a',
      '267f68acac01ac7b34b675e36c2cef5e7b7a6b697214add62a491bedd6efc178',
    );
  });

  test('TestMessageKeyGeneration014', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '67723a3381497b149ce24814eddd10c4c41a1e37e75af161930e6b9601afd0ff',
      '9ecbd25e7e2e6c97b8c27d376dcc8c5679da96578557e4e21dba3a7ef4e4ac07',
      'ef649fcf335583e8d45e3c2e',
      '04dbbd812fa8226fdb45924c521a62e3d40a9e2b5806c1501efdeba75b006bf1',
    );
  });

  test('TestMessageKeyGeneration015', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '42063fe80b093e8619b1610972b4c3ab9e76c14fd908e642cd4997cafb30f36c',
      '211c66531bbcc0efcdd0130f9f1ebc12a769105eb39608994bcb188fa6a73a4a',
      '67803605a7e5010d0f63f8c8',
      'e840e4e8921b57647369d121c5a19310648105dbdd008200ebf0d3b668704ff8',
    );
  });

  test('TestMessageKeyGeneration016', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'b5ac382a4be7ac03b554fe5f3043577b47ea2cd7cfc7e9ca010b1ffbb5cf1a58',
      'b3b5f14f10074244ee42a3837a54309f33981c7232a8b16921e815e1f7d1bb77',
      '4e62a0073087ed808be62469',
      'c8efa10230b5ea11633816c1230ca05fa602ace80a7598916d83bae3d3d2ccd7',
    );
  });

  test('TestMessageKeyGeneration017', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'e9d1eba47dd7e6c1532dc782ff63125db83042bb32841db7eeafd528f3ea7af9',
      '54241f68dc2e50e1db79e892c7c7a471856beeb8d51b7f4d16f16ab0645d2f1a',
      'a963ed7dc29b7b1046820a1d',
      'aba215c8634530dc21c70ddb3b3ee4291e0fa5fa79be0f85863747bde281c8b2',
    );
  });

  test('TestMessageKeyGeneration018', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'a94ecf8efeee9d7068de730fad8daf96694acb70901d762de39fa8a5039c3c49',
      'c0565e9e201d2381a2368d7ffe60f555223874610d3d91fbbdf3076f7b1374dd',
      '329bb3024461e84b2e1c489b',
      'ac42445491f092481ce4fa33b1f2274700032db64e3a15014fbe8c28550f2fec',
    );
  });

  test('TestMessageKeyGeneration019', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '533605ea214e70c25e9a22f792f4b78b9f83a18ab2103687c8a0075919eaaa53',
      'ab35a5e1e54d693ff023db8500d8d4e79ad8878c744e0eaec691e96e141d2325',
      '653d759042b85194d4d8c0a7',
      'b43628e37ba3c31ce80576f0a1f26d3a7c9361d29bb227433b66f49d44f167ba',
    );
  });

  test('TestMessageKeyGeneration020', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '7f38df30ceea1577cb60b355b4f5567ff4130c49e84fed34d779b764a9cc184c',
      'a37d7f211b84a551a127ff40908974eb78415395d4f6f40324428e850e8c42a3',
      'b822e2c959df32b3cb772a7c',
      '1ba31764f01f69b5c89ded2d7c95828e8052c55f5d36f1cd535510d61ba77420',
    );
  });

  test('TestMessageKeyGeneration021', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '11b37f9dbc4d0185d1c26d5f4ed98637d7c9701fffa65a65839fa4126573a4e5',
      '964f38d3a31158a5bfd28481247b18dd6e44d69f30ba2a40f6120c6d21d8a6ba',
      '5f72c5b87c590bcd0f93b305',
      '2fc4553e7cedc47f29690439890f9f19c1077ef3e9eaeef473d0711e04448918',
    );
  });

  test('TestMessageKeyGeneration022', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '8be790aa483d4cdd843189f71f135b3ec7e31f381312c8fe9f177aab2a48eafa',
      '95c8c74d633721a131316309cf6daf0804d59eaa90ea998fc35bac3d2fbb7a94',
      '409a7654c0e4bf8c2c6489be',
      '21bb0b06eb2b460f8ab075f497efa9a01c9cf9146f1e3986c3bf9da5689b6dc4',
    );
  });

  test('TestMessageKeyGeneration023', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '19fd2a718ea084827d6bd73f509229ddf856732108b59fc01819f611419fd140',
      'cc6714b9f5616c66143424e1413d520dae03b1a4bd202b82b0a89b0727f5cdc8',
      '1b7fd2534f015a8f795d8f32',
      '2bef39c4ce5c3c59b817e86351373d1554c98bc131c7e461ed19d96cfd6399a0',
    );
  });

  test('TestMessageKeyGeneration024', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '3c2acd893952b2f6d07d8aea76f545ca45961a93fe5757f6a5a80811d5e0255d',
      'c8de6c878cb469278d0af894bc181deb6194053f73da5014c2b5d2c8db6f2056',
      '6ffe4f1971b904a1b1a81b99',
      'df1cd69dd3646fca15594284744d4211d70e7d8472e545d276421fbb79559fd4',
    );
  });

  test('TestMessageKeyGeneration025', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '7dbea4cead9ac91d4137f1c0a6eebb6ba0d1fb2cc46d829fbc75f8d86aca6301',
      'c8e030f6aa680c3d0b597da9c92bb77c21c4285dd620c5889f9beba7446446b0',
      'a9b5a67d081d3b42e737d16f',
      '355a85f551bc3cce9a14461aa60994742c9bbb1c81a59ca102dc64e61726ab8e',
    );
  });

  test('TestMessageKeyGeneration026', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '45422e676cdae5f1071d3647d7a5f1f5adafb832668a578228aa1155a491f2f3',
      '758437245f03a88e2c6a32807edfabff51a91c81ca2f389b0b46f2c97119ea90',
      '263830a065af33d9c6c5aa1f',
      '7c581cf3489e2de203a95106bfc0de3d4032e9d5b92b2b61fb444acd99037e17',
    );
  });

  test('TestMessageKeyGeneration027', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'babc0c03fad24107ad60678751f5db2678041ff0d28671ede8d65bdf7aa407e9',
      'bd68a28bd48d9ffa3602db72c75662ac2848a0047a313d2ae2d6bc1ac153d7e9',
      'd0f9d2a1ace6c758f594ffdd',
      'eb435e3a642adfc9d59813051606fc21f81641afd58ea6641e2f5a9f123bb50a',
    );
  });

  test('TestMessageKeyGeneration028', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '7a1b8aac37d0d20b160291fad124ab697cfca53f82e326d78fef89b4b0ea8f83',
      '9e97875b651a1d30d17d086d1e846778b7faad6fcbc12e08b3365d700f62e4fe',
      'ccdaad5b3b7645be430992eb',
      '6f2f55cf35174d75752f63c06cc7cbc8441759b142999ed2d5a6d09d263e1fc4',
    );
  });

  test('TestMessageKeyGeneration029', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '8370e4e32d7e680a83862cab0da6136ef607014d043e64cdf5ecc0c4e20b3d9a',
      '1472bed5d19db9c546106de946e0649cd83cc9d4a66b087a65906e348dcf92e2',
      'ed02dece5fc3a186f123420b',
      '7b3f7739f49d30c6205a46b174f984bb6a9fc38e5ccfacef2dac04fcbd3b184e',
    );
  });

  test('TestMessageKeyGeneration030', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '9f1c5e8a29cd5677513c2e3a816551d6833ee54991eb3f00d5b68096fc8f0183',
      '5e1a7544e4d4dafe55941fcbdf326f19b0ca37fc49c4d47e9eec7fb68cde4975',
      '7d9acb0fdc174e3c220f40de',
      'e265ab116fbbb86b2aefc089a0986a0f5b77eda50c7410404ad3b4f3f385c7a7',
    );
  });

  test('TestMessageKeyGeneration031', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      'c385aa1c37c2bfd5cc35fcdbdf601034d39195e1cabff664ceb2b787c15d0225',
      '06bf4e60677a13e54c4a38ab824d2ef79da22b690da2b82d0aa3e39a14ca7bdd',
      '26b450612ca5e905b937e147',
      '22208152be2b1f5f75e6bfcc1f87763d48bb7a74da1be3d102096f257207f8b3',
    );
  });

  test('TestMessageKeyGeneration032', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '3ff73528f88a50f9d35c0ddba4560bacee5b0462d0f4cb6e91caf41847040ce4',
      '850c8a17a23aa761d279d9901015b2bbdfdff00adbf6bc5cf22bd44d24ecabc9',
      '4a296a1fb0048e5020d3b129',
      'b1bf49a533c4da9b1d629b7ff30882e12d37d49c19abd7b01b7807d75ee13806',
    );
  });

  test('TestMessageKeyGeneration033', () async {
    assertMessageKeyGeneration(
      'a1a3d60f3470a8612633924e91febf96dc5366ce130f658b1f0fc652c20b3b54',
      '2dcf39b9d4c52f1cb9db2d516c43a7c6c3b8c401f6a4ac8f131a9e1059957036',
      '17f8057e6156ba7cc5310d01eda8c40f9aa388f9fd1712deb9511f13ecc37d27',
      'a8188daff807a1182200b39d',
      '47b89da97f68d389867b5d8a2d7ba55715a30e3d88a3cc11f3646bc2af5580ef',
    );
  });
}
