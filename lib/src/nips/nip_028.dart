import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Public Chat & Channel
class Nip28 {
  static Channel getChannelCreation(Event event) {
    try {
      Map content = jsonDecode(event.content);
      if (event.kind == 40) {
        // create channel
        Map<String, String> additional = Map.from(content);
        String? name = additional.remove("name");
        String? about = additional.remove("about");
        String? picture = additional.remove("picture");
        return Channel(
            event.id, name!, about!, picture!, event.pubkey, additional);
      } else {
        throw Exception("${event.kind} is not nip28 compatible");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Channel getChannelMetadata(Event event) {
    try {
      Map content = jsonDecode(event.content);
      if (event.kind == 41) {
        // create channel
        Map<String, String> additional = Map.from(content);
        String? name = additional.remove("name");
        String? about = additional.remove("about");
        String? picture = additional.remove("picture");
        String? channelId;
        String? relay;
        for (var tag in event.tags) {
          if (tag[0] == "e") {
            channelId = tag[1];
            relay = tag[2];
          }
        }
        Channel result = Channel(
            channelId!, name!, about!, picture!, event.pubkey, additional);
        result.relay = relay;
        return result;
      } else {
        throw Exception("${event.kind} is not nip28 compatible");
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static ChannelMessage getChannelMessage(Event event) {
    try {
      if (event.kind == 42) {
        var content = event.content;
        Thread thread = Nip10.fromTags(event.tags);
        String channelId = thread.root.eventId;
        return ChannelMessage(
            channelId, event.pubkey, content, thread, event.createdAt);
      }
      throw Exception("${event.kind} is not nip28 compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static ChannelMessageHidden getMessageHidden(Event event) {
    try {
      if (event.kind == 43) {
        String? messageId;
        for (var tag in event.tags) {
          if (tag[0] == "e") {
            messageId = tag[1];
            break;
          }
        }
        Map content = jsonDecode(event.content);
        String reason = content['reason'];
        return ChannelMessageHidden(
            event.pubkey, messageId!, reason, event.createdAt);
      }
      throw Exception("${event.kind} is not nip28(hide message) compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static ChannelUserMuted getUserMuted(Event event) {
    try {
      if (event.kind == 44) {
        String? userPubkey;
        for (var tag in event.tags) {
          if (tag[0] == "p") {
            userPubkey = tag[1];
            break;
          }
        }
        Map content = jsonDecode(event.content);
        String reason = content['reason'];
        return ChannelUserMuted(
            event.pubkey, userPubkey!, reason, event.createdAt);
      }
      throw Exception("${event.kind} is not nip28(mute user) compatible");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  static Event createChannel(String name, String about, String picture,
      Map<String, String> additional, String privkey) {
    Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
    };
    map.addAll(additional);
    return Event.from(
      kind: 40,
      tags: [],
      content: jsonEncode(map),
      privkey: privkey,
    );
  }

  static Event setChannelMetaData(
      String name,
      String about,
      String picture,
      Map<String, String> additional,
      String channelId,
      String relayURL,
      String privkey) {
    Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture
    };
    map.addAll(additional);
    return Event.from(
      kind: 41,
      tags: [
        ["e", channelId, relayURL]
      ],
      content: jsonEncode(map),
      privkey: privkey,
    );
  }

  static Event sendChannelMessage(
      String channelId, String content, String privkey,
      {String? relay, List<ETag>? etags, List<PTag>? ptags}) {
    Thread thread =
        Thread(Nip10.rootTag(channelId, relay ?? ''), etags ?? [], ptags ?? []);
    return Event.from(
      kind: 42,
      tags: Nip10.toTags(thread),
      content: content,
      privkey: privkey,
    );
  }

  static Event hideChannelMessage(
      String messageId, String reason, String privkey) {
    Map<String, dynamic> map = {'reason': reason};
    return Event.from(
      kind: 43,
      tags: [
        ["e", messageId]
      ],
      content: jsonEncode(map),
      privkey: privkey,
    );
  }

  static Event muteUser(String pubkey, String reason, String privkey) {
    Map<String, dynamic> map = {'reason': reason};
    return Event.from(
        kind: 44,
        tags: [
          ["p", pubkey]
        ],
        content: jsonEncode(map),
        privkey: privkey);
  }
}

/// channel info
class Channel {
  /// channel create event id
  String channelId;

  String name;

  String about;

  String picture;

  String owner;

  String? relay;

  /// Clients MAY add additional metadata fields.
  Map<String, String> additional;

  /// Default constructor
  Channel(this.channelId, this.name, this.about, this.picture, this.owner,
      this.additional);
}

/// messages in channel
class ChannelMessage {
  String channelId;
  String sender;
  String content;
  Thread thread;
  int createTime;

  ChannelMessage(
      this.channelId, this.sender, this.content, this.thread, this.createTime);
}

class ChannelMessageHidden {
  String operator;
  String messageId;
  String reason;
  int createTime;

  ChannelMessageHidden(
      this.operator, this.messageId, this.reason, this.createTime);
}

class ChannelUserMuted {
  String operator;
  String userPubkey;
  String reason;
  int createTime;

  ChannelUserMuted(
      this.operator, this.userPubkey, this.reason, this.createTime);
}
