import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Public chat channels — [NIP-28](https://github.com/nostr-protocol/nips/blob/master/28.md)
class Nip28 {
  /// Decodes a kind-40 event into a [Channel].
  ///
  /// Throws [InvalidKindException] if the event kind is not 40.
  static Channel getChannelCreation(Event event) {
    if (event.kind != 40) {
      throw InvalidKindException(event.kind, [40]);
    }
    final Map content = json.decode(event.content);
    final Map<String, String> additional = Map.from(content);
    final String name = additional.remove("name") ?? '';
    final String about = additional.remove("about") ?? '';
    final String picture = additional.remove("picture") ?? '';
    return Channel(
        event.id, name, about, picture, event.pubkey, additional);
  }

  /// Decodes a kind-41 event into a [Channel] with updated metadata.
  ///
  /// Throws [InvalidKindException] if the event kind is not 41.
  /// Throws [MissingTagException] if the `e` tag (channel reference) is absent.
  static Channel getChannelMetadata(Event event) {
    if (event.kind != 41) {
      throw InvalidKindException(event.kind, [41]);
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
      throw MissingTagException('e');
    }
    final Channel result = Channel(
        channelId, name, about, picture, event.pubkey, additional);
    result.relay = relay;
    return result;
  }

  /// Decodes a kind-42 event into a [ChannelMessage].
  ///
  /// Throws [InvalidKindException] if the event kind is not 42.
  static ChannelMessage getChannelMessage(Event event) {
    if (event.kind != 42) {
      throw InvalidKindException(event.kind, [42]);
    }
    final Thread thread = Nip10.fromTags(event.tags);
    return ChannelMessage(
        thread.root.eventId, event.pubkey, event.content, thread, event.createdAt);
  }

  /// Decodes a kind-43 event into a [ChannelMessageHidden].
  ///
  /// Throws [InvalidKindException] if the event kind is not 43.
  /// Throws [MissingTagException] if the `e` tag (message reference) is absent.
  static ChannelMessageHidden getMessageHidden(Event event) {
    if (event.kind != 43) {
      throw InvalidKindException(event.kind, [43]);
    }
    String? messageId;
    for (final tag in event.tags) {
      if (tag[0] == "e") {
        messageId = tag[1];
        break;
      }
    }
    if (messageId == null) {
      throw MissingTagException('e');
    }
    final Map content = json.decode(event.content);
    final String reason = content['reason'] ?? '';
    return ChannelMessageHidden(
        event.pubkey, messageId, reason, event.createdAt);
  }

  /// Decodes a kind-44 event into a [ChannelUserMuted].
  ///
  /// Throws [InvalidKindException] if the event kind is not 44.
  /// Throws [MissingTagException] if the `p` tag (user reference) is absent.
  static ChannelUserMuted getUserMuted(Event event) {
    if (event.kind != 44) {
      throw InvalidKindException(event.kind, [44]);
    }
    String? userPubkey;
    for (final tag in event.tags) {
      if (tag[0] == "p") {
        userPubkey = tag[1];
        break;
      }
    }
    if (userPubkey == null) {
      throw MissingTagException('p');
    }
    final Map content = json.decode(event.content);
    final String reason = content['reason'] ?? '';
    return ChannelUserMuted(
        event.pubkey, userPubkey, reason, event.createdAt);
  }

  /// Creates a kind-40 channel creation event.
  ///
  /// [name] is the channel name.
  /// [about] is the channel description.
  /// [picture] is the channel picture URL.
  /// [additional] is a map of extra metadata fields.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event createChannel({
    required String name,
    required String about,
    required String picture,
    required Map<String, String> additional,
    required String secretKey,
  }) {
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

  /// Creates a kind-41 channel metadata update event.
  ///
  /// [name] is the channel name.
  /// [about] is the channel description.
  /// [picture] is the channel picture URL.
  /// [additional] is a map of extra metadata fields.
  /// [channelId] is the event ID of the kind-40 channel creation event.
  /// [relayURL] is the relay URL where the channel was created.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event setChannelMetaData({
    required String name,
    required String about,
    required String picture,
    required Map<String, String> additional,
    required String channelId,
    required String relayURL,
    required String secretKey,
  }) {
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

  /// Creates a kind-42 channel message event.
  ///
  /// [channelId] is the event ID of the kind-40 channel creation event.
  /// [content] is the message text.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [relay] is an optional relay URL for the root tag.
  /// [etags] is an optional list of event tags for threading.
  /// [ptags] is an optional list of pubkey tags for mentions.
  static Event sendChannelMessage({
    required String channelId,
    required String content,
    required String secretKey,
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

  /// Creates a kind-43 hide channel message event.
  ///
  /// [messageId] is the event ID of the message to hide.
  /// [reason] is the human-readable reason for hiding.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event hideChannelMessage({
    required String messageId,
    required String reason,
    required String secretKey,
  }) {
    return Event.from(
      kind: 43,
      tags: [
        ["e", messageId]
      ],
      content: json.encode({'reason': reason}),
      secretKey: secretKey,
    );
  }

  /// Creates a kind-44 mute user event.
  ///
  /// [pubkey] is the public key of the user to mute.
  /// [reason] is the human-readable reason for muting.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event muteUser({
    required String pubkey,
    required String reason,
    required String secretKey,
  }) {
    return Event.from(
        kind: 44,
        tags: [
          ["p", pubkey]
        ],
        content: json.encode({'reason': reason}),
        secretKey: secretKey);
  }
}

/// Channel info for a NIP-28 public chat channel.
class Channel {
  /// The event ID of the channel creation event (kind 40).
  String channelId;

  /// The channel name.
  String name;

  /// The channel description.
  String about;

  /// The channel picture URL.
  String picture;

  /// The public key of the channel creator.
  String owner;

  /// The relay URL where the channel was created (set by metadata events).
  String? relay;

  /// Extra metadata fields beyond name, about, and picture.
  Map<String, String> additional;

  /// Creates a [Channel] with the given fields.
  Channel(this.channelId, this.name, this.about, this.picture, this.owner,
      this.additional);
}

/// A message in a channel (kind 42).
class ChannelMessage {
  /// The channel this message belongs to (root e tag).
  String channelId;

  /// The message author's public key.
  String pubkey;

  /// The message text.
  String content;

  /// Thread references (root, replies, mentions).
  Thread thread;

  /// Unix timestamp in seconds.
  int createdAt;

  /// Creates a [ChannelMessage] with the given fields.
  ChannelMessage(
      this.channelId, this.pubkey, this.content, this.thread, this.createdAt);
}

/// A hidden channel message (kind 43).
class ChannelMessageHidden {
  /// The user who requested the hide.
  String pubkey;

  /// The hidden message's event ID (from e tag).
  String messageId;

  /// The reason for hiding.
  String reason;

  /// Unix timestamp in seconds.
  int createdAt;

  /// Creates a [ChannelMessageHidden] with the given fields.
  ChannelMessageHidden(
      this.pubkey, this.messageId, this.reason, this.createdAt);
}

/// A muted user in a channel (kind 44).
class ChannelUserMuted {
  /// The user who requested the mute.
  String pubkey;

  /// The muted user's public key (from p tag).
  String userPubkey;

  /// The reason for muting.
  String reason;

  /// Unix timestamp in seconds.
  int createdAt;

  /// Creates a [ChannelUserMuted] with the given fields.
  ChannelUserMuted(
      this.pubkey, this.userPubkey, this.reason, this.createdAt);
}

typedef PublicChat = Nip28;
