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
class Nip29 {
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

  /// Decodes a group chat event into a [GroupMessage].
  ///
  /// Accepts kinds 9, 11, and 12 (the user-facing chat kinds).
  /// Throws [InvalidKindException] if the event kind is not one of these.
  /// Throws [MissingTagException] if the `h` tag is absent.
  static GroupMessage decode(Event event) {
    if (event.kind != kindGroupChatMessage &&
        event.kind != kindGroupThreadRoot &&
        event.kind != kindGroupThreadReply) {
      throw InvalidKindException(event.kind, [
        kindGroupChatMessage,
        kindGroupThreadRoot,
        kindGroupThreadReply,
      ]);
    }

    final groupId = findTagValue(event.tags, 'h');
    if (groupId == null) {
      throw MissingTagException('h');
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

    return GroupMessage(
      groupId: groupId,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      previousEvents: previousEvents,
      replyToEventId: replyToEventId,
      subject: subject,
    );
  }

  /// Decodes a kind 39000 event into [GroupMetadata].
  ///
  /// Throws [InvalidKindException] if the event kind is not 39000.
  static GroupMetadata decodeMetadata(Event event) {
    if (event.kind != kindGroupMetadata) {
      throw InvalidKindException(event.kind, [kindGroupMetadata]);
    }

    final groupId = findTagValue(event.tags, 'd') ?? '';
    final name = findTagValue(event.tags, 'name');
    final picture = findTagValue(event.tags, 'picture');
    final about = findTagValue(event.tags, 'about');

    // Privacy flags: presence of these tags indicates the property
    final bool isOpen =
        event.tags.any((t) => t.isNotEmpty && t[0] == 'open');
    final bool isPublic =
        event.tags.any((t) => t.isNotEmpty && t[0] == 'public');

    return GroupMetadata(
      groupId: groupId,
      name: name,
      picture: picture,
      about: about,
      isOpen: isOpen,
      isPublic: isPublic,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// Represents a NIP-29 group chat message (kinds 9, 11, 12).
class GroupMessage {
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

  /// Creates a [GroupMessage] with the given fields.
  const GroupMessage({
    required this.groupId,
    required this.content,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    this.previousEvents = const [],
    this.replyToEventId,
    this.subject,
  });
}

/// Represents NIP-29 group metadata (kind 39000).
class GroupMetadata {
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

  /// Creates a [GroupMetadata] with the given fields.
  const GroupMetadata({
    required this.groupId,
    required this.pubkey,
    required this.createdAt,
    this.name,
    this.picture,
    this.about,
    this.isOpen = false,
    this.isPublic = false,
  });
}

typedef Groups = Nip29;
