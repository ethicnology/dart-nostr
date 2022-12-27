import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:bip340/bip340.dart';
import 'package:nostr/src/utils.dart';

class Event {
  late String id;
  late String pubkey;
  late int createdAt;
  int kind;
  List<List<String>> tags;
  String content;
  late String sig;

  Event(
    this.id,
    this.pubkey,
    this.createdAt,
    this.kind,
    this.tags,
    this.content,
    this.sig,
  ) {
    String id = getEventId();
    assert(this.id == id);
    assert(verify(pubkey, id, sig));
  }

  Event.from({
    this.createdAt = 0,
    required this.kind,
    required this.tags,
    required this.content,
    required String privkey,
  }) {
    pubkey = getPublicKey(privkey);
    id = getEventId();
    if (createdAt == 0) {
      createdAt = DateTime.now().millisecondsSinceEpoch;
    }
    sig = getSignature(privkey);
  }

  Event.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        pubkey = json['pubkey'],
        createdAt = json['created_at'],
        kind = json['kind'],
        tags = json['tags'],
        content = json['content'],
        sig = json['sig'];

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig
      };

  String getEventId() {
    List data = [0, pubkey, createdAt, kind, tags, content];
    String serializedEvent = json.encode(data);
    List<int> hash = sha256.convert(utf8.encode(serializedEvent)).bytes;
    return hex.encode(hash);
  }

  String getSignature(String privateKey) {
    /// aux must be 32-bytes random bytes, generated at signature time.
    /// https://github.com/nbd-wtf/dart-bip340/blob/master/lib/src/bip340.dart#L10
    String aux = generate32RandomBytes();
    return sign(privateKey, id, aux);
  }
}
