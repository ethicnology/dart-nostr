import 'package:nostr/nostr.dart';

/// Reactions — [NIP-25](https://github.com/nostr-protocol/nips/blob/master/25.md)
///
/// A kind 7 event used to react to other events. The content field indicates
/// the reaction value: `+` for like, `-` for dislike, or an emoji.
class Nip25 {
  /// Creates a kind 7 reaction event.
  ///
  /// [eventId] is the ID of the event being reacted to.
  /// [eventPubkey] is the pubkey of the event being reacted to.
  /// [content] is the reaction value: `+`, `-`, or an emoji. Defaults to `+`.
  /// [relay] is an optional relay hint for the referenced event.
  /// [eventKind] is the kind of the event being reacted to (`k` tag per spec).
  /// [addressableCoord] is the NIP-33 coordinate for addressable events (`a` tag).
  static Event encode({
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
      kind: 7,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Decodes a kind 7 event into a [Reaction].
  ///
  /// Throws [InvalidKindException] if the event is not kind 7.
  static Reaction decode(Event event) {
    if (event.kind != 7) {
      throw InvalidKindException(event.kind, [7]);
    }
    final eventId = findTagValue(event.tags, 'e') ?? '';
    final reactedPubkey = findTagValue(event.tags, 'p') ?? '';
    final kindStr = findTagValue(event.tags, 'k');
    final reactedKind = kindStr != null ? int.tryParse(kindStr) : null;

    return Reaction(
      eventId: eventId,
      reactedPubkey: reactedPubkey,
      reactedKind: reactedKind,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// A decoded reaction (kind 7).
class Reaction {
  /// The ID of the event being reacted to.
  final String eventId;

  /// The pubkey of the event being reacted to.
  final String reactedPubkey;

  /// The kind of the event being reacted to (from `k` tag), if present.
  final int? reactedKind;

  /// The reaction value: `+` (like), `-` (dislike), or an emoji.
  final String content;

  /// The pubkey of the user who reacted.
  final String pubkey;

  /// Unix timestamp in seconds.
  final int createdAt;

  Reaction({
    required this.eventId,
    required this.reactedPubkey,
    required this.content,
    required this.pubkey,
    required this.createdAt,
    this.reactedKind,
  });
}

typedef Reactions = Nip25;
