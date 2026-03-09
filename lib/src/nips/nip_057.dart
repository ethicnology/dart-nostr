import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Lightning Zaps — [NIP-57](https://github.com/nostr-protocol/nips/blob/master/57.md)
///
/// Kind 9734: zap request — sent to a recipient's LNURL pay callback.
/// Kind 9735: zap receipt — published by the recipient's lightning wallet
/// service after payment confirmation.
///
/// Currently supports public zaps only. Anonymous and private zaps require
/// bech32 encoding of payloads exceeding the BIP-173 90-character limit,
/// which the Dart `bech32` package does not support. Additionally, the ECDH
/// shared key derivation for private zaps has no cross-implementation test
/// vectors to verify interoperability.
class Nip57 {
  /// Kind for zap request events.
  static const int zapRequestKind = 9734;

  /// Kind for zap receipt events.
  static const int zapReceiptKind = 9735;

  /// Encodes a kind-9734 zap request event.
  ///
  /// [recipientPubkey] is the hex-encoded public key of the zap recipient.
  /// [relays] is the list of relay URLs where the receipt should be published.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [content] is an optional message from the sender.
  /// [eventId] is the event ID being zapped (optional).
  /// [addressableCoord] is a NIP-33 event coordinate (optional).
  /// [amount] is the amount in millisats the sender intends to pay (optional).
  /// [lnurl] is the bech32-encoded LNURL pay URL of the recipient (optional).
  static Event encodeZapRequest({
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
      kind: zapRequestKind,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }


  /// Decodes a kind-9735 zap receipt event into a [ZapReceipt].
  ///
  /// Parses the `bolt11`, `description` (embedded zap request JSON),
  /// `preimage`, `p` (recipient), `P` (sender), `e`, and `a` tags.
  ///
  /// Throws [InvalidKindException] if the event kind is not 9735.
  /// Throws [MissingTagException] if the required `bolt11`, `description`,
  /// or `p` tag is missing.
  static ZapReceipt decodeZapReceipt(Event event) {
    if (event.kind != zapReceiptKind) {
      throw InvalidKindException(event.kind, [zapReceiptKind]);
    }

    final bolt11 = findTagValue(event.tags, 'bolt11');
    if (bolt11 == null) {
      throw MissingTagException('bolt11');
    }

    final description = findTagValue(event.tags, 'description');
    if (description == null) {
      throw MissingTagException('description');
    }

    final recipientPubkey = findTagValue(event.tags, 'p');
    if (recipientPubkey == null) {
      throw MissingTagException('p');
    }

    final preimage = findTagValue(event.tags, 'preimage');
    final senderPubkey = _findUpperPTagValue(event.tags);
    final eventId = findTagValue(event.tags, 'e');
    final addressableCoord = findTagValue(event.tags, 'a');

    // Parse embedded zap request from the description tag
    ZapRequest? embeddedRequest;
    try {
      final map = json.decode(description) as Map<String, dynamic>;
      final zapRequestEvent = Event.fromMap(map, verify: false);
      embeddedRequest = _parseZapRequest(zapRequestEvent);
    } on Exception catch (_) {
      // If parsing fails, leave embeddedRequest as null
    }

    return ZapReceipt(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      recipientPubkey: recipientPubkey,
      senderPubkey: senderPubkey,
      bolt11: bolt11,
      description: description,
      preimage: preimage,
      eventId: eventId,
      addressableCoord: addressableCoord,
      embeddedRequest: embeddedRequest,
    );
  }

  /// Decodes a kind-9734 zap request event into a [ZapRequest].
  ///
  /// Throws [InvalidKindException] if the event kind is not 9734.
  /// Throws [MissingTagException] if required tags are missing.
  static ZapRequest decodeZapRequest(Event event) {
    if (event.kind != zapRequestKind) {
      throw InvalidKindException(event.kind, [zapRequestKind]);
    }
    return _parseZapRequest(event);
  }

  /// Parses a zap request event (kind check should be done by caller).
  static ZapRequest _parseZapRequest(Event event) {
    final recipientPubkey = findTagValue(event.tags, 'p');
    if (recipientPubkey == null) {
      throw MissingTagException('p');
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

    return ZapRequest(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      recipientPubkey: recipientPubkey,
      relays: relays,
      content: event.content,
      eventId: eventId,
      addressableCoord: addressableCoord,
      amount: amount,
      lnurl: lnurl,
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
class ZapRequest {
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

  /// Creates a [ZapRequest] with the given fields.
  const ZapRequest({
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
  });
}

/// A decoded zap receipt (kind 9735).
class ZapReceipt {
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
  final ZapRequest? embeddedRequest;

  /// Creates a [ZapReceipt] with the given fields.
  const ZapReceipt({
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
  });
}

typedef Zaps = Nip57;
