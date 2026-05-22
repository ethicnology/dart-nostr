import 'package:bech32/bech32.dart';
import 'package:convert/convert.dart';
import 'package:nostr/nostr.dart';

/// Encodes hex data into a bech32 string with the given [prefix].
///
/// [hexData] is the hex-encoded data to encode.
/// [length] is an optional maximum length for the bech32 output.
///
/// Returns the bech32-encoded string. Throws [DeserializationException]
/// if [hexData] is not a valid hex string or if the underlying bech32
/// encoder rejects the payload — so callers only need to catch
/// [NostrException].
String bech32Encode(Nip19Prefix prefix, String hexData, {int? length}) {
  try {
    final data = hex.decode(hexData);
    final convertedData = _convertBits(data, 8, 5, true);
    final bech32Data = Bech32(prefix.name, convertedData);
    if (length != null) {
      return bech32.encode(bech32Data, length);
    }
    return bech32.encode(bech32Data);
  } on DeserializationException {
    rethrow;
  } on Object catch (e) {
    // Only surface the underlying exception's runtime type, not its
    // message — `package:bech32` errors like `MixedCase` echo the raw
    // input back in their message, which could leak secret material
    // (e.g. an nsec hex passed by a confused caller) through logs.
    throw DeserializationException('bech32 encode failed: ${e.runtimeType}');
  }
}

/// Decodes a bech32 string into its prefix and hex data.
///
/// [bech32Data] is the bech32-encoded string to decode.
/// [length] is an optional maximum length for decoding.
///
/// Returns a record with the [Nip19Prefix] and hex-encoded data.
/// Throws [DeserializationException] for any malformed input — bad
/// checksum, wrong separator position, mixed case, unknown HRP, etc.
/// The underlying `package:bech32` and enum-lookup failures are wrapped
/// so callers only need to catch [NostrException].
({Nip19Prefix prefix, String data}) bech32Decode(
  String bech32Data, {
  int? length,
}) {
  try {
    final decodedData = length != null
        ? bech32.decode(bech32Data, length)
        : bech32.decode(bech32Data);
    final convertedData = _convertBits(decodedData.data, 5, 8, false);
    final hexData = hex.encode(convertedData);
    return (prefix: Nip19Prefix.from(decodedData.hrp), data: hexData);
  } on DeserializationException {
    rethrow;
  } on Object catch (e) {
    // Don't surface the underlying message — `package:bech32`'s
    // `MixedCase` error embeds the raw input, which would leak any
    // secret accidentally passed here (e.g. an nsec) through logs.
    throw DeserializationException('bech32 decode failed: ${e.runtimeType}');
  }
}

List<int> _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
  var acc = 0;
  var bits = 0;
  final maxv = (1 << toBits) - 1;
  final result = <int>[];

  for (final value in data) {
    if (value < 0 || value >> fromBits != 0) {
      throw DeserializationException('Invalid value: $value');
    }
    acc = (acc << fromBits) | value;
    bits += fromBits;

    while (bits >= toBits) {
      bits -= toBits;
      result.add((acc >> bits) & maxv);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
  } else if (bits >= fromBits || ((acc << (toBits - bits)) & maxv) != 0) {
    throw const DeserializationException('Invalid data');
  }

  return result;
}
