///This NIP describes how to use "e" and "p" tags in text events,
///especially those that are replies to other text events.
///It helps clients thread the replies into a tree rooted at the original event.

class Nip10 {
  ///{
  ///     "tags": [
  ///         ["e", <kind_40_event_id>, <relay-url>, "root"],
  ///         ["e", <kind_42_event_id>, <relay-url>, "reply"],
  ///         ["p", <pubkey>, <relay-url>],
  ///         ...
  ///     ],
  ///     ...
  /// }
  static Thread fromTags(List<List<String>> tags) {
    ETag root = ETag('', '', '');
    List<ETag> etags = [];
    List<PTag> ptags = [];
    for (var tag in tags) {
      if (tag[0] == "p") ptags.add(PTag(tag[1], tag[2]));
      if (tag[0] == "e") {
        if (tag[3] == 'root') {
          root = ETag(tag[1], tag[2], tag[3]);
        } else {
          etags.add(ETag(tag[1], tag[2], tag[3]));
        }
      }
    }
    return Thread(root, etags, ptags);
  }

  static ETag rootTag(String eventId, String relay) {
    return ETag(eventId, relay, 'root');
  }

  static List<List<String>> toTags(Thread thread) {
    List<List<String>> result = [];
    result.add(
        ["e", thread.root.eventId, thread.root.relayURL, thread.root.marker]);
    for (var etag in thread.etags) {
      result.add(["e", etag.eventId, etag.relayURL, etag.marker]);
    }
    for (var ptag in thread.ptags) {
      result.add(["p", ptag.pubkey, ptag.relayURL]);
    }
    return result;
  }
}

class ETag {
  String eventId;
  String relayURL;
  String marker; // root, reply, mention

  ETag(this.eventId, this.relayURL, this.marker);
}

class PTag {
  String pubkey;
  String relayURL;

  PTag(this.pubkey, this.relayURL);
}

class Thread {
  ETag root;
  List<ETag> etags;
  List<PTag> ptags;
  Thread(this.root, this.etags, this.ptags);
}
