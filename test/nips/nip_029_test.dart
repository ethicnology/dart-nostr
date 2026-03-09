import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip029', () {
    test('decode kind 9 group chat message', () {
      final event = Event.partial(
        kind: 9,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['h', 'mygroup123'],
          ['previous', 'abc12345', 'def67890'],
        ],
        content: 'Hello group!',
      );

      final msg = Nip29.decode(event);

      expect(msg.groupId, 'mygroup123');
      expect(msg.content, 'Hello group!');
      expect(msg.kind, 9);
      expect(msg.previousEvents, ['abc12345', 'def67890']);
      expect(msg.pubkey,
          'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233');
      expect(msg.createdAt, 1700000000);
      expect(msg.replyToEventId, isNull);
      expect(msg.subject, isNull);
    });

    test('decode kind 11 thread root with subject', () {
      final event = Event.partial(
        kind: 11,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['h', 'devgroup'],
          ['subject', 'Release planning'],
        ],
        content: 'Let us discuss the next release.',
      );

      final msg = Nip29.decode(event);

      expect(msg.groupId, 'devgroup');
      expect(msg.kind, 11);
      expect(msg.subject, 'Release planning');
      expect(msg.content, 'Let us discuss the next release.');
    });

    test('decode kind 12 thread reply', () {
      final event = Event.partial(
        kind: 12,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['h', 'devgroup'],
          ['e', 'root-event-id-hex'],
        ],
        content: 'I agree with the plan.',
      );

      final msg = Nip29.decode(event);

      expect(msg.groupId, 'devgroup');
      expect(msg.kind, 12);
      expect(msg.replyToEventId, 'root-event-id-hex');
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip29.decode(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('decode throws MissingTagException for missing h tag', () {
      final event = Event.partial(
        kind: 9,
        tags: [],
        content: 'no group id',
      );

      expect(
        () => Nip29.decode(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('decodeMetadata parses kind 39000', () {
      final event = Event.partial(
        kind: 39000,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'mygroup123'],
          ['name', 'My Group'],
          ['about', 'A test group'],
          ['picture', 'https://example.com/pic.jpg'],
          ['open'],
          ['public'],
        ],
      );

      final meta = Nip29.decodeMetadata(event);

      expect(meta.groupId, 'mygroup123');
      expect(meta.name, 'My Group');
      expect(meta.about, 'A test group');
      expect(meta.picture, 'https://example.com/pic.jpg');
      expect(meta.isOpen, isTrue);
      expect(meta.isPublic, isTrue);
    });

    test('decodeMetadata with closed private group', () {
      final event = Event.partial(
        kind: 39000,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'private-group'],
          ['name', 'Secret Group'],
        ],
      );

      final meta = Nip29.decodeMetadata(event);

      expect(meta.groupId, 'private-group');
      expect(meta.name, 'Secret Group');
      expect(meta.isOpen, isFalse);
      expect(meta.isPublic, isFalse);
    });

    test('decodeMetadata throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip29.decodeMetadata(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('decode real-world kind 9 from groups.fiatjaf.com', () {
      final event = Event.fromMap({
        "kind": 9,
        "id":
            "34309c0b0d3642c77042d1b6f21f6fc6d7c3e60fdc37fcfa855144d5a9a3023f",
        "pubkey":
            "0b28af7e8d2d961e22f63e9aa2400ff2dd11b398a4c29a512aaea256a9662308",
        "created_at": 1771896515,
        "tags": [
          ["h", "e1cc34"]
        ],
        "content": "hello",
        "sig":
            "82fd9f805adba34c219f32921f9df6b8a18d9496875366c6d5698a6a319e8f4675bbdd50aa359cc6c17fd4ff54cdb9a3afbb3e7a9bf79ed0aca2bafa66b59434"
      });

      final msg = Nip29.decode(event);
      expect(msg.groupId, 'e1cc34');
      expect(msg.content, 'hello');
      expect(msg.kind, 9);
      expect(msg.pubkey,
          '0b28af7e8d2d961e22f63e9aa2400ff2dd11b398a4c29a512aaea256a9662308');
    });

    test('typedef alias works', () {
      expect(Groups.kindGroupChatMessage, 9);
    });
  });
}
