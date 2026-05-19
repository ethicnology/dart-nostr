import 'package:nostr/nostr.dart';

/// Reactions — [NIP-25](https://github.com/nostr-protocol/nips/blob/master/25.md)
///
/// A kind 7 event used to react to other events. The content field indicates
/// the reaction value: `+` for like, `-` for dislike, or an emoji.
class Reaction {
  /// Event kind for reactions.
  static const int kindReaction = 7;

  /// Creates a kind 7 reaction event.
  ///
  /// [eventId] is the ID of the event being reacted to.
  /// [eventPubkey] is the pubkey of the event being reacted to.
  /// [content] is the reaction value: `+`, `-`, or an emoji. Defaults to `+`.
  /// [relay] is an optional relay hint for the referenced event.
  /// [eventKind] is the kind of the event being reacted to (`k` tag per spec).
  /// [addressableCoord] is the NIP-33 coordinate for addressable events (`a` tag).
  static Event create({
    required String eventId,
    required String eventPubkey,
    required String secretKey,
    String content = '+',
    String? relay,
    int? eventKind,
    String? addressableCoord,
  }) {
    final List<List<String>> tags = [
      ["e", eventId, if (relay != null) relay],
      if (addressableCoord != null) ["a", addressableCoord],
      ["p", eventPubkey],
      if (eventKind != null) ["k", eventKind.toString()],
    ];

    return Event.from(
      kind: kindReaction,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind 7 event into a [ReactionData].
  ///
  /// Per NIP-25: "If multiple `e` tags are present, the target of the
  /// reaction SHOULD be the LAST one." Same rule for `p`. We respect that
  /// here — `findTagValue` would return the first match.
  ///
  /// Throws [InvalidKindException] if the event is not kind 7.
  static ReactionData parse(Event event) {
    if (event.kind != kindReaction) {
      throw InvalidKindException(event.kind, [kindReaction]);
    }

    String eventId = '';
    String reactedPubkey = '';
    String? relay;
    for (final tag in event.tags) {
      if (tag.length < 2) continue;
      if (tag[0] == 'e') {
        eventId = tag[1];
        relay = tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null;
      } else if (tag[0] == 'p') {
        reactedPubkey = tag[1];
      }
    }

    final kindStr = findTagValue(event.tags, 'k');
    final reactedKind = kindStr != null ? int.tryParse(kindStr) : null;
    final coordinate = findTagValue(event.tags, 'a');

    return ReactionData(
      eventId: eventId,
      reactedPubkey: reactedPubkey,
      reactedKind: reactedKind,
      relay: relay,
      addressableCoord: coordinate,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// A decoded reaction (kind 7).
class ReactionData {
  /// The ID of the event being reacted to (LAST `e` tag per spec).
  final String eventId;

  /// The pubkey of the event being reacted to (LAST `p` tag per spec).
  final String reactedPubkey;

  /// The kind of the event being reacted to (from `k` tag), if present.
  final int? reactedKind;

  /// Optional relay hint from the `e` tag third element.
  final String? relay;

  /// Optional addressable-event coordinate from the `a` tag.
  final String? addressableCoord;

  /// The reaction value: `+` (like), `-` (dislike), or an emoji.
  final String content;

  /// The pubkey of the user who reacted.
  final String pubkey;

  /// Unix timestamp in seconds.
  final int createdAt;

  const ReactionData({
    required this.eventId,
    required this.reactedPubkey,
    required this.content,
    required this.pubkey,
    required this.createdAt,
    this.reactedKind,
    this.relay,
    this.addressableCoord,
  });
}

typedef Nip25 = Reaction;
