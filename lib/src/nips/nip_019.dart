import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:nostr/src/error.dart';
import 'package:nostr/src/nips/nip_019_utils.dart';

/// Bech32-encoded entities — [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md)
///
/// This NIP standardizes bech32-formatted strings that can be used to display keys,
/// ids and other information in clients. These formats are not meant to be used anywhere
/// in the core protocol, they are only meant for displaying to users, copy-pasting,
/// sharing, rendering QR codes and inputting data.
class Nip19 {
  static const _shareableIdentifiersPrefixes = [
    Nip19Prefix.nprofile,
    Nip19Prefix.nevent,
    Nip19Prefix.naddr
  ];

  /// Decodes a bech32-encoded NIP-19 string into its prefix and hex data.
  ///
  /// The bech32 npub `npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6`
  /// translates to the hex public key `3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d`
  ///
  /// Throws [NostrException] if the payload is a shareable identifier
  /// (nprofile, nevent, naddr) — use [decodeShareableIdentifiers] instead.
  static ({Nip19Prefix prefix, String data}) decode({required String payload}) {
    final decoded = bech32Decode(payload);
    if (_shareableIdentifiersPrefixes.contains(decoded.prefix)) {
      throw NostrException('use ${Nip19.decodeShareableIdentifiers} instead');
    }
    return decoded;
  }

  /// Encodes hex data into a bech32-encoded NIP-19 string.
  ///
  /// The hex public key `3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d`
  /// translates to `npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6`
  ///
  /// Throws [NostrException] if the prefix is a shareable identifier
  /// (nprofile, nevent, naddr) — use [encodeShareableIdentifiers] instead.
  static String encode({
    required Nip19Prefix prefix,
    required String data,
  }) {
    if (_shareableIdentifiersPrefixes.contains(prefix)) {
      throw NostrException('use ${Nip19.encodeShareableIdentifiers} instead');
    }
    return bech32Encode(prefix, data);
  }

  /// Encode shareable identifiers (nprofile, nevent, naddr) as TLV data.
  ///
  /// [prefix] must be one of [Nip19Prefix.nprofile], [Nip19Prefix.nevent],
  /// or [Nip19Prefix.naddr].
  /// [data] is the primary identifier (pubkey, event id, or d-tag value).
  /// [relays] is an optional list of relay URLs.
  /// [author] is an optional pubkey of the event author.
  /// [kind] is an optional event kind number.
  static String encodeShareableIdentifiers({
    required Nip19Prefix prefix,
    required String data,
    List<String>? relays,
    String? author,
    int? kind,
  }) {
    if (!_shareableIdentifiersPrefixes.contains(prefix)) {
      throw NostrException('$prefix not in $_shareableIdentifiersPrefixes');
    }

    // 0: data
    if (prefix == Nip19Prefix.naddr) {
      data = data.codeUnits
          .map((number) => number.toRadixString(16).padLeft(2, '0'))
          .join();
    }
    var result =
        '00${hex.decode(data).length.toRadixString(16).padLeft(2, '0')}$data';

    // 1: relay
    if (relays != null) {
      for (final relay in relays) {
        result = '${result}01';
        final value = relay.codeUnits
            .map((number) => number.toRadixString(16).padLeft(2, '0'))
            .join();
        result =
            '$result${hex.decode(value).length.toRadixString(16).padLeft(2, '0')}$value';
      }
    }

    // 2: author
    if (author != null) {
      result = '${result}02';
      result =
          '$result${hex.decode(author).length.toRadixString(16).padLeft(2, '0')}$author';
    }

    // 3: kind
    if (kind != null) {
      result = '${result}03';
      final byteData = ByteData(4);
      byteData.setUint32(0, kind);
      final value = List.generate(
              byteData.lengthInBytes,
              (index) =>
                  byteData.getUint8(index).toRadixString(16).padLeft(2, '0'))
          .join();
      result =
          '$result${hex.decode(value).length.toRadixString(16).padLeft(2, '0')}$value';
    }
    return bech32Encode(prefix, result, length: result.length + 90);
  }

  /// Decodes a shareable identifier (nprofile, nevent, naddr) from a
  /// bech32-encoded TLV payload.
  ///
  /// For these events, the contents are a binary-encoded list of TLV (type-length-value),
  /// with T and L being 1 byte each (uint8, i.e. a number in the range of 0-255),
  ///  and V being a sequence of bytes of the size indicated by L.
  ///
  /// 0: data depends on the bech32 prefix:
  /// - for nprofile it will be the 32 bytes of the profile public key
  /// - for nevent it will be the 32 bytes of the event id
  /// - for naddr, it is the identifier (the "d" tag) of the event being referenced. For normal replaceable events use an empty string.
  ///
  /// 1: relay for nprofile, nevent and naddr, optionally, a relay in which the entity
  /// (profile or event) is more likely to be found, encoded as ascii this may be included multiple times
  ///
  /// 2: author
  /// - for naddr, the 32 bytes of the pubkey of the event
  /// - for nevent, optionally, the 32 bytes of the pubkey of the event
  ///
  /// 3: kind
  /// - for naddr, the 32-bit unsigned integer of the kind, big-endian
  /// - for nevent, optionally, the 32-bit unsigned integer of the kind, big-endian
  ///
  /// Throws [DeserializationException] if the payload cannot be decoded.
  static ShareableIdentifiers decodeShareableIdentifiers({
    required String payload,
  }) {
    try {
      String data = '';
      final List<String> relays = [];
      String? author;
      int? kind;
      final decoded = bech32Decode(payload, length: payload.length);
      final tlvBytes = hex.decode(decoded.data);

      var index = 0;
      while (index < tlvBytes.length) {
        final type = tlvBytes[index++];
        final length = tlvBytes[index++];

        final value = Uint8List.fromList(tlvBytes.sublist(index, index + length));
        index += length;

        if (type == 0) {
          data = (decoded.prefix == Nip19Prefix.naddr)
              ? String.fromCharCodes(value)
              : hex.encode(value);
        } else if (type == 1) {
          relays.add(String.fromCharCodes(value));
        } else if (type == 2) {
          author = hex.encode(value);
        } else if (type == 3) {
          final byteData = ByteData.sublistView(value);
          kind = byteData.getUint32(0);
        }
      }

      return ShareableIdentifiers(
        prefix: decoded.prefix,
        data: data,
        relays: relays,
        author: author,
        kind: kind,
      );
    } catch (e) {
      throw DeserializationException('Failed to decode shareable entity: $e');
    }
  }
}

/// Represents all the prefixes available for NIP-19 encoding.
///
/// `nrelay` is deprecated and not included.
enum Nip19Prefix {
  /// Secret key prefix.
  nsec,

  /// Public key prefix.
  npub,

  /// Note (event) ID prefix.
  note,

  /// Profile with relay metadata prefix.
  nprofile,

  /// Event with relay metadata prefix.
  nevent,

  /// Addressable event (replaceable) prefix.
  naddr;

  /// Resolves a [Nip19Prefix] from its string [name].
  static Nip19Prefix from(String name) =>
      Nip19Prefix.values.byName(name.toLowerCase());
}

/// Shareable identifiers with extra metadata.
///
/// When sharing a profile or an event, an app may decide to include relay information
/// and other metadata such that other apps can locate and display these entities
/// more easily.
class ShareableIdentifiers {
  /// The NIP-19 prefix indicating the entity type.
  final Nip19Prefix prefix;

  /// The primary identifier (pubkey, event id, or d-tag value).
  final String data;

  /// Relay URLs where the entity is likely to be found.
  List<String> relays;

  /// The pubkey of the event author (for nevent and naddr).
  String? author;

  /// The event kind (for nevent and naddr).
  int? kind;

  /// Creates a [ShareableIdentifiers] with the given fields.
  ShareableIdentifiers({
    required this.prefix,
    required this.data,
    this.relays = const [],
    this.author,
    this.kind,
  });
}
