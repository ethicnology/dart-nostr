import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Public Chat & Channel (NIP-28)
class Nip28 {
  static Channel getChannelCreation(Event event) {
    if (event.kind != 40) {
      throw Exception("kind ${event.kind} is not nip28 compatible (expected 40)");
    }
    final Map content = json.decode(event.content);
    final Map<String, String> additional = Map.from(content);
    final String name = additional.remove("name") ?? '';
    final String about = additional.remove("about") ?? '';
    final String picture = additional.remove("picture") ?? '';
    return Channel(
        event.id, name, about, picture, event.pubkey, additional);
  }

  static Channel getChannelMetadata(Event event) {
    if (event.kind != 41) {
      throw Exception("kind ${event.kind} is not nip28 compatible (expected 41)");
    }
    final Map content = json.decode(event.content);
    final Map<String, String> additional = Map.from(content);
    final String name = additional.remove("name") ?? '';
    final String about = additional.remove("about") ?? '';
    final String picture = additional.remove("picture") ?? '';
    String? channelId;
    String? relay;
    for (final tag in event.tags) {
      if (tag[0] == "e") {
        channelId = tag[1];
        if (tag.length > 2) relay = tag[2];
      }
    }
    if (channelId == null) {
      throw Exception("Missing channel reference (e tag) in kind 41 event");
    }
    final Channel result = Channel(
        channelId, name, about, picture, event.pubkey, additional);
    result.relay = relay;
    return result;
  }

  static ChannelMessage getChannelMessage(Event event) {
    if (event.kind != 42) {
      throw Exception("kind ${event.kind} is not nip28 compatible (expected 42)");
    }
    final Thread thread = Nip10.fromTags(event.tags);
    return ChannelMessage(
        thread.root.eventId, event.pubkey, event.content, thread, event.createdAt);
  }

  static ChannelMessageHidden getMessageHidden(Event event) {
    if (event.kind != 43) {
      throw Exception("kind ${event.kind} is not nip28 compatible (expected 43)");
    }
    String? messageId;
    for (final tag in event.tags) {
      if (tag[0] == "e") {
        messageId = tag[1];
        break;
      }
    }
    if (messageId == null) {
      throw Exception("Missing message reference (e tag) in kind 43 event");
    }
    final Map content = json.decode(event.content);
    final String reason = content['reason'] ?? '';
    return ChannelMessageHidden(
        event.pubkey, messageId, reason, event.createdAt);
  }

  static ChannelUserMuted getUserMuted(Event event) {
    if (event.kind != 44) {
      throw Exception("kind ${event.kind} is not nip28 compatible (expected 44)");
    }
    String? userPubkey;
    for (final tag in event.tags) {
      if (tag[0] == "p") {
        userPubkey = tag[1];
        break;
      }
    }
    if (userPubkey == null) {
      throw Exception("Missing user reference (p tag) in kind 44 event");
    }
    final Map content = json.decode(event.content);
    final String reason = content['reason'] ?? '';
    return ChannelUserMuted(
        event.pubkey, userPubkey, reason, event.createdAt);
  }

  static Event createChannel(String name, String about, String picture,
      Map<String, String> additional, String secretKey) {
    final Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
    };
    map.addAll(additional);
    return Event.from(
      kind: 40,
      tags: [],
      content: json.encode(map),
      secretKey: secretKey,
    );
  }

  static Event setChannelMetaData(
      String name,
      String about,
      String picture,
      Map<String, String> additional,
      String channelId,
      String relayURL,
      String secretKey) {
    final Map<String, dynamic> map = {
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
      content: json.encode(map),
      secretKey: secretKey,
    );
  }

  static Event sendChannelMessage(
    String channelId,
    String content,
    String secretKey, {
    String? relay,
    List<ETag>? etags,
    List<PTag>? ptags,
  }) {
    final Thread thread =
        Thread(Nip10.rootTag(channelId, relay ?? ''), etags ?? [], ptags ?? []);
    return Event.from(
      kind: 42,
      tags: Nip10.toTags(thread),
      content: content,
      secretKey: secretKey,
    );
  }

  static Event hideChannelMessage(
    String messageId,
    String reason,
    String secretKey,
  ) {
    return Event.from(
      kind: 43,
      tags: [
        ["e", messageId]
      ],
      content: json.encode({'reason': reason}),
      secretKey: secretKey,
    );
  }

  static Event muteUser(String pubkey, String reason, String secretKey) {
    return Event.from(
        kind: 44,
        tags: [
          ["p", pubkey]
        ],
        content: json.encode({'reason': reason}),
        secretKey: secretKey);
  }
}

/// Channel info
class Channel {
  String channelId;
  String name;
  String about;
  String picture;
  String owner;
  String? relay;
  Map<String, String> additional;

  Channel(this.channelId, this.name, this.about, this.picture, this.owner,
      this.additional);
}

/// A message in a channel (kind 42)
class ChannelMessage {
  /// The channel this message belongs to (root e tag)
  String channelId;

  /// The message author's public key
  String pubkey;

  /// The message text
  String content;

  /// Thread references (root, replies, mentions)
  Thread thread;

  /// Unix timestamp in seconds
  int createdAt;

  ChannelMessage(
      this.channelId, this.pubkey, this.content, this.thread, this.createdAt);
}

/// A hidden channel message (kind 43)
class ChannelMessageHidden {
  /// The user who requested the hide
  String pubkey;

  /// The hidden message's event ID (from e tag)
  String messageId;

  /// The reason for hiding
  String reason;

  /// Unix timestamp in seconds
  int createdAt;

  ChannelMessageHidden(
      this.pubkey, this.messageId, this.reason, this.createdAt);
}

/// A muted user in a channel (kind 44)
class ChannelUserMuted {
  /// The user who requested the mute
  String pubkey;

  /// The muted user's public key (from p tag)
  String userPubkey;

  /// The reason for muting
  String reason;

  /// Unix timestamp in seconds
  int createdAt;

  ChannelUserMuted(
      this.pubkey, this.userPubkey, this.reason, this.createdAt);
}

typedef PublicChat = Nip28;
