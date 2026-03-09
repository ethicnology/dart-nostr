import 'package:nostr/nostr.dart';

/// Reposts — [NIP-18](https://github.com/nostr-protocol/nips/blob/master/18.md)
///
/// Kind 6 for text note reposts (kind 1 only), kind 16 for generic reposts
/// (any other kind). The content is the stringified JSON of the reposted event.
class Nip18 {
  /// Creates a repost event.
  ///
  /// Uses kind 6 if the original event is kind 1, otherwise kind 16.
  /// The [relay] hint MUST be included per spec for the `e` tag.
  /// The content is set to the JSON-serialized original event.
  static Event encode({
    required Event originalEvent,
    required String secretKey,
    required String relay,
  }) {
    final isTextNote = originalEvent.kind == 1;
    final kind = isTextNote ? 6 : 16;

    final List<List<String>> tags = [
      ["e", originalEvent.id, relay],
      ["p", originalEvent.pubkey],
      if (!isTextNote) ["k", originalEvent.kind.toString()],
    ];

    return Event.from(
      kind: kind,
      tags: tags,
      content: originalEvent.toJson(),
      secretKey: secretKey,
    );
  }

  /// Decodes a kind 6 or kind 16 repost event into a [Repost].
  ///
  /// Throws [InvalidKindException] if the event is not kind 6 or 16.
  static Repost decode(Event event) {
    if (event.kind != 6 && event.kind != 16) {
      throw InvalidKindException(event.kind, [6, 16]);
    }
    final eventId = findTagValue(event.tags, 'e') ?? '';
    final repostedPubkey = findTagValue(event.tags, 'p') ?? '';

    Event? originalEvent;
    if (event.content.isNotEmpty) {
      try {
        originalEvent = Event.fromJson(event.content, verify: false);
      } on Exception {
        // Content may be empty or malformed for older events
      }
    }

    return Repost(
      eventId: eventId,
      repostedPubkey: repostedPubkey,
      originalEvent: originalEvent,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// A decoded repost (kind 6 or 16).
class Repost {
  /// The ID of the reposted event.
  final String eventId;

  /// The pubkey of the reposted event's author.
  final String repostedPubkey;

  /// The original event, if the content was valid JSON. May be null.
  final Event? originalEvent;

  /// The pubkey of the user who reposted.
  final String pubkey;

  /// Unix timestamp in seconds.
  final int createdAt;

  Repost({
    required this.eventId,
    required this.repostedPubkey,
    required this.pubkey,
    required this.createdAt,
    this.originalEvent,
  });
}

typedef Reposts = Nip18;
