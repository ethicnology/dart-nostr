import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip005', () {
    test('encode', () {
      const hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      final user = Keys(hex);
      final List<String> relays = [
        'wss://relay.example.com',
        'wss://relay2.example.com'
      ];
      final Event event = Nip5.encode(
          name: 'name',
          domain: 'example.com',
          relays: relays,
          secretKey: user.secret);
      expect(event.kind, 0);

      expect(
          () => Nip5.encode(
              name: 'name',
              domain: 'example',
              relays: relays,
              secretKey: user.secret),
          throwsException);
      expect(
          () => Nip5.encode(
              name: 'name!',
              domain: 'example.com',
              relays: relays,
              secretKey: user.secret),
          throwsException);
    });

    test('isValidName allows a-z 0-9 _ - .', () {
      expect(Nip5.isValidName('alice'), isTrue);
      expect(Nip5.isValidName('alice-bob'), isTrue);
      expect(Nip5.isValidName('alice.bob'), isTrue);
      expect(Nip5.isValidName('alice_bob'), isTrue);
      expect(Nip5.isValidName('alice123'), isTrue);
      expect(Nip5.isValidName('Alice'), isFalse); // uppercase not allowed
      expect(Nip5.isValidName('alice!'), isFalse);
      expect(Nip5.isValidName('alice@bob'), isFalse);
    });

    test('verificationUrl builds correct URL', () {
      final url = Nip5.verificationUrl('alice@example.com');
      expect(url.toString(),
          'https://example.com/.well-known/nostr.json?name=alice');
    });

    test('decode', () async {
      final event = Event.from(
        kind: 0,
        tags: [],
        content:
            '{"name":"name","nip05":"name@example.com","relays":["wss://relay.example.com","wss://relay2.example.com"]}',
        secretKey:
            "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
      );
      final DNS? dns = await Nip5.decode(event);
      expect(dns!.name, 'name');
      expect(dns.domain, 'example.com');
      expect(dns.pubkey, event.pubkey);
      expect(
          dns.relays, ['wss://relay.example.com', 'wss://relay2.example.com']);
    });

    test('verify damus@damus.io (live DNS)', () async {
      final result = await Nip5.verify(
        identifier: 'damus@damus.io',
        pubkey:
            '3efdaebb1d8923ebd99c9e7ace3b4194ab45512e2be79c1b7d68d9243e0d2681',
      );
      expect(result, isTrue);
    });

    test('verify with wrong pubkey returns false (live DNS)', () async {
      final result = await Nip5.verify(
        identifier: 'damus@damus.io',
        pubkey:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );
      expect(result, isFalse);
    });

    test('rust-nostr verificationUrl vector', () {
      final vectors = json.decode(
          File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
      final nip05 = vectors['nip05'];
      final url = Nip5.verificationUrl(nip05['identifier']);
      expect(url.toString(), nip05['expected_url']);
    });

    test('verify with non-existent name returns false (live DNS)', () async {
      final result = await Nip5.verify(
        identifier: 'this_user_surely_does_not_exist_xyz@damus.io',
        pubkey:
            '3efdaebb1d8923ebd99c9e7ace3b4194ab45512e2be79c1b7d68d9243e0d2681',
      );
      expect(result, isFalse);
    });
  });
}
