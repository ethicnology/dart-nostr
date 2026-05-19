import 'package:nostr/nostr.dart';

/// Relay-based groups — [NIP-29](https://github.com/nostr-protocol/nips/blob/master/29.md)
///
/// All group events carry an `h` tag containing the group identifier.
/// User-created events (chat messages, articles, etc.) may also include
/// `previous` tags referencing the first 8 characters of recent event IDs
/// for timeline consistency.
///
/// Example:
/// ```json
/// {
///   "kind": 9,
///   "tags": [
///     ["h", "<group-id>"],
///     ["previous", "abc12345", "def67890"]
///   ],
///   "content": "Hello group!"
/// }
/// ```
class Group {
  /// Kind for group chat messages (simple, no subject).
  static const int kindGroupChatMessage = 9;

  /// Kind for group thread root messages (has subject).
  static const int kindGroupThreadRoot = 11;

  /// Kind for group thread reply messages.
  static const int kindGroupThreadReply = 12;

  /// Kind for join request.
  static const int kindJoinRequest = 9021;

  /// Kind for leave request.
  static const int kindLeaveRequest = 9022;

  /// Kind for group metadata (relay-generated).
  static const int kindGroupMetadata = 39000;

  /// Kind for group admins list (relay-generated).
  static const int kindGroupAdmins = 39001;

  /// Kind for group members list (relay-generated).
  static const int kindGroupMembers = 39002;

  /// Parses a group chat event into a [GroupMessageData].
  ///
  /// Accepts kinds 9, 11, and 12 (the user-facing chat kinds).
  /// Throws [InvalidKindException] if the event kind is not one of these.
  /// Throws [MissingTagException] if the `h` tag is absent and
  /// [permissive] is false. In permissive mode the missing tag is
  /// recorded in [GroupMessageData.missingTags] and `groupId` defaults
  /// to the empty string.
  static GroupMessageData parseMessage(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindGroupChatMessage &&
        event.kind != kindGroupThreadRoot &&
        event.kind != kindGroupThreadReply) {
      throw InvalidKindException(event.kind, [
        kindGroupChatMessage,
        kindGroupThreadRoot,
        kindGroupThreadReply,
      ]);
    }

    final missing = <String>{};
    final groupId = findTagValue(event.tags, 'h');
    if (groupId == null) {
      if (!permissive) throw MissingTagException('h');
      missing.add('h');
    }

    // Extract previous event references (may be multiple values in one tag)
    final List<String> previousEvents = [];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'previous') {
        for (var i = 1; i < tag.length; i++) {
          previousEvents.add(tag[i]);
        }
      }
    }

    // Thread references
    final replyToEventId = findTagValue(event.tags, 'e');
    final subject = findTagValue(event.tags, 'subject');

    return GroupMessageData(
      groupId: groupId ?? '',
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      previousEvents: previousEvents,
      replyToEventId: replyToEventId,
      subject: subject,
      missingTags: missing,
    );
  }

  /// Parses a kind 39000 event into [GroupMetadataData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 39000.
  /// Throws [MissingTagException] if the `d` (group identifier) tag is
  /// absent and [permissive] is false. NIP-29 makes `d` the group
  /// identifier for the addressable metadata event — silently defaulting
  /// it would let consumers act on the wrong (or empty) group.
  ///
  /// In permissive mode the missing tag is recorded in
  /// [GroupMetadataData.missingTags] instead of throwing.
  static GroupMetadataData parseMetadata(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindGroupMetadata) {
      throw InvalidKindException(event.kind, [kindGroupMetadata]);
    }

    final missing = <String>{};
    final groupId = findTagValue(event.tags, 'd');
    if (groupId == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    final name = findTagValue(event.tags, 'name');
    final picture = findTagValue(event.tags, 'picture');
    final about = findTagValue(event.tags, 'about');

    // Privacy flags: presence of these tags indicates the property
    final bool isOpen =
        event.tags.any((t) => t.isNotEmpty && t[0] == 'open');
    final bool isPublic =
        event.tags.any((t) => t.isNotEmpty && t[0] == 'public');

    return GroupMetadataData(
      groupId: groupId ?? '',
      name: name,
      picture: picture,
      about: about,
      isOpen: isOpen,
      isPublic: isPublic,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }

  /// Creates a kind-9 group chat message (no subject).
  ///
  /// [groupId] is the group identifier carried in the `h` tag.
  /// [content] is the message body.
  /// [previousEvents] are first-8-char prefixes of recent event IDs for
  /// timeline consistency (spec recommends ≥ 3).
  /// [replyToEventId] is an optional reply target (`e` tag).
  static Event message({
    required String groupId,
    required String content,
    required String secretKey,
    List<String> previousEvents = const [],
    String? replyToEventId,
  }) {
    final tags = <List<String>>[
      ['h', groupId],
      if (previousEvents.isNotEmpty) ['previous', ...previousEvents],
      if (replyToEventId != null) ['e', replyToEventId],
    ];
    return Event.from(
      kind: kindGroupChatMessage,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-11 group thread root message (with subject).
  static Event threadRoot({
    required String groupId,
    required String subject,
    required String content,
    required String secretKey,
    List<String> previousEvents = const [],
  }) {
    final tags = <List<String>>[
      ['h', groupId],
      ['subject', subject],
      if (previousEvents.isNotEmpty) ['previous', ...previousEvents],
    ];
    return Event.from(
      kind: kindGroupThreadRoot,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-12 group thread reply.
  static Event threadReply({
    required String groupId,
    required String replyToEventId,
    required String content,
    required String secretKey,
    List<String> previousEvents = const [],
  }) {
    final tags = <List<String>>[
      ['h', groupId],
      ['e', replyToEventId],
      if (previousEvents.isNotEmpty) ['previous', ...previousEvents],
    ];
    return Event.from(
      kind: kindGroupThreadReply,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-9021 join request.
  static Event joinRequest({
    required String groupId,
    required String secretKey,
    String content = '',
  }) {
    return Event.from(
      kind: kindJoinRequest,
      tags: [
        ['h', groupId],
      ],
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-9022 leave request.
  static Event leaveRequest({
    required String groupId,
    required String secretKey,
    String content = '',
  }) {
    return Event.from(
      kind: kindLeaveRequest,
      tags: [
        ['h', groupId],
      ],
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-39001 group admins event into the pubkey + role list.
  ///
  /// Each `p` tag has the form `["p", pubkey, role?]`. The relay is the
  /// event author per NIP-29.
  ///
  /// Throws [MissingTagException] on missing `d` unless [permissive].
  static GroupAdminsData parseAdmins(Event event, {bool permissive = false}) {
    if (event.kind != kindGroupAdmins) {
      throw InvalidKindException(event.kind, [kindGroupAdmins]);
    }
    final missing = <String>{};
    final groupId = findTagValue(event.tags, 'd');
    if (groupId == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    final admins = <({String pubkey, String? role})>[];
    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'p') continue;
      admins.add((
        pubkey: tag[1],
        role: tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null,
      ));
    }

    return GroupAdminsData(
      groupId: groupId ?? '',
      admins: admins,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }

  /// Parses a kind-39002 group members event into a pubkey list.
  ///
  /// Throws [MissingTagException] on missing `d` unless [permissive].
  static GroupMembersData parseMembers(Event event, {bool permissive = false}) {
    if (event.kind != kindGroupMembers) {
      throw InvalidKindException(event.kind, [kindGroupMembers]);
    }
    final missing = <String>{};
    final groupId = findTagValue(event.tags, 'd');
    if (groupId == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    final members = <String>[];
    for (final tag in event.tags) {
      if (tag.length < 2 || tag[0] != 'p') continue;
      members.add(tag[1]);
    }

    return GroupMembersData(
      groupId: groupId ?? '',
      members: members,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }
}

/// Represents a NIP-29 group chat message (kinds 9, 11, 12).
class GroupMessageData {
  /// The group identifier (from `h` tag).
  final String groupId;

  /// The message content.
  final String content;

  /// The public key of the message author.
  final String pubkey;

  /// Unix timestamp of the message.
  final int createdAt;

  /// The event kind (9, 11, or 12).
  final int kind;

  /// Previous event ID prefixes for timeline ordering (from `previous` tags).
  final List<String> previousEvents;

  /// Event ID this message replies to (from `e` tag), if any.
  final String? replyToEventId;

  /// Thread subject (from `subject` tag), if any (kind 11).
  final String? subject;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-29 requires `h`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [GroupMessageData] with the given fields.
  const GroupMessageData({
    required this.groupId,
    required this.content,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    this.previousEvents = const [],
    this.replyToEventId,
    this.subject,
    this.missingTags = const {},
  });
}

/// Represents NIP-29 group metadata (kind 39000).
class GroupMetadataData {
  /// The group identifier (from `d` tag).
  final String groupId;

  /// The display name of the group.
  final String? name;

  /// The group picture URL.
  final String? picture;

  /// The group description.
  final String? about;

  /// Whether the group allows anyone to join.
  final bool isOpen;

  /// Whether the group's events are visible to non-members.
  final bool isPublic;

  /// The relay's public key that signed this metadata.
  final String pubkey;

  /// Unix timestamp of the metadata event.
  final int createdAt;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-29 requires `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [GroupMetadataData] with the given fields.
  const GroupMetadataData({
    required this.groupId,
    required this.pubkey,
    required this.createdAt,
    this.name,
    this.picture,
    this.about,
    this.isOpen = false,
    this.isPublic = false,
    this.missingTags = const {},
  });
}

/// Parsed kind-39001 group admins event.
class GroupAdminsData {
  /// The group identifier (from `d` tag).
  final String groupId;

  /// Admins and their optional role labels.
  final List<({String pubkey, String? role})> admins;

  /// The relay's pubkey that signed the event.
  final String pubkey;

  /// Unix timestamp of the admins event.
  final int createdAt;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-29 requires `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  const GroupAdminsData({
    required this.groupId,
    required this.admins,
    required this.pubkey,
    required this.createdAt,
    this.missingTags = const {},
  });
}

/// Parsed kind-39002 group members event.
class GroupMembersData {
  /// The group identifier (from `d` tag).
  final String groupId;

  /// Member pubkeys (from `p` tags).
  final List<String> members;

  /// The relay's pubkey that signed the event.
  final String pubkey;

  /// Unix timestamp of the members event.
  final int createdAt;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-29 requires `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  const GroupMembersData({
    required this.groupId,
    required this.members,
    required this.pubkey,
    required this.createdAt,
    this.missingTags = const {},
  });
}

typedef Nip29 = Group;
