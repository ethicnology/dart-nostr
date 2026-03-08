import 'package:nostr/nostr.dart';

/// Private direct messages — [NIP-17](https://github.com/nostr-protocol/nips/blob/master/17.md)
class Nip17 {
  /// Encodes a private direct message as a gift-wrapped event.
  ///
  /// [message] is the plaintext message body.
  /// [authorSecretKey] is the sender's hex-encoded secret key.
  /// [receiverPubkey] is the recipient's hex-encoded public key.
  ///
  /// Returns a kind-1059 gift wrap event ready for broadcast.
  static Future<Event> encode({
    required String message,
    required String authorSecretKey,
    required String receiverPubkey,
  }) async {
    final authorPubkey = Keys(authorSecretKey).public;

    final rumor = Event.partial(
      pubkey: authorPubkey,
      kind: 14,
      content: message,
      tags: [
        ['p', receiverPubkey]
      ],
    );
    rumor.id = rumor.getEventId();
    // Kind 14s MUST never be signed.
    // If it is signed, the message might leak to relays and become fully public.
    rumor.sig = '';

    return Nip59.wrap(
      rumor: rumor,
      authorSecretKey: authorSecretKey,
      recipientPubkey: receiverPubkey,
    );
  }

  /// Decodes a gift-wrapped private direct message.
  ///
  /// [giftWrap] is the kind-1059 event to unwrap.
  /// [receiverSecretKey] is the recipient's hex-encoded secret key.
  ///
  /// Returns the inner kind-14 rumor event.
  /// Throws [InvalidKindException] if the unwrapped event is not kind 14.
  static Future<Event> decode({
    required Event giftWrap,
    required String receiverSecretKey,
  }) async {
    final dm = await Nip59.unwrap(
      giftWrap: giftWrap,
      recipientSecretKey: receiverSecretKey,
    );

    if (dm.kind != 14) {
      throw InvalidKindException(dm.kind, [14]);
    }

    return dm;
  }
}

typedef DirectMessage = Nip17;
