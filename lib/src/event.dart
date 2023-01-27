import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:bip340/bip340.dart' as bip340;
import 'package:nostr/src/utils.dart';
import 'package:json_annotation/json_annotation.dart';

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
  late String id;

  /// 32-bytes hex-encoded public key of the event creator (hex)
  late String pubkey;

  /// unix timestamp in seconds
  @JsonKey(
    name: 'created_at',
  )
  late int createdAt;

  /// -  0: set_metadata: the content is set to a stringified JSON object {name: <username>, about: <string>, picture: <url, string>} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
  /// -  1: text_note: the content is set to the text content of a note (anything the user wants to say). Non-plaintext notes should instead use kind 1000-10000 as described in NIP-16.
  /// -  2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
  late int kind;

  /// The tags array can store a tag identifier as the first element of each subarray, plus arbitrary information afterward (always as strings).
  ///
  /// This NIP defines "p" — meaning "pubkey", which points to a pubkey of someone that is referred to in the event —, and "e" — meaning "event", which points to the id of an event this event is quoting, replying to or referring to somehow.
  late List<List<String>> tags;

  /// arbitrary string
  String content = "";

  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  late String sig;

  /// subscription_id is a random string that should be used to represent a subscription.
  @JsonKey(includeIfNull: false, toJson: null)
  String? subscriptionId;

  /// Default constructor
  Event(
    this.id,
    this.pubkey,
    this.createdAt,
    this.kind,
    this.tags,
    this.content,
    this.sig,
  ) {
    assert(createdAt.toString().length == 10);
    assert(createdAt <= currentUnixTimestampSeconds());
    pubkey = pubkey.toLowerCase();
    String id = getEventId();
    assert(this.id == id);
    assert(bip340.verify(pubkey, id, sig));
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
    }
    assert(createdAt.toString().length == 10);
    assert(createdAt <= currentUnixTimestampSeconds());
    pubkey = bip340.getPublicKey(privkey).toLowerCase();
    id = getEventId();
    sig = getSignature(privkey);
  }

  /// Deserialize an event from a JSON
  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  /// Serialize an event in JSON
  Map<String, dynamic> toJson() => _$EventToJson(this);

  Map<String, dynamic> toJson2() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig
      };

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
    } else if (input.length == 3) {
      json = input[2] as Map<String, dynamic>;
      json['subscriptionId'] = input[1];
    } else {
      throw Exception('invalid input');
    }
    return _$EventFromJson(json);
  }

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
    // FIXME since json_annotation getEventId generates sometimes wrong ID
    print('$id $pubkey $createdAt $kind $tags $content $sig');
    List data = [0, pubkey.toLowerCase(), createdAt, kind, tags, content];
    String serializedEvent = json.encode(data);
    List<int> hash = sha256.convert(utf8.encode(serializedEvent)).bytes;
    var tmp = hex.encode(hash);
    print(tmp);
    return tmp;
  }

  /// Each user has a keypair. Signatures, public key, and encodings are done according to the Schnorr signatures standard for the curve secp256k1
  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  String getSignature(String privateKey) {
    /// aux must be 32-bytes random bytes, generated at signature time.
    /// https://github.com/nbd-wtf/dart-bip340/blob/master/lib/src/bip340.dart#L10
    String aux = generate64RandomHexChars();
    return bip340.sign(privateKey, id, aux);
  }
}
