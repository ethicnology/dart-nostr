import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const awardeeKey =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

  group('NIP-58 Badge Definition (kind 30009)', () {
    test('creates a minimal badge definition', () {
      final event = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
      );

      expect(event.kind, 30009);
      expect(findTagValue(event.tags, 'd'), 'bravery');
      expect(event.content, '');
    });

    test('creates a badge definition with all fields', () {
      final event = Badge.definition(
        badgeId: 'medal',
        secretKey: secretKey,
        name: 'Medal of Honor',
        description: 'Awarded for outstanding contribution',
        image: 'https://example.com/badge.png',
        imageSize: '1024x1024',
        thumbnails: [
          const BadgeImage(
              url: 'https://example.com/thumb-512.png', size: '512x512'),
          const BadgeImage(
              url: 'https://example.com/thumb-64.png', size: '64x64'),
        ],
      );

      expect(event.kind, 30009);
      expect(findTagValue(event.tags, 'd'), 'medal');
      expect(findTagValue(event.tags, 'name'), 'Medal of Honor');
      expect(findTagValue(event.tags, 'description'),
          'Awarded for outstanding contribution');

      final imageTag = event.tags.firstWhere((t) => t[0] == 'image');
      expect(imageTag[1], 'https://example.com/badge.png');
      expect(imageTag[2], '1024x1024');

      final thumbTags = event.tags.where((t) => t[0] == 'thumb').toList();
      expect(thumbTags, hasLength(2));
      expect(thumbTags[0][1], 'https://example.com/thumb-512.png');
      expect(thumbTags[0][2], '512x512');
    });

    test('parses a badge definition', () {
      final event = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
        name: 'Bravery',
        description: 'For the brave',
        image: 'https://example.com/brave.png',
        imageSize: '256x256',
        thumbnails: [
          const BadgeImage(
              url: 'https://example.com/brave-sm.png', size: '64x64'),
        ],
      );

      final data = Badge.parseDefinition(event);
      expect(data.badgeId, 'bravery');
      expect(data.name, 'Bravery');
      expect(data.description, 'For the brave');
      expect(data.image!.url, 'https://example.com/brave.png');
      expect(data.image!.size, '256x256');
      expect(data.thumbnails, hasLength(1));
      expect(data.thumbnails[0].url, 'https://example.com/brave-sm.png');
    });

    test('parseDefinition throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['d', 'test']
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.parseDefinition(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('parseDefinition throws on missing d tag', () {
      final event = Event.from(
        kind: 30009,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.parseDefinition(event),
        throwsA(isA<MissingTagException>()),
      );
    });
  });

  group('NIP-58 Badge Award (kind 8)', () {
    test('creates a badge award', () {
      final def = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
      );

      final award = Badge.award(
        badgeDefinition: def,
        awardees: [(pubkey: awardeeKey, relay: 'wss://relay.example.com')],
        secretKey: secretKey,
      );

      expect(award.kind, 8);
      final aTag = findTagValue(award.tags, 'a');
      expect(aTag, contains(':bravery'));
      expect(aTag, startsWith('30009:'));

      final pTags = award.tags.where((t) => t[0] == 'p').toList();
      expect(pTags, hasLength(1));
      expect(pTags[0][1], awardeeKey);
      expect(pTags[0][2], 'wss://relay.example.com');
    });

    test('award throws on wrong definition kind', () {
      final notADef = Event.from(
        kind: 1,
        tags: [
          ['d', 'test']
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.award(
          badgeDefinition: notADef,
          awardees: [(pubkey: awardeeKey, relay: null)],
          secretKey: secretKey,
        ),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('award throws on missing d tag', () {
      final def = Event.from(
        kind: 30009,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.award(
          badgeDefinition: def,
          awardees: [(pubkey: awardeeKey, relay: null)],
          secretKey: secretKey,
        ),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('parses a badge award', () {
      final def = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
      );
      final award = Badge.award(
        badgeDefinition: def,
        awardees: [
          (pubkey: awardeeKey, relay: 'wss://relay.example.com'),
          (
            pubkey:
                '0000000000000000000000000000000000000000000000000000000000000001',
            relay: null
          ),
        ],
        secretKey: secretKey,
      );

      final data = Badge.parseAward(award);
      expect(data.coordinate, contains(':bravery'));
      expect(data.awardees, hasLength(2));
      expect(data.awardees[0].pubkey, awardeeKey);
      expect(data.awardees[0].relay, 'wss://relay.example.com');
      expect(data.awardees[1].relay, isNull);
    });

    test('parseAward throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.parseAward(event),
        throwsA(isA<InvalidKindException>()),
      );
    });
  });

  group('NIP-58 Profile Badges (kind 10008)', () {
    test('creates profile badges with current spec kind 10008', () {
      final def = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
      );
      final awardEvent = Badge.award(
        badgeDefinition: def,
        awardees: [(pubkey: awardeeKey, relay: null)],
        secretKey: secretKey,
      );

      final profile = Badge.profileBadges(
        badges: [(definition: def, award: awardEvent)],
        secretKey: secretKey,
        pubkey: awardeeKey,
      );

      // Spec migration: was kind 30008 with d=profile_badges, now 10008
      // as a NIP-51 standard list.
      expect(profile.kind, 10008);
      expect(findTagValue(profile.tags, 'd'), isNull);

      // a and e tags should be adjacent (a immediately followed by e) per
      // spec, so consumers that pair by adjacency match correctly.
      expect(profile.tags[0][0], 'a');
      expect(profile.tags[1][0], 'e');
      expect(profile.tags[1][1], awardEvent.id);
    });

    test('profileBadges throws on wrong definition kind', () {
      final notDef = Event.from(
        kind: 1,
        tags: [
          ['d', 'test']
        ],
        content: '',
        secretKey: secretKey,
      );
      final awardEvent = Event.from(
        kind: 8,
        tags: [
          ['p', awardeeKey]
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.profileBadges(
          badges: [(definition: notDef, award: awardEvent)],
          secretKey: secretKey,
          pubkey: awardeeKey,
        ),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('profileBadges throws on wrong award kind', () {
      final def = Badge.definition(
        badgeId: 'test',
        secretKey: secretKey,
      );
      final notAward = Event.from(
        kind: 1,
        tags: [
          ['p', awardeeKey]
        ],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.profileBadges(
          badges: [(definition: def, award: notAward)],
          secretKey: secretKey,
          pubkey: awardeeKey,
        ),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('profileBadges throws when award lacks awarded pubkey', () {
      final def = Badge.definition(
        badgeId: 'test',
        secretKey: secretKey,
      );
      final awardEvent = Badge.award(
        badgeDefinition: def,
        awardees: [(pubkey: awardeeKey, relay: null)],
        secretKey: secretKey,
      );
      // Use a different pubkey that's not in the award
      expect(
        () => Badge.profileBadges(
          badges: [(definition: def, award: awardEvent)],
          secretKey: secretKey,
          pubkey:
              '0000000000000000000000000000000000000000000000000000000000000001',
        ),
        throwsA(isA<NostrException>()),
      );
    });

    test('parses profile badges', () {
      final def = Badge.definition(
        badgeId: 'bravery',
        secretKey: secretKey,
      );
      final awardEvent = Badge.award(
        badgeDefinition: def,
        awardees: [(pubkey: awardeeKey, relay: null)],
        secretKey: secretKey,
      );

      final profile = Badge.profileBadges(
        badges: [(definition: def, award: awardEvent)],
        secretKey: secretKey,
        pubkey: awardeeKey,
      );

      final data = Badge.parseProfileBadges(profile);
      expect(data.badges, hasLength(1));
      expect(data.badges[0].coordinate, contains(':bravery'));
      expect(data.badges[0].awardEventId, awardEvent.id);
    });

    test('parseProfileBadges pairs by adjacency (a then e)', () {
      // Per spec, pairs are adjacent. `a1` without a following `e` is
      // discarded when `a2` arrives; the next `e` pairs with `a2`.
      final event = Event.from(
        kind: 10008,
        tags: [
          ['a', '30009:abc:badge1'],
          ['a', '30009:abc:badge2'],
          ['e', 'event1'],
        ],
        content: '',
        secretKey: secretKey,
      );

      final data = Badge.parseProfileBadges(event);
      expect(data.badges, hasLength(1));
      expect(data.badges[0].coordinate, '30009:abc:badge2');
      expect(data.badges[0].awardEventId, 'event1');
    });

    test('parseProfileBadges pairs multiple adjacent a/e tags in order', () {
      final event = Event.from(
        kind: 10008,
        tags: [
          ['a', '30009:abc:badge1'],
          ['e', 'event1'],
          ['a', '30009:abc:badge2'],
          ['e', 'event2'],
        ],
        content: '',
        secretKey: secretKey,
      );

      final data = Badge.parseProfileBadges(event);
      expect(data.badges, hasLength(2));
      expect(data.badges[0].coordinate, '30009:abc:badge1');
      expect(data.badges[0].awardEventId, 'event1');
      expect(data.badges[1].coordinate, '30009:abc:badge2');
      expect(data.badges[1].awardEventId, 'event2');
    });

    test('parseProfileBadges accepts legacy kind 30008 events', () {
      // Backward compat: read existing kind-30008 events from clients
      // that pre-date the 10008 migration.
      final event = Event.from(
        kind: 30008,
        tags: [
          ['d', 'profile_badges'],
          ['a', '30009:abc:badge1'],
          ['e', 'event1'],
        ],
        content: '',
        secretKey: secretKey,
      );

      final data = Badge.parseProfileBadges(event);
      expect(data.badges, hasLength(1));
      expect(data.badges[0].coordinate, '30009:abc:badge1');
    });

    test('parseProfileBadges throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [],
        content: '',
        secretKey: secretKey,
      );
      expect(
        () => Badge.parseProfileBadges(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('award throws when awardees is empty', () {
      final def = Badge.definition(
        badgeId: 'test',
        secretKey: secretKey,
      );
      expect(
        () => Badge.award(
          badgeDefinition: def,
          awardees: const [],
          secretKey: secretKey,
        ),
        throwsA(isA<NostrException>()),
      );
    });
  });

  group('NIP-58 typedef', () {
    test('Nip58 alias works', () {
      final event = Nip58.definition(
        badgeId: 'test',
        secretKey: secretKey,
      );
      expect(event.kind, 30009);
    });
  });
}
