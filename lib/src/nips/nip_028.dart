import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Public chat channels — [NIP-28](https://github.com/nostr-protocol/nips/blob/master/28.md)
///
/// Kind 40: channel creation, kind 41: channel metadata update,
/// kind 42: channel message, kind 43: hide message, kind 44: mute user.
class PublicChat {
  /// Event kind for channel creation.
  static const int kindChannelCreation = 40;

  /// Event kind for channel metadata updates.
  static const int kindChannelMetadata = 41;

  /// Event kind for channel messages.
  static const int kindChannelMessage = 42;

  /// Event kind for hiding a channel message.
  static const int kindHideMessage = 43;

  /// Event kind for muting a channel user.
  static const int kindMuteUser = 44;

  /// Parses a kind-40 event into a [ChannelData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 40.
  static ChannelData parseChannel(Event event) {
    if (event.kind != kindChannelCreation) {
      throw InvalidKindException(event.kind, [kindChannelCreation]);
    }
    final parsed = _parseChannelContent(event.content);
    return ChannelData(
      channelId: event.id,
      name: parsed.name,
      about: parsed.about,
      picture: parsed.picture,
      relays: parsed.relays,
      owner: event.pubkey,
      additional: parsed.additional,
    );
  }

  /// Parses a kind-41 event into a [ChannelData] with updated metadata.
  ///
  /// Throws [InvalidKindException] if the event kind is not 41.
  /// Throws [MissingTagException] if the `e` tag (channel reference) is absent.
  static ChannelData parseMetadata(Event event) {
    if (event.kind != kindChannelMetadata) {
      throw InvalidKindException(event.kind, [kindChannelMetadata]);
    }
    final parsed = _parseChannelContent(event.content);

    final channelId = findTagValue(event.tags, 'e');
    if (channelId == null) {
      throw MissingTagException('e');
    }

    // Extract relay from e tag (third element)
    String? relay;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 2) {
        relay = tag[2];
        break;
      }
    }

    return ChannelData(
      channelId: channelId,
      name: parsed.name,
      about: parsed.about,
      picture: parsed.picture,
      relays: parsed.relays,
      owner: event.pubkey,
      additional: parsed.additional,
      relay: relay,
    );
  }

  /// Parses the JSON content of a kind 40 / 41 channel event into its
  /// well-known fields plus any extra string metadata.
  ///
  /// The spec allows a `relays` array alongside `name`, `about`, `picture`;
  /// we extract it as a typed `List<String>` rather than crashing on the
  /// non-string value the way `Map<String, String>.from` would.
  static _ChannelContent _parseChannelContent(String raw) {
    final Map<String, dynamic> content =
        json.decode(raw) as Map<String, dynamic>;

    final String name = content['name'] is String ? content['name'] : '';
    final String about = content['about'] is String ? content['about'] : '';
    final String picture =
        content['picture'] is String ? content['picture'] : '';

    final List<String> relays = content['relays'] is List
        ? (content['relays'] as List).whereType<String>().toList()
        : const [];

    // Anything else that's a string falls through to `additional` so callers
    // can read forward-compatible kind-0 conventions (website, banner, bot…).
    final Map<String, String> additional = {};
    for (final entry in content.entries) {
      if (entry.key == 'name' ||
          entry.key == 'about' ||
          entry.key == 'picture' ||
          entry.key == 'relays') {
        continue;
      }
      if (entry.value is String) {
        additional[entry.key] = entry.value as String;
      }
    }

    return _ChannelContent(
      name: name,
      about: about,
      picture: picture,
      relays: relays,
      additional: additional,
    );
  }

  /// Parses a kind-42 event into a [ChannelMessageData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 42.
  static ChannelMessageData parseMessage(Event event) {
    if (event.kind != kindChannelMessage) {
      throw InvalidKindException(event.kind, [kindChannelMessage]);
    }
    final Thread thread = Threading.parseTags(event.tags);
    return ChannelMessageData(
      channelId: thread.root.eventId,
      pubkey: event.pubkey,
      content: event.content,
      thread: thread,
      createdAt: event.createdAt,
    );
  }

  /// Parses a kind-43 event into a [ChannelMessageHiddenData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 43.
  static ChannelMessageHiddenData parseHidden(Event event) {
    if (event.kind != kindHideMessage) {
      throw InvalidKindException(event.kind, [kindHideMessage]);
    }
    final messageId = findTagValue(event.tags, 'e') ?? '';
    String reason = '';
    try {
      final Map content = json.decode(event.content);
      reason = content['reason'] ?? '';
    } on FormatException {
      // Content may not be JSON (e.g. encrypted)
    }
    return ChannelMessageHiddenData(
      pubkey: event.pubkey,
      messageId: messageId,
      reason: reason,
      createdAt: event.createdAt,
    );
  }

  /// Parses a kind-44 event into a [ChannelUserMutedData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 44.
  /// Throws [MissingTagException] if the `p` tag (user reference) is absent.
  static ChannelUserMutedData parseMuted(Event event) {
    if (event.kind != kindMuteUser) {
      throw InvalidKindException(event.kind, [kindMuteUser]);
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
    return ChannelUserMutedData(
      pubkey: event.pubkey,
      userPubkey: userPubkey,
      reason: reason,
      createdAt: event.createdAt,
    );
  }

  /// Creates a kind-40 channel creation event.
  static Event channel({
    required String name,
    required String about,
    required String picture,
    required String secretKey,
    List<String> relays = const [],
    Map<String, String> additional = const {},
  }) {
    final Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
      if (relays.isNotEmpty) 'relays': relays,
    };
    map.addAll(additional);
    return Event.from(
      kind: kindChannelCreation,
      tags: [],
      content: json.encode(map),
      secretKey: secretKey,
    );
  }

  /// Creates a kind-41 channel metadata update event.
  ///
  /// Per spec, the `e` tag includes a `"root"` marker.
  static Event channelMetadata({
    required String name,
    required String about,
    required String picture,
    required String channelId,
    required String relayURL,
    required String secretKey,
    List<String> relays = const [],
    Map<String, String> additional = const {},
  }) {
    final Map<String, dynamic> map = {
      'name': name,
      'about': about,
      'picture': picture,
      if (relays.isNotEmpty) 'relays': relays,
    };
    map.addAll(additional);
    return Event.from(
      kind: kindChannelMetadata,
      tags: [
        ["e", channelId, relayURL, "root"]
      ],
      content: json.encode(map),
      secretKey: secretKey,
    );
  }

  /// Creates a kind-42 channel message event.
  static Event channelMessage({
    required String channelId,
    required String content,
    required String secretKey,
    String? relay,
    List<ETag>? etags,
    List<PTag>? ptags,
  }) {
    final Thread thread =
        Thread(root: Threading.rootTag(channelId, relay ?? ''), etags: etags ?? [], ptags: ptags ?? []);
    return Event.from(
      kind: kindChannelMessage,
      tags: Threading.toTags(thread),
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-43 hide channel message event.
  static Event hideMessage({
    required String messageId,
    required String reason,
    required String secretKey,
  }) {
    return Event.from(
      kind: kindHideMessage,
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
        kind: kindMuteUser,
        tags: [
          ["p", pubkey]
        ],
        content: json.encode({'reason': reason}),
        secretKey: secretKey);
  }
}

/// Channel info for a NIP-28 public chat channel.
class ChannelData {
  /// The event ID of the channel creation event (kind 40).
  final String channelId;

  /// The channel name.
  final String name;

  /// The channel description.
  final String about;

  /// The channel picture URL.
  final String picture;

  /// Channel-level relay hints from the kind-40 content (spec-defined
  /// `relays` array). Empty when the content does not include it.
  final List<String> relays;

  /// The public key of the channel creator.
  final String owner;

  /// The relay URL from the kind-41 `e`-tag third element (the relay where
  /// the kind-40 creation event can be found). Distinct from [relays].
  final String? relay;

  /// Extra metadata fields beyond name, about, picture, and relays.
  /// Only string values are kept; structured fields land on dedicated
  /// fields above.
  final Map<String, String> additional;

  const ChannelData({
    required this.channelId,
    required this.name,
    required this.about,
    required this.picture,
    required this.owner,
    required this.additional,
    this.relays = const [],
    this.relay,
  });
}

/// Internal struct for unpacking a kind 40 / 41 content payload.
class _ChannelContent {
  final String name;
  final String about;
  final String picture;
  final List<String> relays;
  final Map<String, String> additional;
  const _ChannelContent({
    required this.name,
    required this.about,
    required this.picture,
    required this.relays,
    required this.additional,
  });
}

/// A message in a channel (kind 42).
class ChannelMessageData {
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

  const ChannelMessageData({
    required this.channelId,
    required this.pubkey,
    required this.content,
    required this.thread,
    required this.createdAt,
  });
}

/// A hidden channel message (kind 43).
class ChannelMessageHiddenData {
  /// The user who requested the hide.
  final String pubkey;

  /// The hidden message's event ID (from e tag).
  final String messageId;

  /// The reason for hiding.
  final String reason;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ChannelMessageHiddenData({
    required this.pubkey,
    required this.messageId,
    required this.reason,
    required this.createdAt,
  });
}

/// A muted user in a channel (kind 44).
class ChannelUserMutedData {
  /// The user who requested the mute.
  final String pubkey;

  /// The muted user's public key (from p tag).
  final String userPubkey;

  /// The reason for muting.
  final String reason;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ChannelUserMutedData({
    required this.pubkey,
    required this.userPubkey,
    required this.reason,
    required this.createdAt,
  });
}

typedef Nip28 = PublicChat;
typedef Channel = ChannelData;
typedef ChannelMessage = ChannelMessageData;
typedef ChannelMessageHidden = ChannelMessageHiddenData;
typedef ChannelUserMuted = ChannelUserMutedData;
