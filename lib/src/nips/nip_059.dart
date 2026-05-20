import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Gift wrap — [NIP-59](https://github.com/nostr-protocol/nips/blob/master/59.md)
///
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
class GiftWrap {
  /// Event kind for the inner seal that wraps the rumor.
  static const int kindSeal = 13;

  /// Event kind for the outer gift wrap broadcast to relays.
  static const int kindGiftWrap = 1059;

  /// Create a full "gift wrap" (kind=1059) that hides an underlying rumor.
  ///
  /// [rumor] is a Nostr event without a signature. If it has .sig or .id,
  ///   they will be forcibly removed to preserve "unsigned rumor."
  /// [authorSecretKey] is the real author's secret key (hex-encoded, 32 bytes).
  /// [recipientPubkey] is the final recipient's pubkey (hex-encoded, 32 bytes).
  /// [ephemeralSecretKey] optionally specifies the ephemeral key used for the gift wrap.
  ///   If null, it is randomly generated.
  /// [createdAt] optionally overrides 'created_at' for the final gift wrap.
  ///   Timestamps can be randomized to defeat time analysis.
  /// [extraTags] are additional tags to store inside the final gift wrap (e.g. expiration).
  ///
  /// Returns a `kind=1059` event that you broadcast. The seal is inside the `content`.
  /// Throws [CryptoException] if the rumor pubkey does not match the author.
  static Future<Event> wrap({
    required Event rumor,
    required String authorSecretKey,
    required String recipientPubkey,
    String? ephemeralSecretKey,
    int? createdAt,
    List<List<String>>? extraTags,
  }) async {
    final authorPubkey = Keys(authorSecretKey).public;

    if (rumor.pubkey != authorPubkey) {
      throw const CryptoException(
        "Beware impersonation: The seal pubkey doesn't match the rumor pubkey",
        CryptoErrorCode.sealAuthorMismatch,
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

    // Encrypt rumor with (authorSecretKey, recipientPubkey)
    final sealCiphertext = await Encryption.encrypt(
      plaintext: rumorJson,
      recipientPubkey: recipientPubkey,
      senderSecretKey: authorSecretKey,
    );

    // Build the seal event (kind=13, empty tags, .content = ciphertext)
    // "tags must always be empty for kind=13" per the spec.
    // This event is signed by real author.
    final seal = Event.from(
      kind: kindSeal,
      tags: [], // Per NIP-59, MUST always be empty
      content: sealCiphertext,
      pubkey: authorPubkey,
      secretKey: authorSecretKey,
      createdAt: _randomPastTimestamp(),
    );

    // Create a "gift wrap" (kind=1059) by encrypting the seal using an ephemeral key.
    // Then sign with ephemeral key. If ephemeral key not specified, generate it
    final ephemeral = ephemeralSecretKey ?? Keys.generate().secret;
    final ephemeralPubkey = Keys(ephemeral).public;

    // Encrypt seal with (ephemeralPriv, recipientPubkey)
    final wrapCiphertext = await Encryption.encrypt(
      plaintext: seal.toJson(),
      recipientPubkey: recipientPubkey,
      senderSecretKey: ephemeral,
    );

    // Build gift wrap event (kind=1059). Typically includes ["p", recipient] in tags
    final tags = [
      ["p", recipientPubkey],
      if (extraTags != null) ...extraTags,
    ];

    final giftWrap = Event.from(
      kind: kindGiftWrap,
      tags: tags,
      content: wrapCiphertext,
      pubkey: ephemeralPubkey,
      secretKey: ephemeral, // ephemeral signing key
      createdAt: createdAt ?? _randomPastTimestamp(),
    );

    // You only broadcast the final giftWrap to the network. The rumor and seal
    // remain local or ephemeral.
    return giftWrap;
  }

  /// Unwrap a gift-wrapped event (`kind=1059`) to recover the sealed rumor (`kind=13`),
  /// then decrypt that seal to get the underlying rumor.
  ///
  /// [giftWrap] must be a `kind=1059` event posted by ephemeral key.
  /// [recipientSecretKey] is the real recipient's secret key.
  ///
  /// Returns the final "rumor" (an **unsigned** event), which you can parse or show.
  /// Throws [CryptoException] if the event is not a gift wrap, not a seal,
  /// the pubkeys do not match, or the rumor is signed.
  static Future<Event> unwrap({
    required Event giftWrap,
    required String recipientSecretKey,
  }) async {
    if (giftWrap.kind != kindGiftWrap) {
      throw const CryptoException(
        'Not a gift wrap event (expected kind=1059)',
        CryptoErrorCode.notGiftWrapKind,
      );
    }

    // Verify the gift wrap's own signature before decrypting. Otherwise a
    // tampered/forged outer event with a valid-looking ephemeral pubkey
    // would happily decrypt to garbage (the NIP-44 MAC catches that), but
    // verifying here gives a clearer error and matches NIP-44's "Before
    // decryption, the event's pubkey and signature MUST be validated."
    if (!giftWrap.isValid()) {
      throw const CryptoException(
        'Invalid gift wrap signature',
        CryptoErrorCode.invalidGiftWrapSignature,
      );
    }

    // Decrypt the gift wrap to recover the "seal" (kind=13)
    // with (ephemeralPub = giftWrap.pubkey, recipientSecretKey)
    final sealJsonStr = await Encryption.decrypt(
      payload: giftWrap.content,
      senderPubkey: giftWrap.pubkey,
      recipientSecretKey: recipientSecretKey,
    );

    // Reconstruct the seal event
    final seal = Event.fromJson(sealJsonStr);

    if (seal.kind != kindSeal) {
      throw const CryptoException(
        'Unwrapped content is not a seal (expected kind=13)',
        CryptoErrorCode.unwrappedNotSealKind,
      );
    }

    // Per NIP-59: "tags must always be empty in a kind:13". A seal with
    // tags could be used to smuggle metadata that the wrap was meant to
    // hide. Reject it.
    if (seal.tags.isNotEmpty) {
      throw const CryptoException(
        'Seal (kind 13) MUST have empty tags',
        CryptoErrorCode.sealMustHaveEmptyTags,
      );
    }

    // Decrypt the seal to recover the rumor
    // with (authorPub = seal.pubkey, recipientSecretKey)
    final rumorJsonStr = await Encryption.decrypt(
      payload: seal.content,
      senderPubkey: seal.pubkey,
      recipientSecretKey: recipientSecretKey,
    );

    final Object? decoded;
    try {
      decoded = json.decode(rumorJsonStr);
    } on FormatException {
      // Don't echo the underlying message — `rumorJsonStr` is the
      // *decrypted* plaintext of the gift-wrapped DM and may be
      // sensitive. `FormatException.toString()` includes a snippet of
      // the offending input.
      throw const DeserializationException('rumor JSON is invalid');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DeserializationException(
        'rumor must decode to a JSON object',
      );
    }
    final rumorMap = decoded;
    final pubkey = getRequiredField<String>(rumorMap, 'pubkey');
    final createdAt = getRequiredField<int>(rumorMap, 'created_at');
    final kind = getRequiredField<int>(rumorMap, 'kind');
    final content = getRequiredField<String>(rumorMap, 'content');
    final rawTags = getRequiredField<List>(rumorMap, 'tags');
    final tags = <List<String>>[];
    for (var i = 0; i < rawTags.length; i++) {
      final entry = rawTags[i];
      if (entry is! List) {
        throw DeserializationException(
          "rumor tag at index $i is not a list",
        );
      }
      final tag = <String>[];
      for (var j = 0; j < entry.length; j++) {
        final value = entry[j];
        if (value is! String) {
          throw DeserializationException(
            "rumor tag[$i][$j] is not a string",
          );
        }
        tag.add(value);
      }
      tags.add(tag);
    }

    final rumor = Event.partial(
      pubkey: pubkey,
      createdAt: createdAt,
      kind: kind,
      content: content,
      tags: tags,
    );

    if (seal.pubkey != rumor.pubkey) {
      throw const CryptoException(
        "Beware impersonation: The seal pubkey doesn't match the rumor pubkey",
        CryptoErrorCode.sealAuthorMismatch,
      );
    }

    if (rumor.sig.isNotEmpty) {
      // If it is signed, the message might leak to relays and become fully public.
      throw const CryptoException(
        'Rumor should be unsigned',
        CryptoErrorCode.rumorMustBeUnsigned,
      );
    }

    // The rumor is intentionally unsigned per NIP-59. It can be any kind of event, but .sig is empty. Return it:
    return rumor;
  }

  /// Timestamps SHOULD be randomized within the past 2 days to prevent
  /// time-correlation attacks per the NIP-59 specification.
  static int _randomPastTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const twoDays = 2 * 24 * 3600; // 172800 seconds
    final randomBytes = generateRandomBytes(4);
    final randomOffset =
        randomBytes.fold<int>(0, (a, b) => (a << 8) | b) % twoDays;
    return now - randomOffset;
  }
}

typedef Nip59 = GiftWrap;
