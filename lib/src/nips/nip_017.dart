import 'package:nostr/nostr.dart';

/// Private direct messages — [NIP-17](https://github.com/nostr-protocol/nips/blob/master/17.md)
class DirectMessage {
  /// Event kind for the inner DM rumor.
  static const int kindDirectMessage = 14;

  /// Creates a private direct message as a gift-wrapped event.
  ///
  /// [message] is the plaintext message body.
  /// [authorSecretKey] is the sender's hex-encoded secret key.
  /// [recipientPubkey] is the recipient's hex-encoded public key.
  ///
  /// Returns a kind-1059 gift wrap event ready for broadcast.
  static Future<Event> create({
    required String message,
    required String authorSecretKey,
    required String recipientPubkey,
  }) async {
    final authorPubkey = Keys(authorSecretKey).public;

    final rumor = Event.partial(
      pubkey: authorPubkey,
      kind: kindDirectMessage,
      content: message,
      tags: [
        ['p', recipientPubkey]
      ],
    );
    rumor.id = rumor.getEventId();
    // Kind 14s MUST never be signed.
    // If it is signed, the message might leak to relays and become fully public.
    rumor.sig = '';

    return Nip59.wrap(
      rumor: rumor,
      authorSecretKey: authorSecretKey,
      recipientPubkey: recipientPubkey,
    );
  }

  /// Parses a gift-wrapped private direct message.
  ///
  /// [giftWrap] is the kind-1059 event to unwrap.
  /// [recipientSecretKey] is the recipient's hex-encoded secret key.
  ///
  /// Returns the inner kind-14 rumor event.
  /// Throws [InvalidKindException] if the unwrapped event is not kind 14.
  static Future<Event> parse({
    required Event giftWrap,
    required String recipientSecretKey,
  }) async {
    final dm = await Nip59.unwrap(
      giftWrap: giftWrap,
      recipientSecretKey: recipientSecretKey,
    );

    if (dm.kind != kindDirectMessage) {
      throw InvalidKindException(dm.kind, [kindDirectMessage]);
    }

    return dm;
  }
}

typedef Nip17 = DirectMessage;
