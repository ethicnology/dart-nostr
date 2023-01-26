// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Filter _$FilterFromJson(Map<String, dynamic> json) => Filter(
      ids: (json['ids'] as List<dynamic>?)?.map((e) => e as String).toList(),
      authors:
          (json['authors'] as List<dynamic>?)?.map((e) => e as String).toList(),
      kinds: (json['kinds'] as List<dynamic>?)?.map((e) => e as int).toList(),
      e: (json['#e'] as List<dynamic>?)?.map((e) => e as String).toList(),
      p: (json['#p'] as List<dynamic>?)?.map((e) => e as String).toList(),
      since: json['since'] as int?,
      until: json['until'] as int?,
      limit: json['limit'] as int?,
    );

Map<String, dynamic> _$FilterToJson(Filter instance) {
  final val = <String, dynamic>{};

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('ids', instance.ids);
  writeNotNull('authors', instance.authors);
  writeNotNull('kinds', instance.kinds);
  writeNotNull('#e', instance.e);
  writeNotNull('#p', instance.p);
  writeNotNull('since', instance.since);
  writeNotNull('until', instance.until);
  writeNotNull('limit', instance.limit);
  return val;
}
