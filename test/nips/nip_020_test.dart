import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip20', () {
    test('Constructor', () {
      var eventId =
          "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30";
      var status = true;
      var message = "";
      var nip20 = Nip20(eventId, status, message);
      expect(nip20.eventId, eventId);
      expect(nip20.status, status);
      expect(nip20.message, message);
    });

    test('serialize', () {
      var eventId =
          "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30";
      var status = true;
      var message = "";
      var stringNip20 = '["OK","$eventId",$status,"$message"]';
      var nip20 = Nip20(eventId, status, message);
      expect(nip20.serialize(), stringNip20);
    });

    test('deserialize', () {
      var jsonNip20 = [
        "OK",
        "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30",
        true,
        ""
      ];
      var nip20 = Nip20.deserialize(jsonNip20);
      expect(nip20.eventId, jsonNip20[1]);
      expect(nip20.status, jsonNip20[2]);
      expect(nip20.message, jsonNip20[3]);
    });
  });
}
