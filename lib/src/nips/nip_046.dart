import 'package:nostr/nostr.dart';

/// Nostr Connect (remote signing) — [NIP-46](https://github.com/nostr-protocol/nips/blob/master/46.md)
///
/// Kind 24133 events carry NIP-44 encrypted JSON-RPC payloads between a
/// client and a remote signer. The content is opaque without decryption,
/// so this class exposes the event structure and tags only.
///
/// Supported methods include `connect`, `sign_event`, `get_public_key`,
/// `nip44_encrypt`, `nip44_decrypt`, `nip04_encrypt`, `nip04_decrypt`,
/// and `ping`.
class Nip46 {
  /// The event kind used for Nostr Connect messages.
  static const int kind = 24133;

  /// Encodes a kind-24133 Nostr Connect event.
  ///
  /// [encryptedContent] is the NIP-44 encrypted JSON-RPC payload.
  /// [targetPubkey] is the hex-encoded public key of the recipient
  /// (remote signer or client).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event encode({
    required String encryptedContent,
    required String targetPubkey,
    required String secretKey,
  }) {
    return Event.from(
      kind: 24133,
      tags: [
        ['p', targetPubkey],
      ],
      content: encryptedContent,
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-24133 event into a [NostrConnectEvent].
  ///
  /// Throws [InvalidKindException] if the event kind is not 24133.
  /// Throws [MissingTagException] if the required `p` tag is absent.
  static NostrConnectEvent decode(Event event) {
    if (event.kind != 24133) {
      throw InvalidKindException(event.kind, [24133]);
    }
    final targetPubkey = findTagValue(event.tags, 'p');
    if (targetPubkey == null) {
      throw MissingTagException('p');
    }
    return NostrConnectEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      targetPubkey: targetPubkey,
      encryptedContent: event.content,
    );
  }
}

/// A decoded NIP-46 Nostr Connect event (kind 24133).
///
/// The [encryptedContent] remains opaque — decryption requires calling
/// NIP-44 with the appropriate keys.
class NostrConnectEvent {
  /// The event ID.
  final String id;

  /// The author's public key (client or remote signer).
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The target recipient's public key from the `p` tag.
  final String targetPubkey;

  /// The NIP-44 encrypted JSON-RPC content.
  final String encryptedContent;

  /// Creates a [NostrConnectEvent] with the given fields.
  const NostrConnectEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.targetPubkey,
    required this.encryptedContent,
  });
}

typedef NostrConnect = Nip46;
