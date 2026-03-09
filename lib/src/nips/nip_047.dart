import 'package:nostr/nostr.dart';

/// Nostr Wallet Connect — [NIP-47](https://github.com/nostr-protocol/nips/blob/master/47.md)
///
/// Kind 13194: wallet info event — plaintext content with space-separated
/// supported method names.
///
/// Kind 23194: encrypted request from client to wallet service.
/// Kind 23195: encrypted response from wallet service to client.
/// Kind 23196: encrypted notification (NIP-04 legacy).
/// Kind 23197: encrypted notification (NIP-44).
///
/// Encrypted kinds carry NIP-44 (or NIP-04) payloads; this class exposes
/// the event structure without performing decryption.
class WalletConnect {
  /// Kind for the wallet info event.
  static const int infoKind = 13194;

  /// Kind for encrypted request events.
  static const int requestKind = 23194;

  /// Kind for encrypted response events.
  static const int responseKind = 23195;

  /// Kind for encrypted notification events (NIP-04 legacy).
  static const int notificationLegacyKind = 23196;

  /// Kind for encrypted notification events (NIP-44).
  static const int notificationKind = 23197;

  /// All valid NWC event kinds.
  static const List<int> _allKinds = [
    infoKind,
    requestKind,
    responseKind,
    notificationLegacyKind,
    notificationKind,
  ];

  /// Parses a kind-13194 info event into a [WalletInfoData].
  ///
  /// The content contains space-separated supported method names.
  /// Throws [InvalidKindException] if the event kind is not 13194.
  static WalletInfoData parseInfo(Event event) {
    if (event.kind != infoKind) {
      throw InvalidKindException(event.kind, [infoKind]);
    }
    final capabilities = event.content
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();

    final encryption = findAllTagValues(event.tags, 'encryption');
    final notifications = findAllTagValues(event.tags, 'notifications');

    return WalletInfoData(
      pubkey: event.pubkey,
      capabilities: capabilities,
      encryption: encryption,
      notifications: notifications,
    );
  }

  /// Parses an encrypted NWC event (kinds 23194, 23195, 23196, 23197)
  /// into a [WalletEventData].
  ///
  /// The content remains encrypted — decryption requires the shared secret.
  /// Throws [InvalidKindException] if the event kind is not a valid NWC kind.
  static WalletEventData parse(Event event) {
    if (!_allKinds.contains(event.kind)) {
      throw InvalidKindException(event.kind, _allKinds);
    }

    if (event.kind == infoKind) {
      throw InvalidKindException(event.kind, [
        requestKind,
        responseKind,
        notificationLegacyKind,
        notificationKind,
      ]);
    }

    final targetPubkey = findTagValue(event.tags, 'p');
    final requestEventId = findTagValue(event.tags, 'e');
    final encryption = findTagValue(event.tags, 'encryption');

    return WalletEventData(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      kind: event.kind,
      targetPubkey: targetPubkey,
      requestEventId: requestEventId,
      encryption: encryption,
      encryptedContent: event.content,
    );
  }

  /// Creates a kind-23194 NWC request event.
  ///
  /// [encryptedContent] is the NIP-44 encrypted JSON-RPC request payload.
  /// [walletServicePubkey] is the wallet service's public key.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event request({
    required String encryptedContent,
    required String walletServicePubkey,
    required String secretKey,
  }) {
    return Event.from(
      kind: requestKind,
      tags: [
        ['p', walletServicePubkey],
      ],
      content: encryptedContent,
      secretKey: secretKey,
    );
  }

  /// Creates a kind-23195 NWC response event.
  ///
  /// [encryptedContent] is the NIP-44 encrypted JSON-RPC response payload.
  /// [clientPubkey] is the requesting client's public key.
  /// [requestEventId] is the event ID of the request being answered.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event response({
    required String encryptedContent,
    required String clientPubkey,
    required String requestEventId,
    required String secretKey,
  }) {
    return Event.from(
      kind: responseKind,
      tags: [
        ['p', clientPubkey],
        ['e', requestEventId],
      ],
      content: encryptedContent,
      secretKey: secretKey,
    );
  }
}

/// Parsed wallet info from a kind-13194 event.
class WalletInfoData {
  /// The wallet service's public key.
  final String pubkey;

  /// Space-separated supported method names parsed from content.
  final List<String> capabilities;

  /// Supported encryption schemes from `encryption` tags.
  final List<String> encryption;

  /// Supported notification types from `notifications` tags.
  final List<String> notifications;

  /// Creates a [WalletInfoData] with the given fields.
  const WalletInfoData({
    required this.pubkey,
    required this.capabilities,
    this.encryption = const [],
    this.notifications = const [],
  });
}

/// A parsed encrypted NWC event (kinds 23194, 23195, 23196, 23197).
///
/// The [encryptedContent] remains opaque — decryption requires the
/// shared secret between client and wallet service.
class WalletEventData {
  /// The event ID.
  final String id;

  /// The author's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The event kind (23194, 23195, 23196, or 23197).
  final int kind;

  /// The target recipient's public key from the `p` tag, if present.
  final String? targetPubkey;

  /// The request event ID from the `e` tag (responses only), if present.
  final String? requestEventId;

  /// The encryption method from the `encryption` tag, if present.
  final String? encryption;

  /// The encrypted content payload.
  final String encryptedContent;

  /// Creates a [WalletEventData] with the given fields.
  const WalletEventData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.encryptedContent,
    this.targetPubkey,
    this.requestEventId,
    this.encryption,
  });
}

typedef Nip47 = WalletConnect;
