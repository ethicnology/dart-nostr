import 'package:nostr/nostr.dart';

void main() {
  const aliceKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const bobKey =
      'e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45';
  final bobPubkey = Keys(bobKey).public;

  // Define a badge
  final definition = Badge.definition(
    badgeId: 'bravery',
    secretKey: aliceKey,
    name: 'Medal of Bravery',
    description: 'Awarded to users demonstrating bravery',
    image: 'https://nostr.academy/awards/bravery.png',
    imageSize: '1024x1024',
    thumbnails: [
      const BadgeImage(
        url: 'https://nostr.academy/awards/bravery_256x256.png',
        size: '256x256',
      ),
    ],
  );
  assert(definition.kind == 30009);
  print('Badge defined: ${findTagValue(definition.tags, 'd')}');

  // Award the badge to Bob
  final award = Badge.award(
    badgeDefinition: definition,
    awardees: [(pubkey: bobPubkey, relay: 'wss://relay.damus.io')],
    secretKey: aliceKey,
  );
  assert(award.kind == 8);
  print('Awarded to: ${findTagValue(award.tags, 'p')}');

  // Bob adds the badge to his profile
  final profile = Badge.profileBadges(
    badges: [(definition: definition, award: award)],
    secretKey: bobKey,
    pubkey: Keys(bobKey).public,
  );
  assert(profile.kind == 30008);
  print('Profile badges event created');
}
