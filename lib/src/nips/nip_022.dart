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
  /// Per NIP-22 spec: tags `K` and `k` MUST be present. Root scope MUST
  /// be identified by exactly one of uppercase `E`/`A`/`I`, parent by
  /// exactly one of lowercase `e`/`a`/`i`.
  ///
  /// Throws [InvalidKindException] if the event kind is not 1111.
  /// Throws [MissingTagException] (in strict mode, default) if required
  /// `K`/`k` (or root/parent scope tags) are absent. In permissive mode
  /// missing tags are recorded on [CommentData.missingTags] instead.
  static CommentData parse(Event event, {bool permissive = false}) {
    if (event.kind != kindComment) {
      throw InvalidKindException(event.kind, [kindComment]);
    }

    final missing = <String>{};

    // Root scope: uppercase E, A, or I (at least one required)
    final rootEventId = findTagValue(event.tags, 'E');
    final rootCoordinate = findTagValue(event.tags, 'A');
    final rootExternalId = findTagValue(event.tags, 'I');
    final String? rootId = rootEventId ?? rootCoordinate ?? rootExternalId;
    if (rootId == null) {
      if (!permissive) throw MissingTagException('E/A/I');
      missing.add('E/A/I');
    }

    // Parent: lowercase e, a, or i (at least one required)
    final parentEventId = findTagValue(event.tags, 'e');
    final parentCoordinate = findTagValue(event.tags, 'a');
    final parentExternalId = findTagValue(event.tags, 'i');
    final String? parentId =
        parentEventId ?? parentCoordinate ?? parentExternalId;
    if (parentId == null) {
      if (!permissive) throw MissingTagException('e/a/i');
      missing.add('e/a/i');
    }

    // Root/parent kind: spec MUST
    final rootKindStr = findTagValue(event.tags, 'K');
    if (rootKindStr == null) {
      if (!permissive) throw MissingTagException('K');
      missing.add('K');
    }
    final parentKindStr = findTagValue(event.tags, 'k');
    if (parentKindStr == null) {
      if (!permissive) throw MissingTagException('k');
      missing.add('k');
    }

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
      missingTags: missing,
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

  /// Names of required tag groups that were absent when parsed in
  /// permissive mode. Possible entries: `'E/A/I'`, `'e/a/i'`, `'K'`,
  /// `'k'`. Empty in strict mode (strict throws instead).
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

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
    this.missingTags = const {},
  });
}

typedef Nip22 = Comment;
