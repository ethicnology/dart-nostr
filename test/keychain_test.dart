import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Keychain', () {
    test('Default constructor', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keychain(hex);
      expect(keys.private, hex);
      expect(
        keys.public,
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b",
      );
    });

    test('Keychain from NIP19 nsec', () {
      const nsec =
          "nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp";
      final keys = Keychain.from(privateKeyHexOrBech32: nsec);
      expect(keys.private,
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12');
    });

    test('Keychain with invalid encoding (not HEX or Bech32)', () {
      expect(
        () => Keychain(
            'zz7daa0537b93aa3ae4495a274ecc05077e3dc168809d77a7afa4ec1db0fb3bd'),
        throwsException,
      );
    });

    test('Keychain with invalid private key (private.length != 64)', () {
      expect(
        () => Keychain(
          "",
        ),
        throwsException,
      );
    });

    test('Keychain.generate', () {
      final keys = Keychain.generate();
      expect(keys.public.length, 64);
      expect(keys.private.length, 64);
    });

    test('Keychain.verify', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keychain(hex);
      const message =
          "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
      const signature =
          "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

      expect(
          Keychain.verify(
            pubkey: keys.public,
            message: message,
            signature: signature,
          ),
          true);
    });
  });
}
