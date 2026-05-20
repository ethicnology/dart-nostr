import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Lightning Zaps — [NIP-57](https://github.com/nostr-protocol/nips/blob/master/57.md)
///
/// Kind 9734: zap request — sent to a recipient's LNURL pay callback.
/// Kind 9735: zap receipt — published by the recipient's lightning wallet
/// service after payment confirmation.
///
/// Supports public, anonymous, and private zaps.
/// Anonymous zaps use throwaway keys. Private zaps encrypt the real zap
/// request using NIP-44 and store it in an `anon` tag.
///
/// Note: Anonymous and private zaps are not yet in the NIP-57 spec
/// (marked as "future work"). This implementation uses NIP-44 encryption
/// for private zaps (not AES-CBC as in some other libraries).
class Zap {
  /// Kind for zap request events.
  static const int kindZapRequest = 9734;

  /// Kind for zap receipt events.
  static const int kindZapReceipt = 9735;

  /// Creates a kind-9734 zap request event.
  ///
  /// [recipientPubkey] is the hex-encoded public key of the zap recipient.
  /// [relays] is the list of relay URLs where the receipt should be published.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [content] is an optional message from the sender.
  /// [eventId] is the event ID being zapped (optional).
  /// [addressableCoord] is a NIP-33 event coordinate (optional).
  /// [amount] is the amount in millisats the sender intends to pay (optional).
  /// [lnurl] is the bech32-encoded LNURL pay URL of the recipient (optional).
  static Event request({
    required String recipientPubkey,
    required List<String> relays,
    required String secretKey,
    String content = '',
    String? eventId,
    String? addressableCoord,
    int? amount,
    String? lnurl,
  }) {
    final List<List<String>> tags = [
      ['relays', ...relays],
      ['p', recipientPubkey],
    ];

    if (eventId != null) {
      tags.add(['e', eventId]);
    }

    if (addressableCoord != null) {
      tags.add(['a', addressableCoord]);
    }

    if (amount != null) {
      tags.add(['amount', amount.toString()]);
    }

    if (lnurl != null) {
      tags.add(['lnurl', lnurl]);
    }

    return Event.from(
      kind: kindZapRequest,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }


  /// Creates an anonymous kind-9734 zap request event.
  ///
  /// Uses a random throwaway key pair so the sender's identity is hidden.
  /// Adds an empty `["anon"]` tag to signal this is an anonymous zap.
  static Event anonymousRequest({
    required String recipientPubkey,
    required List<String> relays,
    String content = '',
    String? eventId,
    String? addressableCoord,
    int? amount,
    String? lnurl,
  }) {
    final throwaway = Keys.generate();
    final List<List<String>> tags = [
      ['relays', ...relays],
      ['p', recipientPubkey],
      if (eventId != null) ['e', eventId],
      if (addressableCoord != null) ['a', addressableCoord],
      if (amount != null) ['amount', amount.toString()],
      if (lnurl != null) ['lnurl', lnurl],
      ['anon'],
    ];

    return Event.from(
      kind: kindZapRequest,
      tags: tags,
      content: content,
      secretKey: throwaway.secret,
    );
  }

  /// Creates a private kind-9734 zap request event.
  ///
  /// The real zap request (with sender identity) is NIP-44 encrypted and
  /// stored in an `["anon", encrypted]` tag. The outer event is signed
  /// with an ephemeral key so the sender's identity is hidden on relays.
  ///
  /// The recipient can decrypt using [decryptPrivateRequest].
  static Future<Event> privateRequest({
    required String recipientPubkey,
    required List<String> relays,
    required String secretKey,
    String content = '',
    String? eventId,
    String? addressableCoord,
    int? amount,
    String? lnurl,
  }) async {
    // Create the real zap request signed by sender
    final innerEvent = request(
      recipientPubkey: recipientPubkey,
      relays: relays,
      secretKey: secretKey,
      content: content,
      eventId: eventId,
      addressableCoord: addressableCoord,
      amount: amount,
      lnurl: lnurl,
    );

    // Create ephemeral keys for the outer event
    final ephemeral = Keys.generate();

    // Encrypt the inner event JSON using NIP-44 with ephemeral key
    // so recipient can decrypt using outer event's pubkey
    final encrypted = await Encryption.encrypt(
      plaintext: innerEvent.toJson(),
      senderSecretKey: ephemeral.secret,
      recipientPubkey: recipientPubkey,
    );
    final List<List<String>> tags = [
      ['relays', ...relays],
      ['p', recipientPubkey],
      if (eventId != null) ['e', eventId],
      if (addressableCoord != null) ['a', addressableCoord],
      if (amount != null) ['amount', amount.toString()],
      if (lnurl != null) ['lnurl', lnurl],
      ['anon', encrypted],
    ];

    return Event.from(
      kind: kindZapRequest,
      tags: tags,
      content: '',
      secretKey: ephemeral.secret,
    );
  }

  /// Decrypts a private zap request received by the recipient.
  ///
  /// Extracts the NIP-44 encrypted payload from the `anon` tag,
  /// decrypts it, and returns the inner zap request event containing
  /// the real sender identity and message.
  ///
  /// Throws [MissingTagException] if no `anon` tag with content is found.
  /// Throws [CryptoException] if decryption fails.
  static Future<ZapRequestData> decryptPrivateRequest({
    required Event privateZapEvent,
    required String recipientSecretKey,
  }) async {
    // Find anon tag with encrypted content
    String? encrypted;
    for (final tag in privateZapEvent.tags) {
      if (tag.length >= 2 && tag[0] == 'anon' && tag[1].isNotEmpty) {
        encrypted = tag[1];
        break;
      }
    }
    if (encrypted == null) {
      throw MissingTagException('anon');
    }

    // Decrypt using NIP-44 (sender is the outer event pubkey)
    final decrypted = await Encryption.decrypt(
      payload: encrypted,
      recipientSecretKey: recipientSecretKey,
      senderPubkey: privateZapEvent.pubkey,
    );

    // Parse the inner event
    final innerEvent = Event.fromJson(decrypted, verify: false);
    return _parseZapRequestData(innerEvent);
  }

  /// Parses a kind-9735 zap receipt event into a [ZapReceiptData].
  ///
  /// Parses the `bolt11`, `description` (embedded zap request JSON),
  /// `preimage`, `p` (recipient), `P` (sender), `e`, and `a` tags.
  ///
  /// **This method does NOT verify receipt authenticity.** Per NIP-57
  /// Appendix F, clients SHOULD additionally check:
  ///
  /// - `sha256(description) == bolt11.description_hash` (SHOULD per spec) —
  ///   requires a bolt11 decoder which is out of scope for this library.
  /// - `event.pubkey == recipient's LNURL provider's nostrPubkey` (MUST per
  ///   spec) — requires the caller's LNURL response.
  /// - `bolt11.invoiceAmount == zapRequest.amount` (MUST per spec) —
  ///   requires a bolt11 decoder.
  /// - `zapRequest.lnurl == recipient's LNURL` (SHOULD per spec) — requires
  ///   the caller's LNURL response.
  ///
  /// Without these checks the receipt should be treated as untrusted
  /// metadata: a malicious zap service can publish receipts attributing
  /// fake zaps to any sender.
  ///
  /// Throws [InvalidKindException] if the event kind is not 9735.
  /// Throws [MissingTagException] if the required `bolt11`, `description`,
  /// or `p` tag is missing and [permissive] is false. In permissive
  /// mode missing tags are recorded on [ZapReceiptData.missingTags].
  static ZapReceiptData parseReceipt(Event event, {bool permissive = false}) {
    if (event.kind != kindZapReceipt) {
      throw InvalidKindException(event.kind, [kindZapReceipt]);
    }

    final missing = <String>{};
    final bolt11 = findTagValue(event.tags, 'bolt11');
    if (bolt11 == null) {
      if (!permissive) throw MissingTagException('bolt11');
      missing.add('bolt11');
    }

    final description = findTagValue(event.tags, 'description');
    if (description == null) {
      if (!permissive) throw MissingTagException('description');
      missing.add('description');
    }

    final recipientPubkey = findTagValue(event.tags, 'p');
    if (recipientPubkey == null) {
      if (!permissive) throw MissingTagException('p');
      missing.add('p');
    }

    final preimage = findTagValue(event.tags, 'preimage');
    final senderPubkey = _findUpperPTagValue(event.tags);
    final eventId = findTagValue(event.tags, 'e');
    final addressableCoord = findTagValue(event.tags, 'a');

    // Parse embedded zap request from the description tag
    ZapRequestData? embeddedRequest;
    if (description != null) {
      try {
        final decoded = json.decode(description);
        if (decoded is Map<String, dynamic>) {
          final zapRequestEvent = Event.fromMap(decoded, verify: false);
          embeddedRequest =
              _parseZapRequestData(zapRequestEvent, permissive: true);
        }
      } on Exception catch (_) {
        // If parsing fails, leave embeddedRequest as null
      }
    }

    return ZapReceiptData(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      recipientPubkey: recipientPubkey ?? '',
      senderPubkey: senderPubkey,
      bolt11: bolt11 ?? '',
      description: description ?? '',
      preimage: preimage,
      eventId: eventId,
      addressableCoord: addressableCoord,
      embeddedRequest: embeddedRequest,
      missingTags: missing,
    );
  }

  /// Parses a kind-9734 zap request event into a [ZapRequestData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 9734.
  /// Throws [MissingTagException] if required tags are missing and
  /// [permissive] is false.
  static ZapRequestData parseRequest(Event event, {bool permissive = false}) {
    if (event.kind != kindZapRequest) {
      throw InvalidKindException(event.kind, [kindZapRequest]);
    }
    return _parseZapRequestData(event, permissive: permissive);
  }

  /// Parses a zap request event (kind check should be done by caller).
  static ZapRequestData _parseZapRequestData(
    Event event, {
    bool permissive = false,
  }) {
    final missing = <String>{};
    final recipientPubkey = findTagValue(event.tags, 'p');
    if (recipientPubkey == null) {
      if (!permissive) throw MissingTagException('p');
      missing.add('p');
    }

    final relays = <String>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'relays' && tag.length > 1) {
        relays.addAll(tag.sublist(1));
        break;
      }
    }

    final eventId = findTagValue(event.tags, 'e');
    final addressableCoord = findTagValue(event.tags, 'a');
    final amountStr = findTagValue(event.tags, 'amount');
    final amount = amountStr != null ? int.tryParse(amountStr) : null;
    final lnurl = findTagValue(event.tags, 'lnurl');

    return ZapRequestData(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      recipientPubkey: recipientPubkey ?? '',
      relays: relays,
      content: event.content,
      eventId: eventId,
      addressableCoord: addressableCoord,
      amount: amount,
      lnurl: lnurl,
      missingTags: missing,
    );
  }

  /// Finds the value of an uppercase `P` tag (sender pubkey in zap receipts).
  static String? _findUpperPTagValue(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == 'P' && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }
}

/// A decoded zap request (kind 9734).
class ZapRequestData {
  /// The event ID.
  final String id;

  /// The sender's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The recipient's public key from the `p` tag.
  final String recipientPubkey;

  /// Relay URLs from the `relays` tag.
  final List<String> relays;

  /// The sender's optional message.
  final String content;

  /// The event ID being zapped, from the `e` tag.
  final String? eventId;

  /// The NIP-33 event coordinate, from the `a` tag.
  final String? addressableCoord;

  /// The amount in millisats from the `amount` tag.
  final int? amount;

  /// The bech32-encoded LNURL from the `lnurl` tag.
  final String? lnurl;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-57: `p`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [ZapRequestData] with the given fields.
  const ZapRequestData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.recipientPubkey,
    required this.relays,
    required this.content,
    this.eventId,
    this.addressableCoord,
    this.amount,
    this.lnurl,
    this.missingTags = const {},
  });
}

/// A decoded zap receipt (kind 9735).
class ZapReceiptData {
  /// The event ID.
  final String id;

  /// The zap service's public key (event author).
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The recipient's public key from the `p` tag.
  final String recipientPubkey;

  /// The sender's public key from the `P` tag, if present.
  final String? senderPubkey;

  /// The bolt11 Lightning invoice.
  final String bolt11;

  /// The JSON-encoded zap request from the `description` tag.
  final String description;

  /// The payment preimage, if present.
  final String? preimage;

  /// The zapped event ID from the `e` tag, if present.
  final String? eventId;

  /// The NIP-33 event coordinate from the `a` tag, if present.
  final String? addressableCoord;

  /// The parsed embedded zap request from the `description` tag, if valid.
  final ZapRequestData? embeddedRequest;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-57: `bolt11`, `description`, `p`). Empty in
  /// strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [ZapReceiptData] with the given fields.
  const ZapReceiptData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.recipientPubkey,
    required this.bolt11,
    required this.description,
    this.senderPubkey,
    this.preimage,
    this.eventId,
    this.addressableCoord,
    this.embeddedRequest,
    this.missingTags = const {},
  });
}

typedef Nip57 = Zap;
typedef ZapRequest = ZapRequestData;
typedef ZapReceipt = ZapReceiptData;
