import 'dart:convert';
import 'package:nostr/nostr.dart';

/// NIP-59 "Gift Wrap" using the two-layer approach:
///   Rumor (unsigned) -> Seal (kind=13) -> GiftWrap (kind=1059).
///
/// The "rumor" is any content you want to hide, with no signature. The "seal" is
/// signed by the real author, but only says "kind=13" with ciphertext in .content.
/// The "gift wrap" is signed by an ephemeral key, `kind=1059`.
///
/// Decryption by the recipient:
///   1) unwrap gift => returns the "seal" event
///   2) unseal => returns the original rumor
class Nip59 {
  /// Create a full "gift wrap" (kind=1059) that hides an underlying rumor.
  ///
  /// `rumor`         A Nostr event without a signature. If it has .sig or .id,
  ///                 we will forcibly remove them to preserve "unsigned rumor."
  ///
  /// `authorPrivkey` The real author's secret key (hex-encoded, 32 bytes).
  ///
  /// `recipientPubkey` The final recipient's pubkey (hex-encoded, 32 bytes).
  ///
  /// `ephemeralPrivkey` Optionally specify the ephemeral key used for the gift wrap.
  ///                    If null, it is randomly generated.
  ///
  /// `createdAt`     Optionally override 'created_at' for the final gift wrap.
  ///                 Timestamps can be randomized to defeat time analysis.
  ///
  /// `extraTags`     Additional tags to store inside the final gift wrap (e.g. expiration).
  ///
  /// Returns a `kind=1059` event that you broadcast. The seal is inside the `content`.
  static Future<Event> wrap({
    required Event rumor,
    required String authorPrivkey,
    required String recipientPubkey,
    String? ephemeralPrivkey,
    int? createdAt,
    List<List<String>>? extraTags,
  }) async {
    final authorPubkey = Keys(authorPrivkey).public;

    if (rumor.pubkey != authorPubkey) {
      throw Exception(
        "Beware impersonation: The seal pubkey doesn't match the rumor pubkey",
      );
    }

    // if 'rumor' is already signed, let's forcibly remove the signature & id:
    // Copy without "id" and "sig" to ensure it's an unsigned rumor:
    final unsignedRumor = Event.partial(
      pubkey: authorPubkey,
      createdAt: rumor.createdAt,
      kind: rumor.kind,
      tags: rumor.tags,
      content: rumor.content,
    );

    final rumorJson = unsignedRumor.toJson();

    // Encrypt rumor with (authorPrivkey, recipientPubkey)
    final sealCiphertext = await Nip44.encrypt(
      plaintext: rumorJson,
      recipientPublicKey: recipientPubkey,
      senderPrivateKey: authorPrivkey,
    );

    // Build the seal event (kind=13, empty tags, .content = ciphertext)
    // "tags must always be empty for kind=13" per the spec.
    // This event is signed by real author.
    final seal = Event.from(
      kind: 13,
      tags: [], // Per NIP-59, MUST always be empty
      content: sealCiphertext,
      pubkey: authorPubkey,
      privkey: authorPrivkey,
      createdAt: _randomPastTimestamp(),
    );

    // Create a "gift wrap" (kind=1059) by encrypting the seal using an ephemeral key.
    // Then sign with ephemeral key. If ephemeral key not specified, generate it
    final ephemeral = ephemeralPrivkey ?? Keys.generate().secret;
    final ephemeralPubkey = Keys(ephemeral).public;

    // Encrypt seal with (ephemeralPriv, recipientPubkey)
    final wrapCiphertext = await Nip44.encrypt(
      plaintext: seal.toJson(),
      recipientPublicKey: recipientPubkey,
      senderPrivateKey: ephemeral,
    );

    // Build gift wrap event (kind=1059). Typically includes ["p", recipient] in tags
    final tags = [
      ["p", recipientPubkey],
      if (extraTags != null) ...extraTags,
    ];

    final giftWrap = Event.from(
      kind: 1059,
      tags: tags,
      content: wrapCiphertext,
      pubkey: ephemeralPubkey,
      privkey: ephemeral, // ephemeral signing key
      createdAt: createdAt ?? _randomPastTimestamp(),
    );

    // You only broadcast the final giftWrap to the network. The rumor and seal
    // remain local or ephemeral.
    return giftWrap;
  }

  /// Unwrap a gift-wrapped event (`kind=1059`) to recover the sealed rumor (`kind=13`),
  /// then decrypt that seal to get the underlying rumor.
  ///
  /// `giftWrap` must be a `kind=1059` event posted by ephemeral key.
  /// `recipientPrivkey` is the real recipient's secret key.
  ///
  /// Returns the final "rumor" (an **unsigned** event), which you can parse or show.
  static Future<Event> unwrap({
    required Event giftWrap,
    required String recipientPrivkey,
  }) async {
    if (giftWrap.kind != 1059) {
      throw Exception('Not a gift wrap event (expected kind=1059)');
    }

    // Decrypt the gift wrap to recover the "seal" (kind=13)
    // with (ephemeralPub = giftWrap.pubkey, recipientPrivkey)
    final sealJsonStr = await Nip44.decrypt(
      payload: giftWrap.content,
      senderPublicKey: giftWrap.pubkey,
      recipientPrivateKey: recipientPrivkey,
    );

    // Reconstruct the seal event
    final seal = Event.fromJson(sealJsonStr);

    if (seal.kind != 13) {
      throw Exception('Unwrapped content is not a seal (expected kind=13)');
    }

    // Decrypt the seal to recover the rumor
    // with (authorPub = seal.pubkey, recipientPrivkey)
    final rumorJsonStr = await Nip44.decrypt(
      payload: seal.content,
      senderPublicKey: seal.pubkey,
      recipientPrivateKey: recipientPrivkey,
    );

    final rumorMap = json.decode(rumorJsonStr) as Map<String, dynamic>;
    final pubkey = getRequiredField<String>(rumorMap, 'pubkey');
    final createdAt = getRequiredField<int>(rumorMap, 'created_at');
    final kind = getRequiredField<int>(rumorMap, 'kind');
    final content = getRequiredField<String>(rumorMap, 'content');
    final rawTags = getRequiredField<List>(rumorMap, 'tags');
    final tags = rawTags
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();

    final rumor = Event.partial(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: kind,
      content: content,
      tags: tags,
    );

    if (seal.pubkey != rumor.pubkey) {
      throw Exception(
        "Beware impersonation: The seal pubkey doesn't match the rumor pubkey",
      );
    }

    if (rumor.sig.isNotEmpty) {
      // If it is signed, the message might leak to relays and become fully public.
      throw Exception('Rumor should be unsigned');
    }

    // The rumor is intentionally unsigned per NIP-59. It can be any kind of event, but .sig is empty. Return it:
    return rumor;
  }

  /// Timestamps SHOULD be in the past (two days)
  static int _randomPastTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final offset = DateTime.now().millisecondsSinceEpoch % (2 * 24 * 3600);
    return now - (offset ~/ 1000);
  }
}
