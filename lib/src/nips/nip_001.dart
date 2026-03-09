import 'package:nostr/nostr.dart';

/// Basic protocol flow — [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
///
/// 0: set_metadata: the content is set to a stringified JSON object
/// {name: `username`, about: `string`, picture: `url`} describing the user
/// who created the event.
///
/// 1: text_note: the content is set to the plaintext content of a note
/// (anything the user wants to say).
class Nip1 {
  /// Encodes a kind-0 set_metadata event.
  ///
  /// [content] is a JSON-stringified object with `name`, `about`, `picture`.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event encodeSetMetadata({
    required String content,
    required String secretKey,
  }) {
    return Event.from(
      kind: 0,
      tags: [],
      content: content,
      secretKey: secretKey,
    );
  }

  /// Encodes a kind-1 text note event with optional threading.
  ///
  /// [content] is the plaintext note body.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [rootEvent] is the event ID of the thread root (optional).
  /// [rootEventRelay] is the relay URL for the root event (optional).
  /// [replyEvent] is the event ID being replied to (optional).
  /// [replyEventRelay] is the relay URL for the reply event (optional).
  /// [replyUsers] is a list of pubkeys to tag (optional).
  /// [replyUserRelays] is a list of relay URLs for the tagged users (optional).
  /// [hashTags] is a list of hashtag strings (optional).
  static Event encodeTextNote({
    required String content,
    required String secretKey,
    String? rootEvent,
    String? rootEventRelay,
    String? replyEvent,
    String? replyEventRelay,
    List<String>? replyUsers,
    List<String>? replyUserRelays,
    List<String>? hashTags,
  }) {
    List<List<String>> tags = [];
    if (rootEvent != null) {
      final ETag root = Nip10.rootTag(rootEvent, rootEventRelay ?? '');

      final List<ETag> reply = replyEvent == null
          ? <ETag>[]
          : [Nip10.replyTag(replyEvent, replyEventRelay ?? '')];

      final Thread thread = Thread(root: root, etags: reply);
      tags = Nip10.toTags(thread);
    }

    final List<PTag> pTags =
        Nip10.pTags(replyUsers ?? [], replyUserRelays ?? []);

    for (final pTag in pTags) {
      tags.add(["p", pTag.pubkey, pTag.relayURL]);
    }

    if (hashTags != null) {
      for (final t in hashTags) {
        tags.add(['t', t]);
      }
    }

    return Event.from(kind: 1, tags: tags, content: content, secretKey: secretKey);
  }

  /// Extracts hashtag values from event tags.
  ///
  /// Returns a list of strings from all `t` tags, or null if none.
  static List<String>? extractHashTags(List<List<String>> tags) {
    final result = findAllTagValues(tags, 't');
    return result.isNotEmpty ? result : null;
  }

  /// Returns the quote-repost event ID from a `q` tag, or null if absent.
  static String? quoteRepostId(List<List<String>> tags) {
    return findTagValue(tags, 'q');
  }

  /// Returns the group ID from an `h` tag, or null if absent.
  static String? groupId(List<List<String>> tags) {
    return findTagValue(tags, 'h');
  }

  /// Decodes a kind 1, 11, or 12 event into a [Note].
  ///
  /// Throws [InvalidKindException] if the event kind is not 1, 11, or 12.
  static Note decodeTextNote(Event event) {
    if (event.kind == 1 || event.kind == 11 || event.kind == 12) {
      return Note(
        id: event.id,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        thread: Nip10.fromTags(event.tags),
        content: event.content,
        hashTags: extractHashTags(event.tags),
        quoteRepostId: quoteRepostId(event.tags),
        groupId: groupId(event.tags),
      );
    }
    throw InvalidKindException(event.kind, [1, 11, 12]);
  }
}

/// A decoded text note (kind 1, 11, 12).
class Note {
  /// The event ID.
  final String id;

  /// The author's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// Thread references parsed from `e` and `p` tags.
  final Thread? thread;

  /// The plaintext content of the note.
  final String content;

  /// Hashtag values extracted from `t` tags.
  final List<String>? hashTags;

  /// The quote-repost event ID from a `q` tag, if present.
  final String? quoteRepostId;

  /// The group ID from an `h` tag, if present.
  final String? groupId;

  /// Creates a [Note] with the given fields.
  const Note({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.content,
    this.thread,
    this.hashTags,
    this.quoteRepostId,
    this.groupId,
  });
}

typedef TextNote = Nip1;
