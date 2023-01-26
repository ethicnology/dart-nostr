import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  const npubValid =
      'npub1eqmj85el4pkg7qdj2jcae24qykev5evnyz2s6pzdytzpkhga4u5sdmhexk';
  const hexValid =
      'c83723d33fa86c8f01b254b1dcaaa025b2ca659320950d044d22c41b5d1daf29';

  const npubInvalid =
      'nrub1eqmj85el4pkg7qdj2jcae24qykev5evnyz2s6pzdytzpkhga4u5sdmhexk';
  const hexInvalid =
      '_pub1eqmj85el4pkg7qdj2jcae24qykevdcaaa025b2ca6d22c41b5d1daf29';

  group('Convert', () {
    test('Npub to hex valid', () {
      final hex = npubKeyToHex(npubValid);

      expect(hex, hexValid);
    });

    test('Hex to npub valid', () {
      final npub = hexKeyToNub(hexValid);

      expect(npub, npub);
    });

    test('Npub to hex invalid', () {
      final hex = npubKeyToHex(npubInvalid);

      expect(hex, null);
    });

    test('Hex to npub invalid', () {
      final npub = hexKeyToNub(hexInvalid);

      expect(npub, null);
    });
  });
}
