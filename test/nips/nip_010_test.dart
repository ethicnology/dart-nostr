import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip010', () {
    test('parseTags', () {
      final List<List<String>> tags = [
        ["e", '91cf9..4e5ca', 'wss://alicerelay.com', "root"],
        ["e", '14aeb..8dad4', 'wss://bobrelay.com/nostr', "reply"],
        ["p", '612ae..e610f', 'ws://carolrelay.com/ws'],
      ];
      final Thread thread = Nip10.parseTags(tags);
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
      final ETag root = Nip10.rootTag('91cf9..4e5ca', 'wss://alicerelay.com');
      const ETag eTag = ETag(
          eventId: "14aeb..8dad4",
          relayURL: "wss://bobrelay.com/nostr",
          marker: "reply");
      const PTag pTag =
          PTag(pubkey: "612ae..e610f", relayURL: "ws://carolrelay.com/ws");
      final Thread thread = Thread(root: root, etags: [eTag], ptags: [pTag]);

      expect(thread.root.eventId, '91cf9..4e5ca');
      expect(thread.etags[0].eventId, "14aeb..8dad4");
      expect(thread.ptags[0].pubkey, "612ae..e610f");
    });

    test('parseTags handles tags without markers (deprecated positional)', () {
      final List<List<String>> tags = [
        ["e", "abc123", "wss://relay.example.com"],
        ["e", "def456"],
        ["p", "pubkey1", "wss://relay.example.com"],
      ];
      final Thread thread = Nip10.parseTags(tags);
      // Both should parse without crashing
      expect(thread.etags.length, 2);
      expect(thread.etags[0].marker, '');
      expect(thread.etags[1].marker, '');
    });

    test('parseTags handles p tags with only pubkey', () {
      final List<List<String>> tags = [
        ["e", "abc123", "wss://relay.com", "root"],
        // p tag without relay — should not crash
      ];
      final Thread thread = Nip10.parseTags(tags);
      expect(thread.root.eventId, 'abc123');
      expect(thread.ptags, isEmpty);
    });

    test('parseTags keeps 2-element p tags (relay hint is optional)', () {
      // Regression: ["p", <pubkey>] — the most common p tag shape in the
      // wild — used to be silently dropped because the parser required
      // 3 elements.
      final List<List<String>> tags = [
        ["p", 'a' * 64],
        ["p", 'b' * 64, 'wss://relay.example.com'],
      ];
      final Thread thread = Nip10.parseTags(tags);
      expect(thread.ptags.length, 2);
      expect(thread.ptags[0].pubkey, 'a' * 64);
      expect(thread.ptags[0].relayURL, '');
      expect(thread.ptags[1].pubkey, 'b' * 64);
      expect(thread.ptags[1].relayURL, 'wss://relay.example.com');
    });
  });
}
