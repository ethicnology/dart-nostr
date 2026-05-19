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
class AppHandler {
  /// Kind for handler information events.
  static const int kindHandlerInfo = 31990;

  /// Kind for handler recommendation events.
  static const int kindHandlerRecommendation = 31989;

  /// Platform names recognized by [parseHandlerInfo]. Tags whose first
  /// element is one of these are treated as platform-URL templates;
  /// everything else is left to the caller via `event.tags`.
  ///
  /// Add a platform here if you ship a kind-31990 handler under a new
  /// platform name not already covered.
  static const Set<String> _knownPlatforms = {
    'web',
    'ios',
    'android',
    'iphone',
    'ipad',
    'macos',
    'linux',
    'windows',
  };

  /// Creates a kind-31990 handler information event.
  ///
  /// [id] is the handler identifier (`d` tag).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [supportedKinds] is the list of event kinds this handler supports.
  /// [platforms] is a list of platform handlers with URL templates
  /// containing `<bech32>` placeholders and optional entity types.
  /// [metadata] is an optional map of NIP-01 style metadata (name, about,
  /// picture, etc.) that will be JSON-encoded as the event content.
  static Event handlerInfo({
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
      kind: kindHandlerInfo,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-31990 event into an [AppHandlerData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 31990.
  /// Throws [MissingTagException] if the `d` tag is absent and
  /// [permissive] is false. In permissive mode the missing `d` is
  /// recorded on [AppHandlerData.missingTags].
  static AppHandlerData parseHandlerInfo(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindHandlerInfo) {
      throw InvalidKindException(event.kind, [kindHandlerInfo]);
    }

    final missing = <String>{};
    final id = findTagValue(event.tags, 'd');
    if (id == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
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

    // Parse platform tags using a positive allowlist. Spec doesn't
    // enumerate platform names but the convention in the ecosystem is
    // the set below. Tags outside the list (including any future
    // standardized Nostr tag) are NOT misclassified as platforms.
    final platforms = <PlatformHandler>[];
    for (final tag in event.tags) {
      if (tag.length < 2) continue;
      if (!_knownPlatforms.contains(tag[0])) continue;
      final entityType = tag.length > 2 ? tag[2] : null;
      platforms.add(PlatformHandler(
        platform: tag[0],
        url: tag[1],
        entityType: entityType,
      ));
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

    return AppHandlerData(
      id: id ?? '',
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      supportedKinds: supportedKinds,
      platforms: platforms,
      metadata: metadata,
      missingTags: missing,
    );
  }

  /// Creates a kind-31989 handler recommendation event.
  ///
  /// [eventKind] is the event kind being recommended (used as `d` tag).
  /// [handlerCoords] is a list of handler `a` tag coordinates
  /// (e.g. "31990:pubkey:handler-id").
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  static Event recommendation({
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
      kind: kindHandlerRecommendation,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Parses a kind-31989 event into a [HandlerRecommendationData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 31989.
  /// Throws [MissingTagException] if the `d` tag is absent and
  /// [permissive] is false.
  static HandlerRecommendationData parseRecommendation(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindHandlerRecommendation) {
      throw InvalidKindException(event.kind, [kindHandlerRecommendation]);
    }

    final missing = <String>{};
    final kindStr = findTagValue(event.tags, 'd');
    if (kindStr == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    final eventKind = kindStr != null ? int.tryParse(kindStr) : null;
    final handlerCoords = findAllTagValues(event.tags, 'a');

    return HandlerRecommendationData(
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      eventKind: eventKind,
      handlerCoords: handlerCoords,
      missingTags: missing,
    );
  }
}

/// A decoded handler information event (kind 31990).
class AppHandlerData {
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

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-89 requires `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates an [AppHandlerData] with the given fields.
  const AppHandlerData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.supportedKinds,
    this.platforms = const [],
    this.metadata,
    this.missingTags = const {},
  });
}

/// A decoded handler recommendation event (kind 31989).
class HandlerRecommendationData {
  /// The recommending user's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The event kind being recommended, from the `d` tag.
  final int? eventKind;

  /// Handler coordinates from `a` tags (e.g. "31990:pubkey:handler-id").
  final List<String> handlerCoords;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-89 requires `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [HandlerRecommendationData] with the given fields.
  const HandlerRecommendationData({
    required this.pubkey,
    required this.createdAt,
    required this.handlerCoords,
    this.eventKind,
    this.missingTags = const {},
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

typedef Nip89 = AppHandler;
typedef HandlerRecommendation = HandlerRecommendationData;
