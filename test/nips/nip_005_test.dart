import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip005', () {
    test('encode', () {
      var hex =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";
      var user = Keychain(hex);
      List<String> relays = [
        'wss://relay.example.com',
        'wss://relay2.example.com'
      ];
      Event event = Nip5.encode('name', 'example.com', relays, user.private);
      print(event.serialize());
      expect(event.kind, 0);

      expect(() => Nip5.encode('name', 'example', relays, user.private),
          throwsException);
      expect(() => Nip5.encode('name!', 'example.com', relays, user.private),
          throwsException);
    });

    test('decode', () async {
      var event = Event.from(
        kind: 0,
        tags: [],
        content:
            "{\"name\":\"name\",\"nip05\":\"name@example.com\",\"relays\":[\"wss://relay.example.com\",\"wss://relay2.example.com\"]}",
        privkey:
            "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
      );
      DNS? dns = await Nip5.decode(event);
      expect(dns!.name, 'name');
      expect(dns.domain, 'example.com');
      expect(dns.pubkey, event.pubkey);
      expect(
          dns.relays, ['wss://relay.example.com', 'wss://relay2.example.com']);
    });
  });
}
