/// A filter determines what events will be sent in a Nostr subscription.
///
/// Filters are JSON objects sent as part of a REQ message. The relay
/// returns stored events that match the filter, followed by new events
/// as they arrive.
class Filter {
  /// A list of event ids or prefixes to match.
  final List<String>? ids;

  /// A list of pubkeys or prefixes; the pubkey of an event must be one of these.
  final List<String>? authors;

  /// A list of event kind numbers to match.
  final List<int>? kinds;

  /// A list of event ids that are referenced in an "e" tag.
  ///
  /// Convenience for the most common single-letter tag filter. Routed
  /// through [tagFilters] under the key `'e'` on serialization.
  final List<String>? eTags;

  /// A list of addressable-event coordinates that are referenced in an
  /// "a" tag. Routed through [tagFilters] under the key `'a'`.
  final List<String>? aTags;

  /// A list of pubkeys that are referenced in a "p" tag. Routed through
  /// [tagFilters] under the key `'p'`.
  final List<String>? pTags;

  /// Generic single-letter tag filters. Per NIP-01:
  /// `#<single-letter (a-zA-Z)>` keys map to arrays of values.
  ///
  /// Use this for any tag letter the convenience fields above don't cover
  /// (`#d`, `#t`, `#k`, `#r`, …). Each key is one ASCII letter; values
  /// can be empty or multiple.
  ///
  /// Note: [eTags], [aTags], and [pTags] take precedence over the
  /// corresponding entries here when both are set — they serialize
  /// first, and the tagFilter entries for `e`/`a`/`p` are skipped.
  final Map<String, List<String>>? tagFilters;

  /// A unix timestamp; events must be newer than this to pass.
  final int? since;

  /// A unix timestamp; events must be older than this to pass.
  final int? until;

  /// Maximum number of events to be returned in the initial query.
  final int? limit;

  /// NIP-50 full-text search term.
  final String? search;

  /// Creates a [Filter] with the given optional constraints.
  const Filter({
    this.ids,
    this.authors,
    this.kinds,
    this.eTags,
    this.aTags,
    this.pTags,
    this.tagFilters,
    this.since,
    this.until,
    this.limit,
    this.search,
  });

  /// Deserializes a [Filter] from a JSON map.
  ///
  /// Any `#X` key with a single-letter `X` is collected into
  /// [tagFilters]. The well-known `#e`/`#a`/`#p` keys are also
  /// surfaced via [eTags]/[aTags]/[pTags] for backward compatibility.
  factory Filter.fromJson(Map<String, dynamic> json) {
    final tagFilters = <String, List<String>>{};
    for (final entry in json.entries) {
      final key = entry.key;
      if (key.length == 2 && key.startsWith('#')) {
        final letter = key[1];
        if (_isLetter(letter) && entry.value is List) {
          tagFilters[letter] = List<String>.from(entry.value);
        }
      }
    }

    return Filter(
      ids: json['ids'] == null ? null : List<String>.from(json['ids']),
      authors:
          json['authors'] == null ? null : List<String>.from(json['authors']),
      kinds: json['kinds'] == null ? null : List<int>.from(json['kinds']),
      eTags: tagFilters['e'],
      aTags: tagFilters['a'],
      pTags: tagFilters['p'],
      tagFilters: tagFilters.isEmpty ? null : tagFilters,
      since: json['since'],
      until: json['until'],
      limit: json['limit'],
      search: json['search'],
    );
  }

  /// Serializes this filter to a JSON-compatible map.
  ///
  /// `#e`/`#a`/`#p` come from [eTags]/[aTags]/[pTags] when set; otherwise
  /// from [tagFilters]. Any other `#X` keys come from [tagFilters].
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (ids != null) data['ids'] = ids;
    if (authors != null) data['authors'] = authors;
    if (kinds != null) data['kinds'] = kinds;
    if (eTags != null) data['#e'] = eTags;
    if (aTags != null) data['#a'] = aTags;
    if (pTags != null) data['#p'] = pTags;
    if (tagFilters != null) {
      for (final entry in tagFilters!.entries) {
        if (entry.key.length != 1 || !_isLetter(entry.key)) continue;
        final key = '#${entry.key}';
        // Convenience fields win when both are set.
        if (data.containsKey(key)) continue;
        data[key] = entry.value;
      }
    }
    if (since != null) data['since'] = since;
    if (until != null) data['until'] = until;
    if (limit != null) data['limit'] = limit;
    if (search != null) data['search'] = search;
    return data;
  }

  static bool _isLetter(String c) {
    if (c.length != 1) return false;
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  }
}
