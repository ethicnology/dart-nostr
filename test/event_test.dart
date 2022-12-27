import 'package:bip340/bip340.dart';
import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Event', () {
    test('Default constructor', () {
      String id =
          "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
      String pubKey =
          "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
      int createdAt = 1672175320;
      int kind = 1;
      List<List<String>> tags = [];
      String content = "Ceci est une analyse du websocket";
      String sig =
          "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

      Event event = Event(
        id,
        pubKey,
        createdAt,
        kind,
        tags,
        content,
        sig,
      );

      expect(event.id, id);
      expect(event.pubkey, pubKey);
      expect(event.createdAt, createdAt);
      expect(event.kind, kind);
      expect(event.tags, tags);
      expect(event.content, content);
      expect(event.sig, sig);
    });

    test('Constructor from', () {
      int createdAt = 1672175320;
      int kind = 1;
      List<List<String>> tags = [];
      String content = "Ceci est une analyse du websocket";
      String privkey =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";

      Event event = Event.from(
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
        privkey: privkey,
      );

      expect(
        event.id,
        "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49",
      );
      expect(
        event.pubkey,
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b",
      );
      expect(event.createdAt, createdAt);
      expect(event.kind, kind);
      expect(event.tags, tags);
      expect(event.content, content);
      expect(verify(event.pubkey, event.id, event.sig), true);
    });
  });
}
