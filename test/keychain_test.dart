import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Keychain', () {
    test('Default constructor', () {
      var hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      var keys = Keychain(hex);
      expect(keys.private, hex);
      expect(
        keys.public,
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b",
      );
    });

    test('Keychain with bugged private key', () {
      expect(
          () => Keychain(
                "ea7daa0537b93aa3ae4495a274ecc05077e3dc168809d77a7afa4ec1db0fb3bd",
              ),
          throwsA(isA<AssertionError>()));
    });

    test('Keychain with invalid private key (private.length != 64)', () {
      expect(
          () => Keychain(
                "",
              ),
          throwsA(isA<AssertionError>()));
    });

    test('Keychain.generate', () {
      var keys = Keychain.generate();
      expect(keys.public.length, 64);
      expect(keys.private.length, 64);
    });
  });
}
