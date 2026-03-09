import 'package:nostr/nostr.dart';

/// Comments — [NIP-22](https://github.com/nostr-protocol/nips/blob/master/22.md)
///
/// A kind 1111 event for commenting on any content: events, addressable events,
/// or external resources. Root scope is identified by uppercase tags (`E`, `A`,
/// `I`, `K`) and the immediate parent by lowercase (`e`, `a`, `i`, `k`).
///
/// Example:
/// ```json
/// {
///   "kind": 1111,
///   "tags": [
///     ["E", "<root-event-id>", "", "<root-pubkey>"],
///     ["K", "1"],
///     ["e", "<parent-event-id>", "", "<parent-pubkey>"],
///     ["k", "1111"]
///   ],
///   "content": "This is a comment."
/// }
/// ```
class Comment {
  /// Event kind for comments.
  static const int kindComment = 1111;

  /// Creates a kind-1111 comment event.
  ///
  /// [content] is the plaintext comment text.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [rootTag] is the root scope reference — uppercase tag (`E`, `A`, or `I`).
  /// [rootKind] is the kind of the root content (`K` tag).
  /// [parentTag] is the parent reference — lowercase tag (`e`, `a`, or `i`).
  /// [parentKind] is the kind of the parent content (`k` tag).
  /// [rootPubkey] is the root author's pubkey (`P` tag, optional).
  /// [parentPubkey] is the parent author's pubkey (`p` tag, optional).
  ///
  /// Example — commenting on an event:
  /// ```dart
  /// Comment.create(
  ///   content: 'Great post!',
  ///   secretKey: mySecretKey,
  ///   rootTag: ['E', rootEventId, relay, rootAuthorPubkey],
  ///   rootKind: '1',
  ///   parentTag: ['e', parentEventId, relay, parentAuthorPubkey],
  ///   parentKind: '1111',
  /// );
  /// ```
  static Event create({
    required String content,
    required String secretKey,
    required List<String> rootTag,
    required String rootKind,
    required List<String> parentTag,
    required String parentKind,
    String? rootPubkey,
    String? parentPubkey,
  }) {
    final List<List<String>> tags = [
      rootTag,
      ['K', rootKind],
      if (rootPubkey != null) ['P', rootPubkey],
      parentTag,
      ['k', parentKind],
      if (parentPubkey != null) ['p', parentPubkey],
    ];

    return Event.from(
      kind: kindComment,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-1111 event into a [CommentData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 1111.
  static CommentData parse(Event event) {
    if (event.kind != kindComment) {
      throw InvalidKindException(event.kind, [kindComment]);
    }

    // Root scope: uppercase E, A, or I
    final rootEventId = findTagValue(event.tags, 'E');
    final rootCoordinate = findTagValue(event.tags, 'A');
    final rootExternalId = findTagValue(event.tags, 'I');

    // Parent: lowercase e, a, or i
    final parentEventId = findTagValue(event.tags, 'e');
    final parentCoordinate = findTagValue(event.tags, 'a');
    final parentExternalId = findTagValue(event.tags, 'i');

    // Root/parent kind
    final rootKindStr = findTagValue(event.tags, 'K');
    final parentKindStr = findTagValue(event.tags, 'k');

    // Determine root ID (first non-null of E, A, I)
    final String? rootId = rootEventId ?? rootCoordinate ?? rootExternalId;

    // Determine parent ID (first non-null of e, a, i)
    final String? parentId = parentEventId ?? parentCoordinate ?? parentExternalId;

    // Determine root/parent pubkeys from uppercase/lowercase P tags
    final rootPubkey = findTagValue(event.tags, 'P');
    final parentPubkey = findTagValue(event.tags, 'p');

    return CommentData(
      rootId: rootId,
      rootKind: rootKindStr != null ? int.tryParse(rootKindStr) : null,
      rootPubkey: rootPubkey,
      parentId: parentId,
      parentKind: parentKindStr != null ? int.tryParse(parentKindStr) : null,
      parentPubkey: parentPubkey,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// Represents a NIP-22 comment event.
class CommentData {
  /// The root scope identifier (from `E`, `A`, or `I` tag).
  final String? rootId;

  /// The kind of the root event (from `K` tag).
  final int? rootKind;

  /// The public key of the root event author (from `P` tag).
  final String? rootPubkey;

  /// The parent identifier (from `e`, `a`, or `i` tag).
  final String? parentId;

  /// The kind of the parent event (from `k` tag).
  final int? parentKind;

  /// The public key of the parent event author (from `p` tag).
  final String? parentPubkey;

  /// The comment text content (plaintext).
  final String content;

  /// The public key of the comment author.
  final String pubkey;

  /// Unix timestamp of the comment.
  final int createdAt;

  /// Creates a [CommentData] with the given fields.
  const CommentData({
    required this.content,
    required this.pubkey,
    required this.createdAt,
    this.rootId,
    this.rootKind,
    this.rootPubkey,
    this.parentId,
    this.parentKind,
    this.parentPubkey,
  });
}

typedef Nip22 = Comment;
