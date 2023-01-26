import 'package:json_annotation/json_annotation.dart';

part 'filter.g.dart';

/// filter is a JSON object that determines what events will be sent in that subscription
@JsonSerializable(includeIfNull: false)
class Filter {
  /// a list of event ids or prefixes
  List<String>? ids;

  /// a list of pubkeys or prefixes, the pubkey of an event must be one of these
  List<String>? authors;

  /// a list of a kind numbers
  List<int>? kinds;

  /// a list of event ids that are referenced in an "e" tag
  @JsonKey(name: '#e')
  List<String>? e;

  /// a list of pubkeys that are referenced in a "p" tag
  @JsonKey(name: '#p')
  List<String>? p;

  /// a timestamp, events must be newer than this to pass
  int? since;

  /// a timestamp, events must be older than this to pass
  int? until;

  /// maximum number of events to be returned in the initial query
  int? limit;

  /// Default constructor
  Filter({
    this.ids,
    this.authors,
    this.kinds,
    this.e,
    this.p,
    this.since,
    this.until,
    this.limit,
  });

  factory Filter.fromJson(Map<String, dynamic> json) => _$FilterFromJson(json);

  Map<String, dynamic> toJson() => _$FilterToJson(this);
}
