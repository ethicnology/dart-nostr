// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      json['id'] as String,
      json['pubkey'] as String,
      json['created_at'] as int,
      json['kind'] as int,
      (json['tags'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
          .toList(),
      json['content'] as String? ?? '',
      json['sig'] as String,
      subscriptionId: json['subscriptionId'] as String?,
    );

Map<String, dynamic> _$EventToJson(Event instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'pubkey': instance.pubkey,
    'created_at': instance.createdAt,
    'kind': instance.kind,
    'tags': instance.tags,
    'content': instance.content,
    'sig': instance.sig,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('subscriptionId', instance.subscriptionId);
  return val;
}
