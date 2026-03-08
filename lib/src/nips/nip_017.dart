import 'package:nostr/nostr.dart';

class Nip17 {
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

  static Future<Event> decode({
    required Event giftWrap,
    required String receiverSecretKey,
  }) async {
    final dm = await Nip59.unwrap(
      giftWrap: giftWrap,
      recipientSecretKey: receiverSecretKey,
    );

    if (dm.kind != 14) {
      throw Exception('NIP-17 define private direct messages with kind=14');
    }

    return dm;
  }
}

typedef DirectMessage = Nip17;
