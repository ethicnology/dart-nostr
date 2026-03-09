import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip072', () {
    const String secretKey =
        '826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8';
    const String moderatorPubkey =
        '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

    group('community definition', () {
      test('encodes a community with all fields', () {
        final event = Nip72.community(
          id: 'my-community',
          secretKey: secretKey,
          name: 'My Community',
          description: 'A test community',
          image: 'https://example.com/image.png',
          imageDimensions: '1024x768',
          rules: 'Be kind.',
          moderators: [moderatorPubkey],
          relays: [const CommunityRelay(url: 'wss://relay.com')],
        );
        expect(event.kind, 34550);
        expect(findTagValue(event.tags, 'd'), 'my-community');
        expect(findTagValue(event.tags, 'name'), 'My Community');
        expect(findTagValue(event.tags, 'description'), 'A test community');
        expect(findTagValue(event.tags, 'rules'), 'Be kind.');
        expect(findTagValue(event.tags, 'relay'), 'wss://relay.com');

        // Image tag with dimensions
        final imageTag =
            event.tags.firstWhere((t) => t[0] == 'image');
        expect(imageTag[1], 'https://example.com/image.png');
        expect(imageTag[2], '1024x768');

        // Moderator p tag
        final pTag = event.tags.firstWhere((t) => t[0] == 'p');
        expect(pTag[1], moderatorPubkey);
        expect(pTag[3], 'moderator');
      });

      test('encodes a minimal community', () {
        final event = Nip72.community(
          id: 'minimal',
          secretKey: secretKey,
        );
        expect(event.kind, 34550);
        expect(findTagValue(event.tags, 'd'), 'minimal');
        expect(event.tags.length, 1); // only d tag
      });

      test('decodes a community definition', () {
        final event = Nip72.community(
          id: 'test-community',
          secretKey: secretKey,
          name: 'Test',
          description: 'Desc',
          image: 'https://example.com/img.jpg',
          rules: 'Rule 1',
          moderators: [moderatorPubkey],
          relays: [
            const CommunityRelay(url: 'wss://relay1.com', marker: 'author'),
            const CommunityRelay(url: 'wss://relay2.com', marker: 'approvals'),
          ],
        );
        final community = Nip72.parseCommunity(event);
        expect(community.id, 'test-community');
        expect(community.name, 'Test');
        expect(community.description, 'Desc');
        expect(community.image, 'https://example.com/img.jpg');
        expect(community.rules, 'Rule 1');
        expect(community.moderators.length, 1);
        expect(community.moderators[0].pubkey, moderatorPubkey);
        expect(community.moderators[0].role, 'moderator');
        expect(community.relays.length, 2);
        expect(community.relays[0].url, 'wss://relay1.com');
        expect(community.relays[0].marker, 'author');
        expect(community.relays[1].url, 'wss://relay2.com');
        expect(community.relays[1].marker, 'approvals');
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [
            ['d', 'test']
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip72.parseCommunity(event),
            throwsA(isA<InvalidKindException>()));
      });

      test('throws MissingTagException when d tag is absent', () {
        final event = Event.from(
          kind: 34550,
          tags: [],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip72.parseCommunity(event),
            throwsA(isA<MissingTagException>()));
      });
    });

    group('community approval', () {
      test('encodes an approval event', () {
        final event = Nip72.approval(
          communityCoord: '34550:$moderatorPubkey:my-community',
          approvedEventId:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          approvedEventPubkey: moderatorPubkey,
          approvedEventKind: 1,
          secretKey: secretKey,
        );
        expect(event.kind, 4550);
        expect(findTagValue(event.tags, 'a'),
            '34550:$moderatorPubkey:my-community');
        expect(findTagValue(event.tags, 'e'),
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        expect(findTagValue(event.tags, 'p'), moderatorPubkey);
        expect(findTagValue(event.tags, 'k'), '1');
      });

      test('encodes an approval with embedded event JSON', () {
        final approvedEvent = Event.from(
          kind: 1,
          tags: [],
          content: 'Hello community!',
          secretKey: secretKey,
        );
        final event = Nip72.approval(
          communityCoord: '34550:$moderatorPubkey:my-community',
          approvedEventId: approvedEvent.id,
          approvedEventPubkey: approvedEvent.pubkey,
          approvedEventKind: 1,
          secretKey: secretKey,
          approvedEventJson: approvedEvent.toJson(),
        );
        expect(event.content, isNotEmpty);
      });

      test('decodes an approval event', () {
        final event = Nip72.approval(
          communityCoord: '34550:$moderatorPubkey:my-community',
          approvedEventId:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          approvedEventPubkey: moderatorPubkey,
          approvedEventKind: 1111,
          secretKey: secretKey,
        );
        final approval = Nip72.parseApproval(event);
        expect(approval.communityCoord,
            '34550:$moderatorPubkey:my-community');
        expect(approval.approvedEventId,
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        expect(approval.approvedEventPubkey, moderatorPubkey);
        expect(approval.approvedEventKind, 1111);
      });

      test('decodes an approval with embedded event in content', () {
        final approvedEvent = Event.from(
          kind: 1,
          tags: [],
          content: 'Post content',
          secretKey: secretKey,
        );
        final event = Nip72.approval(
          communityCoord: '34550:$moderatorPubkey:my-community',
          approvedEventId: approvedEvent.id,
          approvedEventPubkey: approvedEvent.pubkey,
          approvedEventKind: 1,
          secretKey: secretKey,
          approvedEventJson: approvedEvent.toJson(),
        );
        final approval = Nip72.parseApproval(event);
        expect(approval.approvedEvent, isNotNull);
        expect(approval.approvedEvent!.content, 'Post content');
      });

      test('throws InvalidKindException for wrong kind', () {
        final event = Event.from(
          kind: 1,
          tags: [
            ['a', '34550:pubkey:id']
          ],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip72.parseApproval(event),
            throwsA(isA<InvalidKindException>()));
      });

      test('throws MissingTagException when a tag is absent', () {
        final event = Event.from(
          kind: 4550,
          tags: [],
          content: '',
          secretKey: secretKey,
        );
        expect(() => Nip72.parseApproval(event),
            throwsA(isA<MissingTagException>()));
      });
    });

    test('typedef ModeratedCommunities works', () {
      final event = ModeratedCommunities.community(
        id: 'test',
        secretKey: secretKey,
      );
      expect(event.kind, 34550);
    });
  });
}
