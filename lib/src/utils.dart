import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:nostr/src/error.dart';
import 'package:pointycastle/export.dart';

/// A single Nostr event tag — an ordered list of strings whose first
/// element is the tag name and remaining elements are the value(s).
typedef Tag = List<String>;

/// A collection of [Tag]s as carried on a Nostr event.
typedef Tags = List<Tag>;

/// Generates [bytes] random bytes and returns them as a hex string.
/// Defaults to 32 bytes (64 hex chars).
String generateRandomHex({int bytes = 32}) {
  return hex.encode(generateRandomBytes(bytes));
}

/// Current unix timestamp in seconds
int currentUnixTimestampSeconds() {
  return DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// Generates the requested quantity of random secure bytes
List<int> generateRandomBytes(int quantity) {
  final random = Random.secure();
  return List<int>.generate(quantity, (i) => random.nextInt(256));
}

/// Returns the value of [field] from [map], or throws a
/// [DeserializationException] if the field is missing, null, or the
/// wrong type.
T getRequiredField<T>(Map<String, dynamic> map, String field) {
  if (!map.containsKey(field) || map[field] == null) {
    throw DeserializationException("Missing required field '$field'.");
  }
  if (map[field] is! T) {
    throw DeserializationException("Field '$field' should be of type $T.");
  }
  return map[field] as T;
}

/// Computes the SHA-256 hash of [bytes].
List<int> sha256(List<int> bytes) {
  final hash = SHA256Digest().process(Uint8List.fromList(bytes));
  return hash;
}

/// Finds the first value for a tag with the given [name].
String? findTagValue(List<List<String>> tags, String name) {
  for (final tag in tags) {
    if (tag.isNotEmpty && tag[0] == name && tag.length > 1) return tag[1];
  }
  return null;
}

/// Finds all values for tags with the given [name].
List<String> findAllTagValues(List<List<String>> tags, String name) {
  return tags
      .where((t) => t.isNotEmpty && t[0] == name && t.length > 1)
      .map((t) => t[1])
      .toList();
}
