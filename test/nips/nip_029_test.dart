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

      final msg = Nip29.parseMessage(event);

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

      final msg = Nip29.parseMessage(event);

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

      final msg = Nip29.parseMessage(event);

      expect(msg.groupId, 'devgroup');
      expect(msg.kind, 12);
      expect(msg.replyToEventId, 'root-event-id-hex');
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip29.parseMessage(event),
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
        () => Nip29.parseMessage(event),
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

      final meta = Nip29.parseMetadata(event);

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

      final meta = Nip29.parseMetadata(event);

      expect(meta.groupId, 'private-group');
      expect(meta.name, 'Secret Group');
      expect(meta.isOpen, isFalse);
      expect(meta.isPublic, isFalse);
    });

    test('decodeMetadata throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip29.parseMetadata(event),
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

      final msg = Nip29.parseMessage(event);
      expect(msg.groupId, 'e1cc34');
      expect(msg.content, 'hello');
      expect(msg.kind, 9);
      expect(msg.pubkey,
          '0b28af7e8d2d961e22f63e9aa2400ff2dd11b398a4c29a512aaea256a9662308');
    });

    test('typedef alias works', () {
      expect(Nip29.kindGroupChatMessage, 9);
    });
  });

  group('Nip29 builders', () {
    const secret =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

    test('message() emits kind 9 with h tag and optional previous/reply', () {
      final event = Group.message(
        groupId: 'g1',
        content: 'hi',
        secretKey: secret,
        previousEvents: ['aaaaaaaa', 'bbbbbbbb'],
        replyToEventId: 'a' * 64,
      );
      expect(event.kind, Group.kindGroupChatMessage);
      expect(event.content, 'hi');
      final h = event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'h');
      expect(h[1], 'g1');
      final previous =
          event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'previous');
      expect(previous, ['previous', 'aaaaaaaa', 'bbbbbbbb']);
      final e = event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'e');
      expect(e[1], 'a' * 64);
    });

    test('threadRoot() emits kind 11 with subject tag', () {
      final event = Group.threadRoot(
        groupId: 'g1',
        subject: 'Hello world',
        content: 'body',
        secretKey: secret,
      );
      expect(event.kind, Group.kindGroupThreadRoot);
      final subject =
          event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'subject');
      expect(subject[1], 'Hello world');
    });

    test('threadReply() emits kind 12 with parent e tag', () {
      final event = Group.threadReply(
        groupId: 'g1',
        replyToEventId: 'b' * 64,
        content: 'reply',
        secretKey: secret,
      );
      expect(event.kind, Group.kindGroupThreadReply);
      final e = event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'e');
      expect(e[1], 'b' * 64);
    });

    test('joinRequest() emits kind 9021 with h tag', () {
      final event = Group.joinRequest(groupId: 'g1', secretKey: secret);
      expect(event.kind, Group.kindJoinRequest);
      expect(event.tags, [
        ['h', 'g1'],
      ]);
    });

    test('leaveRequest() emits kind 9022 with h tag', () {
      final event = Group.leaveRequest(groupId: 'g1', secretKey: secret);
      expect(event.kind, Group.kindLeaveRequest);
      expect(event.tags, [
        ['h', 'g1'],
      ]);
    });
  });

  group('Nip29.parseAdmins / parseMembers permissive', () {
    const secret =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

    test('parseAdmins strict throws on missing d', () {
      final event = Event.from(
        kind: Group.kindGroupAdmins,
        tags: [
          ['p', 'a' * 64, 'admin'],
        ],
        content: '',
        secretKey: secret,
      );
      expect(
          () => Group.parseAdmins(event), throwsA(isA<MissingTagException>()));
    });

    test('parseAdmins permissive records missing d', () {
      final event = Event.from(
        kind: Group.kindGroupAdmins,
        tags: [
          ['p', 'a' * 64, 'admin'],
        ],
        content: '',
        secretKey: secret,
      );
      final data = Group.parseAdmins(event, permissive: true);
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
      expect(data.admins, hasLength(1));
    });

    test('parseMembers permissive records missing d', () {
      final event = Event.from(
        kind: Group.kindGroupMembers,
        tags: [
          ['p', 'a' * 64],
        ],
        content: '',
        secretKey: secret,
      );
      final data = Group.parseMembers(event, permissive: true);
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
      expect(data.members, ['a' * 64]);
    });
  });
}
