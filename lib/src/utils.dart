import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:dart_bech32/dart_bech32.dart';

/// generates 32 random bytes converted in hex
String generate64RandomHexChars() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}

/// current unix timestamp in seconds
int currentUnixTimestampSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// takes an npub key and converts it to hex key
String? npubKeyToHex(String npub) {
  try {
    final decoded = bech32.decode(npub);
    if (decoded.prefix == 'npub') {
      final bytes = bech32.fromWords(decoded.words).sublist(0, 32);
      final pubkey = hex.encode(bytes);
      return pubkey;
    }
    return null;
  } catch (e) {
    return null;
  }
}

/// takes an hex key and converts it to npub key
String? hexKeyToNub(String hexkey) {
  try {
    final derivedNPub = bech32.encode(
      Decoded(
        prefix: 'npub',
        words: bech32.toWords(Uint8List.fromList(hex.decode(hexkey))),
      ),
    );

    return derivedNPub;
  } catch (e) {
    return null;
  }
}
