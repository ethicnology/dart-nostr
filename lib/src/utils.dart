import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:pointycastle/export.dart';

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

T getRequiredField<T>(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field) || map[field] == null) {
    throw Exception("Missing required field '$field'.");
  }
  if (map[field] is! T) {
    throw Exception("Field '$field' should be of type ${T.toString()}.");
  }
  return map[field] as T;
}

List<int> sha256(List<int> bytes) {
  final hash = SHA256Digest().process(Uint8List.fromList(bytes));
  return hash;
}
