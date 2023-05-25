import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip010', () {
    test('fromTags', () {
      List<List<String>> tags = [
        ["e", '91cf9..4e5ca', 'wss://alicerelay.com', "root"],
        ["e", '14aeb..8dad4', 'wss://bobrelay.com/nostr', "reply"],
        ["p", '612ae..e610f', 'ws://carolrelay.com/ws'],
      ];
      Thread thread = Nip10.fromTags(tags);
      expect(thread.root.eventId, '91cf9..4e5ca');
      expect(thread.root.relayURL, 'wss://alicerelay.com');
      expect(thread.root.marker, 'root');

      expect(thread.etags[0].eventId, '14aeb..8dad4');
      expect(thread.etags[0].relayURL, 'wss://bobrelay.com/nostr');
      expect(thread.etags[0].marker, 'reply');

      expect(thread.ptags[0].pubkey, '612ae..e610f');
      expect(thread.ptags[0].relayURL, 'ws://carolrelay.com/ws');
    });

    test('toTags', () {
      ETag root = Nip10.rootTag('91cf9..4e5ca', 'wss://alicerelay.com');
      ETag eTag = ETag("14aeb..8dad4", "wss://bobrelay.com/nostr", "reply");
      PTag pTag = PTag("612ae..e610f", "ws://carolrelay.com/ws");
      Thread thread = Thread(root, [eTag], [pTag]);

      expect(thread.root.eventId, '91cf9..4e5ca');
      expect(thread.etags[0].eventId, "14aeb..8dad4");
      expect(thread.ptags[0].pubkey, "612ae..e610f");
    });
  });
}
