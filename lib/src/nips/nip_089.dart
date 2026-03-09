import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Application Handlers — [NIP-89](https://github.com/nostr-protocol/nips/blob/master/89.md)
///
/// Kind 31990: handler information — a parameterized replaceable event
/// published by applications to advertise which event kinds they handle.
/// Contains a `d` tag identifier, `k` tags for supported kinds, platform
/// tags (web, ios, android) with URL templates, and optional JSON metadata
/// in the content field.
///
/// Kind 31989: handler recommendation — published by users to recommend
/// applications for specific event kinds. Not modeled here as it is a
/// simple wrapper around `a` tags.
class Nip89 {
  /// Kind for handler information events.
  static const int handlerInfoKind = 31990;

  /// Kind for handler recommendation events.
  static const int handlerRecommendationKind = 31989;

  /// Encodes a kind-31990 handler information event.
  ///
  /// [id] is the handler identifier (`d` tag).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [supportedKinds] is the list of event kinds this handler supports.
  /// [platforms] is a list of platform handlers with URL templates
  /// containing `<bech32>` placeholders and optional entity types.
  /// [metadata] is an optional map of NIP-01 style metadata (name, about,
  /// picture, etc.) that will be JSON-encoded as the event content.
  static Event encodeHandlerInfo({
    required String id,
    required String secretKey,
    required List<int> supportedKinds,
    List<PlatformHandler> platforms = const [],
    Map<String, dynamic>? metadata,
  }) {
    final List<List<String>> tags = [
      ['d', id],
    ];

    for (final kind in supportedKinds) {
      tags.add(['k', kind.toString()]);
    }

    for (final p in platforms) {
      if (p.entityType != null) {
        tags.add([p.platform, p.url, p.entityType!]);
      } else {
        tags.add([p.platform, p.url]);
      }
    }

    final content = metadata != null ? json.encode(metadata) : '';

    return Event.from(
      kind: handlerInfoKind,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-31990 event into an [AppHandler].
  ///
  /// Throws [InvalidKindException] if the event kind is not 31990.
  /// Throws [MissingTagException] if the `d` tag is absent.
  static AppHandler decodeHandlerInfo(Event event) {
    if (event.kind != handlerInfoKind) {
      throw InvalidKindException(event.kind, [handlerInfoKind]);
    }

    final id = findTagValue(event.tags, 'd');
    if (id == null) {
      throw MissingTagException('d');
    }

    // Parse supported kinds from k tags
    final kindStrings = findAllTagValues(event.tags, 'k');
    final supportedKinds = <int>[];
    for (final k in kindStrings) {
      final parsed = int.tryParse(k);
      if (parsed != null) {
        supportedKinds.add(parsed);
      }
    }

    // Parse platform tags — any tag that isn't a known nostr tag type
    // and has a URL-like value is treated as a platform handler.
    final platforms = <PlatformHandler>[];
    const reservedTags = {'d', 'k', 'p', 'e', 'a', 't', 'r', 'expiration'};
    for (final tag in event.tags) {
      if (tag.length > 1 && !reservedTags.contains(tag[0])) {
        final entityType = tag.length > 2 ? tag[2] : null;
        platforms.add(PlatformHandler(
          platform: tag[0],
          url: tag[1],
          entityType: entityType,
        ));
      }
    }

    // Parse metadata from content JSON
    Map<String, dynamic>? metadata;
    if (event.content.isNotEmpty) {
      try {
        metadata = json.decode(event.content) as Map<String, dynamic>;
      } on FormatException catch (_) {
        // If parsing fails, leave metadata as null
      }
    }

    return AppHandler(
      id: id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      supportedKinds: supportedKinds,
      platforms: platforms,
      metadata: metadata,
    );
  }

  /// Encodes a kind-31989 handler recommendation event.
  ///
  /// [eventKind] is the event kind being recommended (used as `d` tag).
  /// [handlerCoords] is a list of handler `a` tag coordinates
  /// (e.g. "31990:pubkey:handler-id").
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event encodeRecommendation({
    required int eventKind,
    required List<String> handlerCoords,
    required String secretKey,
  }) {
    final List<List<String>> tags = [
      ['d', eventKind.toString()],
    ];

    for (final coord in handlerCoords) {
      tags.add(['a', coord]);
    }

    return Event.from(
      kind: handlerRecommendationKind,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-31989 event into a [HandlerRecommendation].
  ///
  /// Throws [InvalidKindException] if the event kind is not 31989.
  /// Throws [MissingTagException] if the `d` tag is absent.
  static HandlerRecommendation decodeRecommendation(Event event) {
    if (event.kind != handlerRecommendationKind) {
      throw InvalidKindException(event.kind, [handlerRecommendationKind]);
    }

    final kindStr = findTagValue(event.tags, 'd');
    if (kindStr == null) {
      throw MissingTagException('d');
    }

    final eventKind = int.tryParse(kindStr);
    final handlerCoords = findAllTagValues(event.tags, 'a');

    return HandlerRecommendation(
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      eventKind: eventKind,
      handlerCoords: handlerCoords,
    );
  }
}

/// A decoded handler information event (kind 31990).
class AppHandler {
  /// The handler identifier from the `d` tag.
  final String id;

  /// The application's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// Event kinds this handler supports, parsed from `k` tags.
  final List<int> supportedKinds;

  /// Platform-specific URL templates with optional entity types.
  final List<PlatformHandler> platforms;

  /// Optional NIP-01 style metadata parsed from the content JSON.
  final Map<String, dynamic>? metadata;

  /// Creates an [AppHandler] with the given fields.
  const AppHandler({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.supportedKinds,
    this.platforms = const [],
    this.metadata,
  });
}

/// A decoded handler recommendation event (kind 31989).
class HandlerRecommendation {
  /// The recommending user's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The event kind being recommended, from the `d` tag.
  final int? eventKind;

  /// Handler coordinates from `a` tags (e.g. "31990:pubkey:handler-id").
  final List<String> handlerCoords;

  /// Creates a [HandlerRecommendation] with the given fields.
  const HandlerRecommendation({
    required this.pubkey,
    required this.createdAt,
    required this.handlerCoords,
    this.eventKind,
  });
}

/// A platform handler entry from a kind-31990 event.
///
/// Tag format: `["web", "https://app.com/<bech32>", "naddr"]`
class PlatformHandler {
  /// The platform name (e.g. "web", "ios", "android").
  final String platform;

  /// The URL template with `<bech32>` placeholder.
  final String url;

  /// Optional NIP-19 entity type (e.g. "naddr", "nevent", "nprofile").
  /// When absent, the handler is considered generic for any entity.
  final String? entityType;

  /// Creates a [PlatformHandler].
  const PlatformHandler({
    required this.platform,
    required this.url,
    this.entityType,
  });
}

typedef AppHandlers = Nip89;
