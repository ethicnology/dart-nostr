import 'dart:convert';
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
class Bech32Entity {
  static const _shareableIdentifiersPrefixes = [
    Nip19Prefix.nprofile,
    Nip19Prefix.nevent,
    Nip19Prefix.naddr
  ];

  /// Maximum bech32 string length. NIP-19 says strings SHOULD be limited
  /// to 5000 chars; this library enforces it as a hard cap on encode and
  /// decode to avoid pathological inputs.
  static const int _maxBech32Length = 5000;

  /// Decodes a bech32-encoded NIP-19 string into its prefix and hex data.
  ///
  /// The bech32 npub `npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6`
  /// translates to the hex public key `3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d`
  ///
  /// Throws [NostrException] if the payload is a shareable identifier
  /// (nprofile, nevent, naddr) — use [decodeShareableIdentifiers] instead.
  /// Throws [DeserializationException] if the payload exceeds the 5000-char
  /// soft limit.
  static ({Nip19Prefix prefix, String data}) decode({required String payload}) {
    _assertLength(payload);
    final decoded = bech32Decode(payload);
    if (_shareableIdentifiersPrefixes.contains(decoded.prefix)) {
      throw WrongDecodeMethodException('Bech32Entity.decodeShareableIdentifiers');
    }
    return decoded;
  }

  /// Auto-dispatching decode that works for any NIP-19 prefix.
  ///
  /// Returns a [ShareableIdentifierData] for nprofile/nevent/naddr and for
  /// the simple types (nsec/npub/note) returns a [ShareableIdentifierData]
  /// with an empty `relays` list, `null` `author`, and `null` `kind`.
  ///
  /// Useful when consumers receive an unknown-shape `nostr:` URI and want
  /// a uniform result type without branching on prefix.
  ///
  /// Throws [DeserializationException] if the payload cannot be decoded.
  static ShareableIdentifierData decodeAny({required String payload}) {
    _assertLength(payload);
    // Probe with the actual payload length — bech32's default cap is 90,
    // which rejects any real nprofile/nevent/naddr that carries a relay URL.
    final probe = bech32Decode(payload, length: payload.length);
    if (_shareableIdentifiersPrefixes.contains(probe.prefix)) {
      return decodeShareableIdentifiers(payload: payload);
    }
    return ShareableIdentifierData(prefix: probe.prefix, data: probe.data);
  }

  static void _assertLength(String payload) {
    if (payload.length > _maxBech32Length) {
      throw const DeserializationException(
        'bech32 payload exceeds NIP-19 soft cap',
      );
    }
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
      throw WrongDecodeMethodException('Bech32Entity.encodeShareableIdentifiers');
    }
    final encoded = bech32Encode(prefix, data);
    _assertLength(encoded);
    return encoded;
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
      throw WrongPrefixException(
        prefix.name,
        _shareableIdentifiersPrefixes.map((p) => p.name).toList(),
      );
    }

    // naddr addresses an addressable event and is meaningless without both
    // the author's pubkey (type 2) and the event kind (type 3). nostr-tools
    // and rust-nostr enforce this; matching them prevents producing naddrs
    // that decode to incomplete data.
    if (prefix == Nip19Prefix.naddr) {
      if (author == null) {
        throw MissingTlvException(2, 'author pubkey');
      }
      if (kind == null) {
        throw MissingTlvException(3, 'event kind');
      }
    }

    // 0: data
    //
    // For naddr the value is the `d`-tag string. NIP-19 leaves the byte
    // encoding unspecified, but rust-nostr and nostr-tools both use UTF-8,
    // so we follow suit for cross-impl interop.
    if (prefix == Nip19Prefix.naddr) {
      data = hex.encode(utf8.encode(data));
    }
    var result =
        '00${hex.decode(data).length.toRadixString(16).padLeft(2, '0')}$data';

    // 1: relay
    //
    // NIP-19 says relays are "encoded as ascii". ASCII is a subset of UTF-8,
    // so UTF-8 encoding is spec-compatible for any valid relay URL and also
    // matches what rust-nostr / nostr-tools do.
    if (relays != null) {
      for (final relay in relays) {
        result = '${result}01';
        final value = hex.encode(utf8.encode(relay));
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
    final encoded = bech32Encode(prefix, result, length: result.length + 90);
    _assertLength(encoded);
    return encoded;
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
  static ShareableIdentifierData decodeShareableIdentifiers({
    required String payload,
  }) {
    _assertLength(payload);
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
          // naddr type-0 carries the `d`-tag string; nprofile/nevent
          // type-0 carries 32 raw bytes (hex-encode for the caller).
          data = (decoded.prefix == Nip19Prefix.naddr)
              ? utf8.decode(value)
              : hex.encode(value);
        } else if (type == 1) {
          // Relays are ASCII per spec; UTF-8 decode is a strict superset
          // that round-trips with the encode path.
          relays.add(utf8.decode(value));
        } else if (type == 2) {
          author = hex.encode(value);
        } else if (type == 3) {
          final byteData = ByteData.sublistView(value);
          kind = byteData.getUint32(0);
        }
      }

      return ShareableIdentifierData(
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
class ShareableIdentifierData {
  /// The NIP-19 prefix indicating the entity type.
  final Nip19Prefix prefix;

  /// The primary identifier (pubkey, event id, or d-tag value).
  final String data;

  /// Relay URLs where the entity is likely to be found.
  final List<String> relays;

  /// The pubkey of the event author (for nevent and naddr).
  final String? author;

  /// The event kind (for nevent and naddr).
  final int? kind;

  /// Creates a [ShareableIdentifierData] with the given fields.
  const ShareableIdentifierData({
    required this.prefix,
    required this.data,
    this.relays = const [],
    this.author,
    this.kind,
  });
}

typedef Nip19 = Bech32Entity;
typedef ShareableIdentifiers = ShareableIdentifierData;
