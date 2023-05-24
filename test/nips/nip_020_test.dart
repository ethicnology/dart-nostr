import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip020', () {
    test('getOk', () {
      String okPayload =
          '["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, ""]';
      OKEvent? okEvent = Nip20.getOk(okPayload);
      expect(okEvent!.status, true);
    });

  });
}
