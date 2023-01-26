import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:json_annotation/json_annotation.dart';
import 'package:nostr/src/utils.dart';

part 'event.g.dart';

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
@JsonSerializable()
class Event {
  /// 32-bytes hex-encoded sha256 of the the serialized event data (hex)
  late final String id;

  /// 32-bytes hex-encoded public key of the event creator (hex)
  late final String pubkey;

  /// unix timestamp in seconds
  @JsonKey(
    name: 'created_at',
  )
  int createdAt;

  /// -  0: set_metadata: the content is set to a stringified JSON object {name: <username>, about: <string>, picture: <url, string>} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
  /// -  1: text_note: the content is set to the text content of a note (anything the user wants to say). Non-plaintext notes should instead use kind 1000-10000 as described in NIP-16.
  /// -  2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
  final int kind;

  /// The tags array can store a tag identifier as the first element of each subarray, plus arbitrary information afterward (always as strings).
  ///
  /// This NIP defines "p" — meaning "pubkey", which points to a pubkey of someone that is referred to in the event —, and "e" — meaning "event", which points to the id of an event this event is quoting, replying to or referring to somehow.
  final List<List<String>> tags;

  /// arbitrary string
  String content;

  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  late final String sig;

  /// subscription_id is a random string that should be used to represent a subscription.
  @JsonKey(includeIfNull: false, toJson: null)
  String? subscriptionId;

  Event({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    this.content = '',
    required this.sig,
    this.subscriptionId,
  });

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  Map<String, dynamic> toJson() => _$EventToJson(this);

  /// To obtain the event.id, we sha256 the serialized event.
  /// The serialization is done over the UTF-8 JSON-serialized string (with no white space or line breaks) of the following structure:
  ///
  ///[
  ///  0,
  ///  <pubkey, as a (lowercase) hex string>,
  ///  <created_at, as a number>,
  ///  <kind, as a number>,
  ///  <tags, as an array of arrays of non-null strings>,
  ///  <content, as a string>
  ///]
  String getEventId() {
    List data = [0, pubkey.toLowerCase(), createdAt, kind, tags, content];
    String serializedEvent = json.encode(data);
    List<int> hash = sha256.convert(utf8.encode(serializedEvent)).bytes;
    return hex.encode(hash);
  }

  /// Each user has a keypair. Signatures, public key, and encodings are done according to the Schnorr signatures standard for the curve secp256k1
  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  String getSignature(String privateKey) {
    /// aux must be 32-bytes random bytes, generated at signature time.
    /// https://github.com/nbd-wtf/dart-bip340/blob/master/lib/src/bip340.dart#L10
    String aux = generate64RandomHexChars();
    return bip340.sign(privateKey, id, aux);
  }

  /// Serialize to nostr event message
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  String serialize() {
    if (subscriptionId != null) {
      return jsonEncode(["EVENT", subscriptionId, toJson()]);
    } else {
      return jsonEncode(["EVENT", toJson()]);
    }
  }

  /// Deserialize a nostr event message
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  factory Event.deserialize(input) {
    Map<String, dynamic> json = {};
    if (input.length == 2) {
      json = input[1] as Map<String, dynamic>;

      final event = _$EventFromJson(json);

      return event;
    } else if (input.length == 3) {
      json = input[2] as Map<String, dynamic>;
      json['subscriptionId'] = input[1];

      final event = _$EventFromJson(json);

      return event;
    } else {
      throw Exception('invalid input');
    }
  }

  /// Instanciate Event object from the minimum available data
  Event.from(
      {this.createdAt = 0,
      required this.kind,
      required this.tags,
      required this.content,
      required String privkey,
      this.subscriptionId}) {
    if (createdAt == 0) {
      createdAt = currentUnixTimestampSeconds();
    } else {
      createdAt = createdAt;
    }
    assert(createdAt.toString().length == 10);
    assert(createdAt <= currentUnixTimestampSeconds());
    pubkey = bip340.getPublicKey(privkey).toLowerCase();
    id = getEventId();
    sig = getSignature(privkey);
  }
}
