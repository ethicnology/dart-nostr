/// Text note threading — [NIP-10](https://github.com/nostr-protocol/nips/blob/master/10.md)
///
/// This NIP describes how to use "e" and "p" tags in text events,
/// especially those that are replies to other text events.
/// It helps clients thread the replies into a tree rooted at the original event.
class Threading {
  /// Parses `e` and `p` tags from an event into a [Thread].
  ///
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
    ETag root = const ETag();
    final List<ETag> etags = [];
    final List<PTag> ptags = [];
    for (final tag in tags) {
      if (tag[0] == "p" && tag.length >= 3) {
        ptags.add(PTag(pubkey: tag[1], relayURL: tag[2]));
      }
      if (tag[0] == "e") {
        final eventId = tag.length > 1 ? tag[1] : '';
        final relay = tag.length > 2 ? tag[2] : '';
        final marker = tag.length > 3 ? tag[3] : '';
        if (marker == 'root') {
          root = ETag(eventId: eventId, relayURL: relay, marker: marker);
        } else {
          etags.add(ETag(eventId: eventId, relayURL: relay, marker: marker));
        }
      }
    }
    return Thread(root: root, etags: etags, ptags: ptags);
  }

  /// Creates an [ETag] with the `reply` marker.
  static ETag replyTag(String eventId, String relay) {
    return ETag(eventId: eventId, relayURL: relay, marker: 'reply');
  }

  /// Builds a list of [PTag]s from parallel lists of pubkeys and relays.
  ///
  /// If [relays] is shorter than [pubkeys], missing entries default to `''`.
  static List<PTag> pTags(List<String> pubkeys, List<String> relays) {
    final List<PTag> result = [];
    for (int i = 0; i < pubkeys.length; ++i) {
      result.add(PTag(pubkey: pubkeys[i], relayURL: relays.length > i ? relays[i] : ''));
    }
    return result;
  }

  /// Creates an [ETag] with the `root` marker.
  static ETag rootTag(String eventId, String relay) {
    return ETag(eventId: eventId, relayURL: relay, marker: 'root');
  }

  /// Converts a [Thread] back into a list of `e` and `p` tag arrays.
  static List<List<String>> toTags(Thread thread) {
    final List<List<String>> result = [];
    result.add(
        ["e", thread.root.eventId, thread.root.relayURL, thread.root.marker]);
    for (final etag in thread.etags) {
      result.add(["e", etag.eventId, etag.relayURL, etag.marker]);
    }
    for (final ptag in thread.ptags) {
      result.add(["p", ptag.pubkey, ptag.relayURL]);
    }
    return result;
  }
}

/// An `e` (event) tag with optional relay URL and marker.
class ETag {
  /// The referenced event ID.
  final String eventId;

  /// The relay URL where the event can be found.
  final String relayURL;

  /// The marker indicating the role: `root`, `reply`, or `mention`.
  final String marker;

  /// Creates an [ETag] with the given fields.
  const ETag({this.eventId = '', this.relayURL = '', this.marker = ''});
}

/// A `p` (pubkey) tag with optional relay URL.
class PTag {
  /// The referenced public key.
  final String pubkey;

  /// The relay URL where events from this pubkey can be found.
  final String relayURL;

  /// Creates a [PTag] with the given fields.
  const PTag({required this.pubkey, this.relayURL = ''});
}

/// A thread structure parsed from `e` and `p` tags.
class Thread {
  /// The root event tag of the thread.
  final ETag root;

  /// Reply and mention event tags.
  final List<ETag> etags;

  /// Referenced pubkey tags.
  final List<PTag> ptags;

  /// Creates a [Thread] with the given fields.
  const Thread({required this.root, this.etags = const [], this.ptags = const []});
}

typedef Nip10 = Threading;
