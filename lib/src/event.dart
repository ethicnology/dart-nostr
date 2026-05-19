import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:nostr/src/error.dart';
import 'package:nostr/src/schnorr.dart';
import 'package:nostr/src/utils.dart';

/// The only object type that exists is the event, which has the following format on the wire:
///
/// - "id": "32-bytes hex-encoded sha256 of the the serialized event data"
/// - "pubkey": "32-bytes hex-encoded public key of the event creator",
/// - "created_at": unix timestamp in seconds,
/// - "kind": integer,
/// - "tags": [
///    ["e", "32-bytes hex of the id of another event", "recommended relay URL"],
///    ["p", "32-bytes hex of the key", "recommended relay URL"]
///  ],
/// - "content": "arbitrary string",
/// - "sig": "64-bytes signature of the sha256 hash of the serialized event data, which is the same as the 'id' field"
class Event {
  /// 32-bytes hex-encoded sha256 of the the serialized event data (hex).
  late String id;

  /// 32-bytes hex-encoded public key of the event creator (hex).
  late String pubkey;

  /// Unix timestamp in seconds indicating when the event was created.
  late int createdAt;

  /// The event kind, which determines how the event content and tags
  /// should be interpreted.
  ///
  /// -  0: set_metadata: the content is set to a stringified JSON object {name: username, about: string, picture: url} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
  /// -  1: text_note: the content is set to the text content of a note (anything the user wants to say). Non-plaintext notes should instead use kind 1000-10000 as described in NIP-16.
  /// -  2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
  late int kind;

  /// The tags array can store a tag identifier as the first element of each subarray, plus arbitrary information afterward (always as strings).
  ///
  /// This NIP defines "p" -- meaning "pubkey", which points to a pubkey of someone that is referred to in the event --, and "e" -- meaning "event", which points to the id of an event this event is quoting, replying to or referring to somehow.
  late List<List<String>> tags;

  /// Arbitrary string content of the event.
  String content = "";

  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field.
  late String sig;

  /// Optional subscription identifier, present when the event was received
  /// as part of a subscription response.
  String? subscriptionId;

  /// Default constructor.
  ///
  /// If [verify] is `true` (the default), the event is validated after
  /// construction and an [EventValidationException] is thrown when it is
  /// invalid.
  ///
  ///```dart
  /// String id =
  ///     "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  /// String pubKey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// int createdAt = 1672175320;
  /// int kind = 1;
  /// List<List<String>> tags = [];
  /// String content = "Ceci est une analyse du websocket";
  /// String sig =
  ///     "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";
  ///
  /// Event event = Event(
  ///   id,
  ///   pubKey,
  ///   createdAt,
  ///   kind,
  ///   tags,
  ///   content,
  ///   sig,
  ///   verify: true,
  ///   subscriptionId: null,
  /// );
  ///```
  Event(
    this.id,
    this.pubkey,
    this.createdAt,
    this.kind,
    this.tags,
    this.content,
    this.sig, {
    this.subscriptionId,
    bool verify = true,
  }) {
    pubkey = pubkey.toLowerCase();
    if (verify) _assertValid();
  }

  /// Runs the same checks as [isValid] but throws a typed
  /// [EventValidationException] (with a specific [EventValidationReason])
  /// the first time one fails. Used by the validating constructor;
  /// public so consumers can get the reason without parsing strings.
  void _assertValid() {
    if (createdAt <= 0 || createdAt >= 253402300800 /* year 9999 */) {
      throw EventValidationException(
        'created_at $createdAt is not a valid Unix timestamp (seconds)',
        EventValidationReason.invalidTimestamp,
      );
    }
    final String verifyId = getEventId();
    if (id != verifyId) {
      throw EventValidationException(
        'event id mismatch (claimed=$id, canonical=$verifyId)',
        EventValidationReason.idMismatch,
      );
    }
    try {
      if (!Schnorr.verify(publicKey: pubkey, message: id, signature: sig)) {
        throw EventValidationException(
          'Schnorr signature invalid for pubkey=$pubkey',
          EventValidationReason.invalidSignature,
        );
      }
    } on InvalidKeyException catch (e) {
      throw EventValidationException(
        'malformed pubkey or signature: ${e.message}',
        EventValidationReason.malformedSignature,
      );
    }
  }

  /// Partial constructor, you have to fill the fields yourself.
  ///
  /// By default [verify] is `false`, so no validation is performed.
  ///
  /// ```dart
  /// var partialEvent = Event.partial();
  /// assert(partialEvent.isValid() == false);
  /// partialEvent.createdAt = currentUnixTimestampSeconds();
  /// partialEvent.pubkey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// partialEvent.id = partialEvent.getEventId();
  /// partialEvent.sig = partialEvent.getSignature(
  ///   "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  /// );
  /// assert(partialEvent.isValid() == true);
  /// ```
  factory Event.partial({
    String id = "",
    String pubkey = "",
    int createdAt = 0,
    int kind = 1,
    List<List<String>> tags = const <List<String>>[],
    String content = "",
    String sig = "",
    String? subscriptionId,
    bool verify = false,
  }) {
    return Event(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      verify: verify,
      subscriptionId: subscriptionId,
    );
  }

  /// Instantiate an [Event] from the minimum needed data.
  ///
  /// The [id] and [sig] are computed automatically from the provided
  /// [secretKey].
  ///
  /// ```dart
  ///Event event = Event.from(
  ///  kind: 1,
  ///  content: "",
  ///  secretKey:
  ///      "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  ///);
  ///```
  factory Event.from({
    required int kind,
    required String content,
    required String secretKey,
    int? createdAt,
    List<List<String>> tags = const [],
    String? pubkey,
    String? subscriptionId,
    bool verify = false,
  }) {
    createdAt ??= currentUnixTimestampSeconds();
    pubkey ??= Schnorr.derivePublicKey(secretKey).toLowerCase();

    final id = _processEventId(pubkey, createdAt, kind, tags, content);

    final sig = _processSignature(secretKey, id);

    return Event(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }

  /// Deserializes an event from a JSON map.
  ///
  /// If [verify] is `true` (the default), the signature is validated.
  /// Setting [verify] to `false` skips validation for faster deserialization.
  ///
  /// Throws a [DeserializationException] if any required field is missing
  /// or has the wrong type.
  factory Event.fromMap(Map<String, dynamic> map, {bool verify = true}) {
    final id = getRequiredField<String>(map, 'id');
    final sig = getRequiredField<String>(map, 'sig');
    final pubkey = getRequiredField<String>(map, 'pubkey');
    final createdAt = getRequiredField<int>(map, 'created_at');
    final kind = getRequiredField<int>(map, 'kind');
    final content = getRequiredField<String>(map, 'content');
    final rawTags = getRequiredField<List>(map, 'tags');

    var tags = [<String>[]];
    try {
      tags = rawTags
          .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
          .toList();
    } catch (e) {
      throw DeserializationException("Invalid 'tags' format: $e");
    }

    return Event(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      verify: verify,
    );
  }

  /// Deserializes an event from a JSON string.
  ///
  /// If [verify] is `true` (the default), the signature is validated.
  factory Event.fromJson(String payload, {bool verify = true}) =>
      Event.fromMap(json.decode(payload), verify: verify);

  /// Serializes this event to a [Map].
  Map<String, dynamic> toMap() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig
      };

  /// Serializes this event to a JSON string.
  String toJson() => json.encode(toMap());

  /// Serializes to a Nostr event message for the wire.
  ///
  /// Returns one of:
  /// - `["EVENT", event JSON]`
  /// - `["EVENT", subscription_id, event JSON]`
  String serialize() {
    return json.encode([
      "EVENT",
      if (subscriptionId != null) subscriptionId,
      toMap(),
    ]);
  }

  /// Deserializes a Nostr event message from a JSON-encoded [input].
  ///
  /// Accepts both relay-style `["EVENT", subscription_id, {event}]` and
  /// client-style `["EVENT", {event}]` formats.
  ///
  /// Throws a [DeserializationException] if the payload structure is invalid.
  ///
  /// ```dart
  /// Event event = Event.deserialize([
  ///   "EVENT",
  ///   {
  ///     "id": "67bd60e47d7fdddadebff890143167bcd7b5d28b2c3008eae40e0ac5ba0e6b34",
  ///     "kind": 1,
  ///     "pubkey":
  ///         "36685fa5106b1bc03ae7bea82eded855d8f56c41db4c8bdef8099e1e0f2b2afa",
  ///     "created_at": 1674403511,
  ///     "content":
  ///         "Block 773103 was just confirmed. The total value of all the non-coinbase outputs was 61,549,183,849 sats, or \$14,025,828",
  ///     "tags": [],
  ///     "sig":
  ///         "4912a6850a711a876fd2443771f69e094041f7e832df65646a75c2c77989480cce9b41aa5ea3d055c16fe5beb7d11d3d5fa29b4c4046c150b09393c4d3d16eb4"
  ///   }
  /// ]);
  /// ```
  factory Event.deserialize(String input, {bool verify = true}) {
    final data = json.decode(input);
    Map<String, dynamic> event;
    String? subscriptionId;
    if (data.length == 2) {
      event = data[1] as Map<String, dynamic>;
    } else if (data.length == 3) {
      event = data[2] as Map<String, dynamic>;
      subscriptionId = data[1] as String;
    } else {
      throw const DeserializationException('invalid payload');
    }

    final List<List<String>> tags = (event['tags'] as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();

    return Event(
      event['id'],
      event['pubkey'],
      event['created_at'],
      event['kind'],
      tags,
      event['content'],
      event['sig'],
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }

  /// Computes and returns the event id by SHA-256 hashing the serialized
  /// event data.
  ///
  /// The serialization is done over the UTF-8 JSON-serialized string (with
  /// no white space or line breaks) of the following structure:
  ///
  /// ```json
  /// [0, pubkey, created_at, kind, tags, content]
  /// ```
  String getEventId() {
    // Included for minimum breaking changes
    return _processEventId(
      pubkey,
      createdAt,
      kind,
      tags,
      content,
    );
  }

  // Support for [getEventId]
  static String _processEventId(
    String pubkey,
    int createdAt,
    int kind,
    List<List<String>> tags,
    String content,
  ) {
    final data = [0, pubkey.toLowerCase(), createdAt, kind, tags, content];
    final serializedEvent = json.encode(data);
    final hash = sha256(utf8.encode(serializedEvent));
    return hex.encode(hash);
  }

  /// Signs [id] with [secretKey] using Schnorr signatures (BIP-340).
  ///
  /// Returns a 64-byte hex-encoded signature.
  String getSignature(String secretKey) => _processSignature(secretKey, id);

  // Support for [getSignature]
  static String _processSignature(String secretKey, String id) {
    // aux is the 32-byte random component required by BIP-340; we let
    // Schnorr.sign generate it when omitted.
    return Schnorr.sign(secretKey: secretKey, message: id);
  }

  /// Verifies that this event is valid.
  ///
  /// Checks that:
  /// - The [createdAt] is a valid Unix timestamp in seconds.
  /// - The [id] matches the recomputed event id.
  /// - The [sig] is a valid Schnorr signature over [id] for [pubkey].
  ///
  /// Returns `false` instead of throwing. Use the [Event] constructor
  /// (with default `verify: true`) when you want a typed
  /// [EventValidationException] that carries the specific failure
  /// [EventValidationReason].
  bool isValid() {
    try {
      _assertValid();
      return true;
    } on EventValidationException {
      return false;
    }
  }
}
