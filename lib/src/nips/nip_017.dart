import 'dart:convert';
import 'dart:math';

/// Private Direct Messages
/// https://github.com/nostr-protocol/nips/blob/master/17.md
class Nip17 {
  static Future<Event> encode(
      Event event, String receiver, String myPubkey, String privkey,
      {int? kind,
      int? expiration,
      String? sealedPrivkey,
      String? sealedReceiver,
      int? createAt}) async {
    Event sealedGossipEvent = await _encodeSealedGossip(
        event, sealedReceiver ?? receiver, myPubkey, privkey);
    return await Nip59.encode(sealedGossipEvent, sealedReceiver ?? receiver,
        kind: kind?.toString(),
        expiration: expiration,
        sealedPrivkey: sealedPrivkey,
        createAt: createAt ?? randomTimeUpTo2DaysInThePast());
  }

  static Future<Event> _encodeSealedGossip(
      Event event, String receiver, String myPubkey, String privkey) async {
    event.sig = '';
    String encodedEvent = jsonEncode(event);
    String content =
        await Nip44.encryptContent(encodedEvent, receiver, myPubkey, privkey);

    return Event.from(
        kind: 13,
        tags: [],
        createdAt: randomTimeUpTo2DaysInThePast(),
        content: content,
        pubkey: myPubkey,
        privkey: privkey);
  }

  static Future<Event> encodeInnerEvent(String receiver, String content,
      String replyId, String myPubkey, String privKey,
      {String? subContent,
      int? expiration,
      List<String>? members,
      String? subject,
      int createAt = 0,
      EncryptedFile? encryptedFile}) async {
    List<List<String>> tags =
        Nip4.toTags(receiver, replyId, expiration, members: members);
    if (subContent != null && subContent.isNotEmpty) {
      tags.add(['subContent', subContent]);
    }
    if (subject != null && subject.isNotEmpty) {
      tags.add(['subject', subject]);
    }
    if (encryptedFile == null) {
      return await Event.from(
          kind: 14,
          tags: tags,
          content: content,
          pubkey: myPubkey,
          privkey: privKey,
          createdAt: createAt);
    } else {
      tags.add(['file-type', encryptedFile.mimeType]);
      tags.add(['encryption-algorithm', encryptedFile.algorithm]);
      tags.add(['decryption-key', encryptedFile.secret]);
      tags.add(['decryption-nonce', encryptedFile.nonce]);
      return await Event.from(
          kind: 15,
          tags: tags,
          content: content,
          pubkey: myPubkey,
          privkey: privKey,
          createdAt: createAt);
    }
  }

  static Future<Event> encodeSealedGossipDM(String receiver, String content,
      String replyId, String myPubkey, String privKey,
      {String? sealedPrivkey,
      String? sealedReceiver,
      int? createAt,
      String? subContent,
      int? expiration,
      Event? innerEvent,
      List<String>? members}) async {
    innerEvent ??= await encodeInnerEvent(
        receiver, content, replyId, myPubkey, privKey,
        subContent: subContent, expiration: expiration);
    Event event = await encode(innerEvent, receiver, myPubkey, privKey,
        sealedPrivkey: sealedPrivkey,
        sealedReceiver: sealedReceiver,
        createAt: createAt,
        expiration: expiration);
    event.innerEvent = innerEvent;
    return event;
  }

  static Future<Event?> decode(Event event, String myPubkey, String privkey,
      {String? sealedPrivkey}) async {
    try {
      Event sealedGossipEvent =
          await Nip59.decode(event, myPubkey, sealedPrivkey ?? privkey);
      Event decodeEvent = await _decodeSealedGossip(
          sealedGossipEvent, myPubkey, sealedPrivkey ?? privkey);
      return decodeEvent;
    } catch (e) {
      print('decode error: ${e.toString()}');
      return null;
    }
  }

  static Future<Event> _decodeSealedGossip(
      Event event, String myPubkey, String privkey) async {
    if (event.kind == 13) {
      try {
        String content = await Nip44.decryptContent(
            event.content, event.pubkey, myPubkey, privkey);
        Map<String, dynamic> map = jsonDecode(content);
        map['sig'] = '';
        Event innerEvent = await Event.fromJson(map, verify: false);
        if (innerEvent.pubkey == event.pubkey) {
          return innerEvent;
        }
      } catch (e) {
        throw Exception(e);
      }
    }
    throw Exception("${event.kind} is not nip24 compatible");
  }

  static Future<EDMessage?> decodeSealedGossipDM(
      Event innerEvent, String receiver, String myPubkey) async {
    if (innerEvent.kind == 14 || innerEvent.kind == 15) {
      List<String> receivers = [];
      String replyId = "";
      String subContent = innerEvent.content;
      String? expiration;
      String? subject;
      String? mimeType;
      String? algorithm;
      String? secret;
      String? nonce;
      for (var tag in innerEvent.tags) {
        if (tag[0] == "p") {
          if (!receivers.contains(tag[1])) receivers.add(tag[1]);
        }
        if (tag[0] == "e") replyId = tag[1];
        if (tag[0] == "subContent") subContent = tag[1];
        if (tag[0] == "expiration") expiration = tag[1];
        if (tag[0] == "subject") subject = tag[1];
        if (tag[0] == "file-type") mimeType = tag[1];
        if (tag[0] == "encryption-algorithm") algorithm = tag[1];
        if (tag[0] == "decryption-key") secret = tag[1];
        if (tag[0] == "decryption-nonce") nonce = tag[1];
      }
      if (receivers.isEmpty) receivers.add(myPubkey);
      if (receivers.length == 1 ||
          (receivers.length == 2 && receivers.contains(myPubkey))) {
        // private chat
        return EDMessage(innerEvent.pubkey, receivers.first,
            innerEvent.createdAt, subContent, replyId, expiration,
            mimeType: mimeType,
            algorithm: algorithm,
            secret: secret,
            nonce: nonce);
      } else {
        // private chat room
        return EDMessage(innerEvent.pubkey, '', innerEvent.createdAt,
            subContent, replyId, expiration,
            mimeType: mimeType,
            algorithm: algorithm,
            secret: secret,
            nonce: nonce,
            groupId: ChatRoom.generateChatRoomID(receivers),
            subject: subject,
            members: receivers);
      }
    }
    return null;
  }

  static Future<Event> encodeDMRelays(
      List<String> relays, String myPubkey, String privkey) async {
    List<List<String>> tags = [];
    for (var relay in relays) {
      tags.add(['relay', relay]);
    }
    return await Event.from(
        kind: 10050,
        tags: tags,
        content: '',
        pubkey: myPubkey,
        privkey: privkey);
  }

  static List<String> decodeDMRelays(Event event) {
    if (event.kind == 10050) {
      List<String> result = [];
      for (var tag in event.tags) {
        if (tag[0] == 'relay') result.add(tag[1]);
      }
      return result;
    }
    throw Exception("${event.kind} is not nip17 compatible");
  }

  static int randomTimeUpTo2DaysInThePast() {
    var intValue = Random().nextInt(24 * 60 * 60 * 2);
    return currentUnixTimestampSeconds() - intValue;
  }
}

class EncryptedFile {
  String data;
  String mimeType;
  String algorithm;
  String secret;
  String nonce;

  EncryptedFile(
      this.data, this.mimeType, this.algorithm, this.secret, this.nonce);
}

/// ChatRoom info
class ChatRoom {
  String id;
  String name;
  List<String> members;

  /// Default constructor
  ChatRoom(this.id, this.name, this.members);

  static String generateChatRoomID(List<String> members) {
    members.sort();
    String concatenatedPubkeys = members.join();
    var bytes = utf8.encode(concatenatedPubkeys);
    var digest = md5.convert(bytes);
    return digest.toString();
  }
}
