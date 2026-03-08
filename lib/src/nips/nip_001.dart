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

      final Thread thread = Thread(root, reply, []);
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
  /// Returns a list of strings from all `t` tags, or an empty list if none.
  static List<String>? extractHashTags(List<List<String>> tags) {
    final List<String> result = [];
    for (final tag in tags) {
      if (tag[0] == 't') result.add(tag[1]);
    }
    return result;
  }

  /// Returns the quote-repost event ID from a `q` tag, or null if absent.
  static String? quoteRepostId(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag[0] == 'q') return tag[1];
    }
    return null;
  }

  /// Returns the group ID from an `h` tag, or null if absent.
  static String? groupId(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag[0] == 'h') return tag[1];
    }
    return null;
  }

  /// Decodes a kind 1, 11, or 12 event into a [Note].
  ///
  /// Throws [InvalidKindException] if the event kind is not 1, 11, or 12.
  static Note decodeTextNote(Event event) {
    if (event.kind == 1 || event.kind == 11 || event.kind == 12) {
      return Note(
        event.id,
        event.pubkey,
        event.createdAt,
        Nip10.fromTags(event.tags),
        event.content,
        extractHashTags(event.tags),
        quoteRepostId(event.tags),
        groupId(event.tags),
      );
    }
    throw InvalidKindException(event.kind, [1, 11, 12]);
  }
}

/// A decoded text note (kind 1, 11, 12).
class Note {
  /// The event ID.
  String id;

  /// The author's public key.
  String pubkey;

  /// Unix timestamp of the event creation.
  int createdAt;

  /// Thread references parsed from `e` and `p` tags.
  Thread? thread;

  /// The plaintext content of the note.
  String content;

  /// Hashtag values extracted from `t` tags.
  List<String>? hashTags;

  /// The quote-repost event ID from a `q` tag, if present.
  String? quoteRepostId;

  /// The group ID from an `h` tag, if present.
  String? groupId;

  /// Creates a [Note] with the given fields.
  Note(
    this.id,
    this.pubkey,
    this.createdAt,
    this.thread,
    this.content,
    this.hashTags,
    this.quoteRepostId,
    this.groupId,
  );
}

typedef TextNote = Nip1;
