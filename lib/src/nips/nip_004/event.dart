import 'package:bip340/bip340.dart' as bip340;

import '../../event.dart';
import '../../utils.dart';
import 'crypto.dart';

class EncryptedDirectMessage extends Event {
  late String peerPubkey;
  late String? plaintext;
  late String? referenceEventId;

  EncryptedDirectMessage(
    this.peerPubkey,
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig, {
    subscriptionId,
    bool verify = false,
    this.plaintext,
    this.referenceEventId,
  }) : super(
          id,
          pubkey,
          createdAt,
          kind,
          tags,
          content,
          sig,
          subscriptionId: subscriptionId,
          verify: verify,
        ) {
    kind = 4;
    plaintext = content;
  }

  factory EncryptedDirectMessage.partial({
    peerPubkey = "",
    id = "",
    pubkey = "",
    createdAt = 0,
    kind = 4,
    tags = const <List<String>>[],
    content = "",
    sig = "",
    plaintext,
    referenceEventId,
    subscriptionId,
    bool verify = false,
  }) {
    return EncryptedDirectMessage(
      peerPubkey,
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      plaintext: plaintext,
      referenceEventId: referenceEventId,
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }

  factory EncryptedDirectMessage.newEvent(
    String peerPubkey,
    String plaintext,
    String privkey, {
    String? referenceEventId,
  }) {
    EncryptedDirectMessage event = EncryptedDirectMessage.partial();
    event.content = Nip04.encryptMessage(privkey, '02$peerPubkey', plaintext);
    event.kind = 4;
    event.createdAt = currentUnixTimestampSeconds();
    event.pubkey = bip340.getPublicKey(privkey).toLowerCase();
    event.tags = [
      ['p', peerPubkey],
    ];
    event.peerPubkey = peerPubkey;
    event.plaintext = plaintext;
    if (referenceEventId != null) {
      event.tags.add(['e', referenceEventId]);
    }
    event.id = event.getEventId();
    event.sig = event.getSignature(privkey);
    return event;
  }
}
