import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Public chat channels — [NIP-28](https://github.com/nostr-protocol/nips/blob/master/28.md)
///
/// Kind 40: channel creation, kind 41: channel metadata update,
/// kind 42: channel message, kind 43: hide message, kind 44: mute user.
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
      channelId: event.id,
      name: name,
      about: about,
      picture: picture,
      owner: event.pubkey,
      additional: additional,
    );
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

    final channelId = findTagValue(event.tags, 'e');
    if (channelId == null) {
      throw MissingTagException('e');
    }

    // Extract relay from e tag (third element)
    String? relay;
    for (final tag in event.tags) {
      if (tag[0] == 'e' && tag.length > 2) {
        relay = tag[2];
        break;
      }
    }

    return Channel(
      channelId: channelId,
      name: name,
      about: about,
      picture: picture,
      owner: event.pubkey,
      additional: additional,
      relay: relay,
    );
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
      channelId: thread.root.eventId,
      pubkey: event.pubkey,
      content: event.content,
      thread: thread,
      createdAt: event.createdAt,
    );
  }

  /// Decodes a kind-43 event into a [ChannelMessageHidden].
  ///
  /// Throws [InvalidKindException] if the event kind is not 43.
  static ChannelMessageHidden getMessageHidden(Event event) {
    if (event.kind != 43) {
      throw InvalidKindException(event.kind, [43]);
    }
    final messageId = findTagValue(event.tags, 'e') ?? '';
    String reason = '';
    try {
      final Map content = json.decode(event.content);
      reason = content['reason'] ?? '';
    } on FormatException {
      // Content may not be JSON (e.g. encrypted)
    }
    return ChannelMessageHidden(
      pubkey: event.pubkey,
      messageId: messageId,
      reason: reason,
      createdAt: event.createdAt,
    );
  }

  /// Decodes a kind-44 event into a [ChannelUserMuted].
  ///
  /// Throws [InvalidKindException] if the event kind is not 44.
  /// Throws [MissingTagException] if the `p` tag (user reference) is absent.
  static ChannelUserMuted getUserMuted(Event event) {
    if (event.kind != 44) {
      throw InvalidKindException(event.kind, [44]);
    }
    final userPubkey = findTagValue(event.tags, 'p');
    if (userPubkey == null) {
      throw MissingTagException('p');
    }
    String reason = '';
    try {
      final Map content = json.decode(event.content);
      reason = content['reason'] ?? '';
    } on FormatException {
      // Content may not be JSON (e.g. encrypted)
    }
    return ChannelUserMuted(
      pubkey: event.pubkey,
      userPubkey: userPubkey,
      reason: reason,
      createdAt: event.createdAt,
    );
  }

  /// Creates a kind-40 channel creation event.
  static Event createChannel({
    required String name,
    required String about,
    required String picture,
    required String secretKey,
    Map<String, String> additional = const {},
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
  /// Per spec, the `e` tag includes a `"root"` marker.
  static Event setChannelMetaData({
    required String name,
    required String about,
    required String picture,
    required String channelId,
    required String relayURL,
    required String secretKey,
    Map<String, String> additional = const {},
  }) {
    final Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
    };
    map.addAll(additional);
    return Event.from(
      kind: 41,
      tags: [
        ["e", channelId, relayURL, "root"]
      ],
      content: json.encode(map),
      secretKey: secretKey,
    );
  }

  /// Creates a kind-42 channel message event.
  static Event sendChannelMessage({
    required String channelId,
    required String content,
    required String secretKey,
    String? relay,
    List<ETag>? etags,
    List<PTag>? ptags,
  }) {
    final Thread thread =
        Thread(root: Nip10.rootTag(channelId, relay ?? ''), etags: etags ?? [], ptags: ptags ?? []);
    return Event.from(
      kind: 42,
      tags: Nip10.toTags(thread),
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-43 hide channel message event.
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
  final String channelId;

  /// The channel name.
  final String name;

  /// The channel description.
  final String about;

  /// The channel picture URL.
  final String picture;

  /// The public key of the channel creator.
  final String owner;

  /// The relay URL where the channel was created.
  final String? relay;

  /// Extra metadata fields beyond name, about, and picture.
  final Map<String, String> additional;

  const Channel({
    required this.channelId,
    required this.name,
    required this.about,
    required this.picture,
    required this.owner,
    required this.additional,
    this.relay,
  });
}

/// A message in a channel (kind 42).
class ChannelMessage {
  /// The channel this message belongs to (root e tag).
  final String channelId;

  /// The message author's public key.
  final String pubkey;

  /// The message text.
  final String content;

  /// Thread references (root, replies, mentions).
  final Thread thread;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ChannelMessage({
    required this.channelId,
    required this.pubkey,
    required this.content,
    required this.thread,
    required this.createdAt,
  });
}

/// A hidden channel message (kind 43).
class ChannelMessageHidden {
  /// The user who requested the hide.
  final String pubkey;

  /// The hidden message's event ID (from e tag).
  final String messageId;

  /// The reason for hiding.
  final String reason;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ChannelMessageHidden({
    required this.pubkey,
    required this.messageId,
    required this.reason,
    required this.createdAt,
  });
}

/// A muted user in a channel (kind 44).
class ChannelUserMuted {
  /// The user who requested the mute.
  final String pubkey;

  /// The muted user's public key (from p tag).
  final String userPubkey;

  /// The reason for muting.
  final String reason;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ChannelUserMuted({
    required this.pubkey,
    required this.userPubkey,
    required this.reason,
    required this.createdAt,
  });
}

typedef PublicChat = Nip28;
