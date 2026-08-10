import 'package:nostr/nostr.dart';
// Internal import to hand-craft a well-formed bech32 nsec carrying a
// truncated payload (the public encoder refuses to build one).
import 'package:nostr/src/nips/nip_019_utils.dart';
import 'package:test/test.dart';

void main() {
  group('Keys', () {
    test('Default constructor', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keys(hex);
      expect(keys.secret, hex);
      expect(
        keys.public,
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b",
      );
    });

    test('Keys from NIP19 nsec', () {
      const nsec =
          "nsec1tmsusqq2k28d6exhff7e2xkzm42es9yg0vdeuxk8chufa9sjtsfq8z3spp";
      final keys = Keys(nsec);
      expect(keys.secret,
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12');
    });

    test('Keys with invalid encoding (not HEX or Bech32)', () {
      expect(
        () => Keys(
            'zz7daa0537b93aa3ae4495a274ecc05077e3dc168809d77a7afa4ec1db0fb3bd'),
        throwsException,
      );
    });

    test('Keys with invalid secret key (secret.length != 64)', () {
      expect(
        () => Keys(
          "",
        ),
        throwsException,
      );
    });

    test('Keys with a well-formed nsec carrying a truncated payload', () {
      // Valid bech32 checksum, but the payload is 31 bytes instead of 32 —
      // must be rejected as InvalidKeyException, not crash downstream.
      final truncatedNsec = bech32Encode(Nip19Prefix.nsec, 'ab' * 31);
      expect(() => Keys(truncatedNsec), throwsA(isA<InvalidKeyException>()));
    });

    test('Keys.generate', () {
      final keys = Keys.generate();
      expect(keys.public.length, 64);
      expect(keys.secret.length, 64);
    });

    group('secret key range validation (BIP-340: scalar in [1, n - 1])', () {
      // Previously Keys('00…00') crashed with a raw _TypeError from the
      // bip340 backend, and Keys('ff…ff') (> n) silently derived a
      // non-canonical public key. Both must be InvalidKeyException.
      for (final (label, key) in [
        ('secret is 0',
            '0000000000000000000000000000000000000000000000000000000000000000'),
        ('secret == secp256k1.n',
            'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141'),
        ('secret > secp256k1.n',
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'),
      ]) {
        test('Keys($label) throws InvalidKeyException', () {
          expect(() => Keys(key), throwsA(isA<InvalidKeyException>()));
        });

        test('Schnorr.derivePublicKey($label) throws InvalidKeyException', () {
          expect(() => Schnorr.derivePublicKey(key),
              throwsA(isA<InvalidKeyException>()));
        });

        test('Schnorr.sign($label) throws InvalidKeyException', () {
          expect(() => Schnorr.sign(secretKey: key, message: '0' * 64),
              throwsA(isA<InvalidKeyException>()));
        });
      }

      test('Keys(n - 1) is accepted (boundary)', () {
        final keys = Keys(
            'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140');
        // x(G·(n-1)) == x(G) since (n-1)·G = -G
        expect(
          keys.public,
          '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        );
      });
    });

    test('Keys.nsec getter', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keys(hex);
      expect(keys.nsec, startsWith('nsec1'));
      // Round-trip: nsec → Keys → same secret
      final restored = Keys(keys.nsec);
      expect(restored.secret, hex);
    });

    test('Keys.npub getter', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keys(hex);
      expect(keys.npub, startsWith('npub1'));
      // Decode npub and verify it matches the public key
      final decoded = Nip19.decode(payload: keys.npub);
      expect(decoded.data, keys.public);
    });

    test('Keys.verify', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final keys = Keys(hex);
      const message =
          "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
      const signature =
          "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

      expect(
          Schnorr.verify(
            publicKey: keys.public,
            message: message,
            signature: signature,
          ),
          true);
    });
  });
}
