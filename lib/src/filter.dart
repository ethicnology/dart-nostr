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
  final List<String>? eTags;

  /// A list of event ids that are referenced in an "a" tag.
  final List<String>? aTags;

  /// A list of pubkeys that are referenced in a "p" tag.
  final List<String>? pTags;

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
    this.since,
    this.until,
    this.limit,
    this.search,
  });

  /// Deserializes a [Filter] from a JSON map.
  factory Filter.fromJson(Map<String, dynamic> json) {
    return Filter(
      ids: json['ids'] == null ? null : List<String>.from(json['ids']),
      authors:
          json['authors'] == null ? null : List<String>.from(json['authors']),
      kinds: json['kinds'] == null ? null : List<int>.from(json['kinds']),
      eTags: json['#e'] == null ? null : List<String>.from(json['#e']),
      aTags: json['#a'] == null ? null : List<String>.from(json['#a']),
      pTags: json['#p'] == null ? null : List<String>.from(json['#p']),
      since: json['since'],
      until: json['until'],
      limit: json['limit'],
      search: json['search'],
    );
  }

  /// Serializes this filter to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (ids != null) data['ids'] = ids;
    if (authors != null) data['authors'] = authors;
    if (kinds != null) data['kinds'] = kinds;
    if (eTags != null) data['#e'] = eTags;
    if (aTags != null) data['#a'] = aTags;
    if (pTags != null) data['#p'] = pTags;
    if (since != null) data['since'] = since;
    if (until != null) data['until'] = until;
    if (limit != null) data['limit'] = limit;
    if (search != null) data['search'] = search;
    return data;
  }
}
