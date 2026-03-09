import 'package:nostr/nostr.dart';

void main() {
  const eventId =
      'b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30';
  const nip20 = Nip20(eventId, true, '');

  final serialized = nip20.serialize();
  print('OK message: $serialized');

  final deserialized = Nip20.deserialize(serialized);
  assert(deserialized.eventId == eventId);
  assert(deserialized.status == true);
  assert(deserialized.message == '');
}
