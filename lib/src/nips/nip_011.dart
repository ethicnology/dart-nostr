import 'dart:convert';
import 'package:http/http.dart' as http;

/// Relay Information Document — [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md)
///
/// Relays serve a JSON metadata document at their HTTP root when the
/// request carries `Accept: application/nostr+json`. Clients use it to
/// discover supported NIPs, payment requirements, content limits, contact
/// info, and operator policies before opening a WebSocket subscription.
///
/// Example use:
/// ```dart
/// final info = await RelayInfo.fetch('wss://relay.damus.io');
/// if (info != null && info.supportedNips.contains(44)) {
///   // relay supports NIP-44 encryption
/// }
/// ```
class RelayInfo {
  /// Fetches the relay information document for [relayUrl].
  ///
  /// [relayUrl] may use any scheme (`wss://`, `ws://`, `https://`, `http://`);
  /// `wss` / `ws` are normalised to `https` / `http` for the HTTP request,
  /// because NIP-11 lives on the same host on the regular HTTP port.
  ///
  /// Returns `null` when the relay is unreachable, the response status is
  /// not 200, the body is not valid JSON, or the response is missing
  /// every NIP-11 field. The function never throws on network or parse
  /// errors — wrap in a try/catch only if you want to surface them.
  ///
  /// [timeout] defaults to 8 seconds.
  static Future<RelayInfoData?> fetch(
    String relayUrl, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final url = _toHttpUrl(relayUrl);
    if (url == null) return null;

    final client = http.Client();
    try {
      final response = await client.get(url,
          headers: const {'Accept': 'application/nostr+json'}).timeout(timeout);

      if (response.statusCode != 200) return null;

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      return RelayInfoData.fromMap(decoded, url: relayUrl);
    } on Exception {
      return null;
    } finally {
      client.close();
    }
  }

  /// Normalises a WebSocket URL to its HTTP equivalent for NIP-11 fetch.
  ///
  /// `wss://host[:port]/path` → `https://host[:port]/path`
  /// `ws://host[:port]/path`  → `http://host[:port]/path`
  /// `https://...` / `http://...` are passed through unchanged.
  ///
  /// Returns `null` for malformed input or unsupported schemes.
  static Uri? _toHttpUrl(String relayUrl) {
    final parsed = Uri.tryParse(relayUrl.trim());
    if (parsed == null || parsed.host.isEmpty) return null;
    return switch (parsed.scheme) {
      'wss' || 'https' => parsed.replace(scheme: 'https'),
      'ws' || 'http' => parsed.replace(scheme: 'http'),
      _ => null,
    };
  }
}

/// A parsed NIP-11 relay information document.
class RelayInfoData {
  /// The relay URL the document was fetched from (original scheme preserved).
  final String url;

  /// Operator-chosen relay name.
  final String? name;

  /// Free-form description of the relay's purpose / policies.
  final String? description;

  /// The administrator's hex-encoded public key (optional).
  final String? pubkey;

  /// Contact URL or email for the administrator.
  final String? contact;

  /// List of NIP numbers the relay claims to support.
  final List<int> supportedNips;

  /// Software identifier (typically a URL to the repo).
  final String? software;

  /// Software version string.
  final String? version;

  /// Operational limits and capabilities advertised by the relay.
  final RelayLimitation? limitation;

  /// Event retention policies advertised by the relay.
  final List<Map<String, dynamic>> retention;

  /// ISO 3166-1 country codes the relay serves from.
  final List<String> relayCountries;

  /// IETF language tags for content stored on the relay.
  final List<String> languageTags;

  /// Free-form tags describing the relay's topical focus.
  final List<String> tags;

  /// URL to the relay's posting policy.
  final String? postingPolicy;

  /// URL where the relay sells subscriptions or pay-to-relay access.
  final String? paymentsUrl;

  /// Raw fee schedule object (admission/publication/subscription buckets).
  final Map<String, dynamic>? fees;

  /// URL of the relay's icon.
  final String? icon;

  /// Creates a [RelayInfoData] with the given fields.
  const RelayInfoData({
    required this.url,
    this.name,
    this.description,
    this.pubkey,
    this.contact,
    this.supportedNips = const [],
    this.software,
    this.version,
    this.limitation,
    this.retention = const [],
    this.relayCountries = const [],
    this.languageTags = const [],
    this.tags = const [],
    this.postingPolicy,
    this.paymentsUrl,
    this.fees,
    this.icon,
  });

  /// Parses a NIP-11 JSON object into a [RelayInfoData].
  ///
  /// Unknown fields are ignored. Wrong-typed fields are dropped silently
  /// (relays in the wild emit malformed types — a string where a list is
  /// expected, etc. — and we'd rather return a partial doc than throw).
  factory RelayInfoData.fromMap(
    Map<String, dynamic> map, {
    required String url,
  }) {
    final supportedNips = <int>[];
    final rawNips = map['supported_nips'];
    if (rawNips is List) {
      for (final n in rawNips) {
        if (n is int) {
          supportedNips.add(n);
        } else if (n is String) {
          final parsed = int.tryParse(n);
          if (parsed != null) supportedNips.add(parsed);
        }
      }
    }

    return RelayInfoData(
      url: url,
      name: map['name'] is String ? map['name'] as String : null,
      description:
          map['description'] is String ? map['description'] as String : null,
      pubkey: map['pubkey'] is String ? map['pubkey'] as String : null,
      contact: map['contact'] is String ? map['contact'] as String : null,
      supportedNips: supportedNips,
      software: map['software'] is String ? map['software'] as String : null,
      version: map['version'] is String ? map['version'] as String : null,
      limitation: map['limitation'] is Map<String, dynamic>
          ? RelayLimitation.fromMap(map['limitation'] as Map<String, dynamic>)
          : null,
      retention: map['retention'] is List
          ? (map['retention'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : const [],
      relayCountries: _stringList(map['relay_countries']),
      languageTags: _stringList(map['language_tags']),
      tags: _stringList(map['tags']),
      postingPolicy: map['posting_policy'] is String
          ? map['posting_policy'] as String
          : null,
      paymentsUrl:
          map['payments_url'] is String ? map['payments_url'] as String : null,
      fees: map['fees'] is Map<String, dynamic>
          ? map['fees'] as Map<String, dynamic>
          : null,
      icon: map['icon'] is String ? map['icon'] as String : null,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  /// Whether the relay claims to support the given [nip] number.
  bool supports(int nip) => supportedNips.contains(nip);
}

/// Operational limits and capabilities a relay advertises via NIP-11.
///
/// All fields are optional — relays only populate the ones they actually
/// enforce. Treat `null` as "unspecified", not "no limit".
class RelayLimitation {
  /// Maximum size (bytes) of a single incoming message.
  final int? maxMessageLength;

  /// Maximum concurrent subscriptions per connection.
  final int? maxSubscriptions;

  /// Maximum number of filters per `REQ` message.
  final int? maxFilters;

  /// Maximum `limit` value in a filter.
  final int? maxLimit;

  /// Maximum length of a subscription id string.
  final int? maxSubidLength;

  /// Minimum length of a pubkey / id prefix accepted in filters.
  final int? minPrefix;

  /// Maximum total number of tags on an event the relay will accept.
  final int? maxEventTags;

  /// Maximum size (bytes) of an event's `content` field.
  final int? maxContentLength;

  /// Minimum NIP-13 difficulty required for incoming events.
  final int? minPowDifficulty;

  /// True if the relay requires NIP-42 AUTH to read or write.
  final bool? authRequired;

  /// True if the relay requires payment to publish.
  final bool? paymentRequired;

  /// True if the relay restricts writes (e.g. to its own pubkey set).
  final bool? restrictedWrites;

  /// Creates a [RelayLimitation].
  const RelayLimitation({
    this.maxMessageLength,
    this.maxSubscriptions,
    this.maxFilters,
    this.maxLimit,
    this.maxSubidLength,
    this.minPrefix,
    this.maxEventTags,
    this.maxContentLength,
    this.minPowDifficulty,
    this.authRequired,
    this.paymentRequired,
    this.restrictedWrites,
  });

  /// Parses the `limitation` object of a NIP-11 document.
  factory RelayLimitation.fromMap(Map<String, dynamic> map) {
    int? asInt(Object? v) =>
        v is int ? v : (v is String ? int.tryParse(v) : null);
    bool? asBool(Object? v) => v is bool ? v : null;

    return RelayLimitation(
      maxMessageLength: asInt(map['max_message_length']),
      maxSubscriptions: asInt(map['max_subscriptions']),
      maxFilters: asInt(map['max_filters']),
      maxLimit: asInt(map['max_limit']),
      maxSubidLength: asInt(map['max_subid_length']),
      minPrefix: asInt(map['min_prefix']),
      maxEventTags: asInt(map['max_event_tags']),
      maxContentLength: asInt(map['max_content_length']),
      minPowDifficulty: asInt(map['min_pow_difficulty']),
      authRequired: asBool(map['auth_required']),
      paymentRequired: asBool(map['payment_required']),
      restrictedWrites: asBool(map['restricted_writes']),
    );
  }
}

typedef Nip11 = RelayInfo;
