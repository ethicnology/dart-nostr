import 'package:nostr/nostr.dart';

/// User statuses — [NIP-38](https://github.com/nostr-protocol/nips/blob/master/38.md)
///
/// A kind 30315 addressable event representing a user's current status.
/// The `d` tag identifies the status type ("general", "music", or custom).
/// Content holds the status text, and optional tags include `r` (URL),
/// `expiration` (Unix timestamp), and reference tags (`e`, `p`, `a`).
///
/// Example:
/// ```json
/// {
///   "kind": 30315,
///   "tags": [
///     ["d", "music"],
///     ["r", "spotify:track:abc123"],
///     ["expiration", "1692000000"]
///   ],
///   "content": "Listening to Dark Side of the Moon"
/// }
/// ```
class UserStatus {
  /// Event kind for user status.
  static const int kindUserStatus = 30315;

  /// Creates a kind-30315 user status event.
  ///
  /// [statusType] is the `d` tag value: "general", "music", or custom.
  /// [content] is the status text. Empty string clears the status.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [url] is an optional reference URL (`r` tag).
  /// [expiration] is an optional Unix timestamp when the status expires.
  static Event create({
    required String statusType,
    required String content,
    required String secretKey,
    String? url,
    int? expiration,
  }) {
    final List<List<String>> tags = [
      ['d', statusType],
      if (url != null) ['r', url],
      if (expiration != null) ['expiration', expiration.toString()],
    ];

    return Event.from(
      kind: kindUserStatus,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-30315 event into a [UserStatusData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 30315.
  /// Throws [MissingTagException] if the `d` tag is absent.
  static UserStatusData parse(Event event) {
    if (event.kind != kindUserStatus) {
      throw InvalidKindException(event.kind, [kindUserStatus]);
    }

    final statusType = findTagValue(event.tags, 'd');
    if (statusType == null) {
      throw MissingTagException('d');
    }

    final url = findTagValue(event.tags, 'r');
    final expirationStr = findTagValue(event.tags, 'expiration');
    final eventRef = findTagValue(event.tags, 'e');
    final pubkeyRef = findTagValue(event.tags, 'p');
    final coordRef = findTagValue(event.tags, 'a');

    return UserStatusData(
      statusType: statusType,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      url: url,
      expiration:
          expirationStr != null ? int.tryParse(expirationStr) : null,
      eventRef: eventRef,
      pubkeyRef: pubkeyRef,
      coordinateRef: coordRef,
    );
  }
}

/// Represents a NIP-38 user status event.
class UserStatusData {
  /// The status type identifier (from `d` tag): "general", "music", or custom.
  final String statusType;

  /// The status text content.
  final String content;

  /// The public key of the status author.
  final String pubkey;

  /// Unix timestamp of the status event.
  final int createdAt;

  /// Optional reference URL (from `r` tag).
  final String? url;

  /// Optional expiration timestamp (from `expiration` tag).
  final int? expiration;

  /// Optional referenced event ID (from `e` tag).
  final String? eventRef;

  /// Optional referenced pubkey (from `p` tag).
  final String? pubkeyRef;

  /// Optional referenced addressable event coordinate (from `a` tag).
  final String? coordinateRef;

  /// Creates a [UserStatusData] with the given fields.
  const UserStatusData({
    required this.statusType,
    required this.content,
    required this.pubkey,
    required this.createdAt,
    this.url,
    this.expiration,
    this.eventRef,
    this.pubkeyRef,
    this.coordinateRef,
  });
}

typedef Nip38 = UserStatus;
typedef UserStatuses = UserStatus;
