import 'package:bip340/bip340.dart' as bip340;
import 'package:nostr/src/event.dart';
import 'package:nostr/src/nips/nip_004/crypto.dart';
import 'package:nostr/src/utils.dart';

class EncryptedDirectMessage extends Event {
  static Map<String, List<List<int>>> gMapByteSecret = {};

  EncryptedDirectMessage(Event event)
      : super(
          event.id,
          event.pubkey,
          event.createdAt,
          4,
          event.tags,
          event.content,
          event.sig,
          subscriptionId: event.subscriptionId,
          verify: true,
        );

  factory EncryptedDirectMessage.quick(
    String senderPrivkey,
    String receiverPubkey,
    String message,
  ) {
    var event = Event.partial();
    event.pubkey = bip340.getPublicKey(senderPrivkey).toLowerCase();
    event.createdAt = currentUnixTimestampSeconds();
    event.kind = 4;
    event.tags = [
      ['p', receiverPubkey]
    ];
    event.content = Nip4.cipher(senderPrivkey, '02$receiverPubkey', message);
    event.id = event.getEventId();
    event.sig = event.getSignature(senderPrivkey);
    return EncryptedDirectMessage(event);
  }

  String? get receiverPubkey => findPubkey();

  String getCiphertext(String senderPrivkey, String receiverPubkey) {
    String ciphertext =
        Nip4.cipher(senderPrivkey, '02$receiverPubkey', content);
    return ciphertext;
  }

  String getPlaintext(String receiverPrivkey, String senderPubkey) {
    return Nip4.decipher(receiverPrivkey, senderPubkey, content);
  }

  String? findPubkey() {
    String prefix = "p";
    for (List<String> tag in tags) {
      if (tag.isNotEmpty && tag[0] == prefix && tag.length > 1) return tag[1];
    }
    return null;
  }
}
