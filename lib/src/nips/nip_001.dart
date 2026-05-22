import 'package:nostr/nostr.dart';

/// Basic protocol flow — [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md)
///
/// 0: set_metadata: the content is set to a stringified JSON object
/// {name: `username`, about: `string`, picture: `url`} describing the user
/// who created the event.
///
/// 1: text_note: the content is set to the plaintext content of a note
/// (anything the user wants to say).
class Note {
  /// Event kind for user metadata (`set_metadata`).
  static const int kindMetadata = 0;

  /// Event kind for a short text note.
  static const int kindShortNote = 1;

  /// Creates a kind-0 set_metadata event.
  ///
  /// [content] is a JSON-stringified object with `name`, `about`, `picture`.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event setMetadata({
    required String content,
    required String secretKey,
  }) {
    return Event.from(
      kind: kindMetadata,
      tags: [],
      content: content,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-1 text note event with optional threading.
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
  static Event create({
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

    return Event.from(
        kind: kindShortNote,
        tags: tags,
        content: content,
        secretKey: secretKey);
  }

  /// Extracts hashtag values from event tags.
  ///
  /// Returns the values of every `t` tag in [tags], or an empty list
  /// when none are present.
  static List<String> extractHashTags(List<List<String>> tags) {
    return findAllTagValues(tags, 't');
  }

  /// Returns the quote-repost event ID from a `q` tag, or null if absent.
  static String? quoteRepostId(List<List<String>> tags) {
    return findTagValue(tags, 'q');
  }

  /// Returns the group ID from an `h` tag, or null if absent.
  static String? groupId(List<List<String>> tags) {
    return findTagValue(tags, 'h');
  }

  /// Parses a kind 1 short text note, or kind 11 / 12 NIP-29 group
  /// thread root / reply, into a [NoteData].
  ///
  /// Throws [InvalidKindException] if the event kind is not one of these.
  static NoteData parse(Event event) {
    if (event.kind == kindShortNote ||
        event.kind == Group.kindGroupThreadRoot ||
        event.kind == Group.kindGroupThreadReply) {
      return NoteData(
        id: event.id,
        pubkey: event.pubkey,
        createdAt: event.createdAt,
        thread: Nip10.parseTags(event.tags),
        content: event.content,
        hashTags: extractHashTags(event.tags),
        quoteRepostId: quoteRepostId(event.tags),
        groupId: groupId(event.tags),
      );
    }
    throw InvalidKindException(event.kind, [
      kindShortNote,
      Group.kindGroupThreadRoot,
      Group.kindGroupThreadReply,
    ]);
  }
}

/// A decoded text note (kind 1, 11, 12).
class NoteData {
  /// The event ID.
  final String id;

  /// The author's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// Thread references parsed from `e` and `p` tags. A note with no
  /// such tags yields a [Thread] with an empty-sentinel `root` and
  /// empty `etags`/`ptags` lists — check `thread.root.eventId.isEmpty`
  /// (and the lists) to detect a thread-less note.
  final Thread thread;

  /// The plaintext content of the note.
  final String content;

  /// Hashtag values extracted from `t` tags.
  final List<String> hashTags;

  /// The quote-repost event ID from a `q` tag, if present.
  final String? quoteRepostId;

  /// The group ID from an `h` tag, if present.
  final String? groupId;

  /// Creates a [NoteData] with the given fields.
  const NoteData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.content,
    required this.thread,
    this.hashTags = const [],
    this.quoteRepostId,
    this.groupId,
  });
}

typedef Nip1 = Note;
typedef TextNote = Note;
