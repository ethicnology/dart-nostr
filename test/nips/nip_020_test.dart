import 'dart:convert';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip20', () {
    test('Constructor', () {
      const eventId =
          "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30";
      const status = true;
      const message = "";
      const nip20 = Nip20(eventId, status, message);
      expect(nip20.eventId, eventId);
      expect(nip20.status, status);
      expect(nip20.message, message);
    });

    test('serialize', () {
      const eventId =
          "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30";
      const status = true;
      const message = "";
      const stringNip20 = '["OK","$eventId",$status,"$message"]';
      const nip20 = Nip20(eventId, status, message);
      expect(nip20.serialize(), stringNip20);
    });

    test('deserialize', () {
      final serializedNip20 = [
        "OK",
        "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30",
        true,
        ""
      ];
      final nip20 = Nip20.deserialize(json.encode(serializedNip20));
      expect(nip20.eventId, serializedNip20[1]);
      expect(nip20.status, serializedNip20[2]);
      expect(nip20.message, serializedNip20[3]);
    });
  });
}
