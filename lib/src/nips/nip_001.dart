import 'package:nostr/nostr.dart';

/// Basic Event Kinds
/// 0: set_metadata: the content is set to a stringified JSON object {name: `username`, about: `string`, picture: `url`} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
/// 1: text_note: the content is set to the plaintext content of a note (anything the user wants to say). Do not use Markdown! Clients should not have to guess how to interpret content like [](). Use different event kinds for parsable content.
class Nip1 {
  static Event encodeSetMetadata({
    required String content,
    required String privkey,
  }) {
    return Event.from(
      kind: 0,
      tags: [],
      content: content,
      privkey: privkey,
    );
  }

  static Event encodeTextNote(
    String content,
    String privkey, {
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

    return Event.from(kind: 1, tags: tags, content: content, privkey: privkey);
  }

  static List<String>? hashTags(List<List<String>> tags) {
    final List<String> hashTags = [];
    for (final tag in tags) {
      if (tag[0] == 't') hashTags.add(tag[1]);
    }
    return hashTags;
  }

  static String? quoteRepostId(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag[0] == 'q') return tag[1];
    }
    return null;
  }

  static String? groupId(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag[0] == 'h') return tag[1];
    }
    return null;
  }

  static TextNote decodeTextNote(Event event) {
    if (event.kind == 1 || event.kind == 11 || event.kind == 12) {
      return TextNote(
        event.id,
        event.pubkey,
        event.createdAt,
        Nip10.fromTags(event.tags),
        event.content,
        hashTags(event.tags),
        quoteRepostId(event.tags),
        groupId(event.tags),
      );
    }
    throw Exception("${event.kind} is not nip1 compatible");
  }
}

class TextNote {
  String nodeId;
  String pubkey;
  int createdAt;
  Thread? thread;
  String content;
  List<String>? hashTags;
  String? quoteRepostId;
  String? groupId;

  TextNote(
    this.nodeId,
    this.pubkey,
    this.createdAt,
    this.thread,
    this.content,
    this.hashTags,
    this.quoteRepostId,
    this.groupId,
  );
}
