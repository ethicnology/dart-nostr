import 'dart:math';

import 'package:convert/convert.dart';

/// generates 32 random bytes converted in hex
String generate64RandomHexChars() {
  final randomBytes = generateRandomBytes(32);
  return hex.encode(randomBytes);
}

/// current unix timestamp in seconds
int currentUnixTimestampSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// generates the requested quantity of random secure bytes
List<int> generateRandomBytes(int quantity) {
  final random = Random.secure();
  return List<int>.generate(quantity, (i) => random.nextInt(256));
}
