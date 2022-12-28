import 'dart:math';

import 'package:convert/convert.dart';

/// generate 32 random bytes
String generate32RandomBytes() {
  final random = Random.secure();
  final randomBytes = List<int>.generate(32, (i) => random.nextInt(256));
  return hex.encode(randomBytes);
}

/// current unix timestamp in seconds
int currentUnixSecondsTimestamp() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
