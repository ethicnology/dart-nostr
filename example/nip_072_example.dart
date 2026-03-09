import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip72.encodeCommunity(
    id: 'dart-devs',
    secretKey: secretKey,
    name: 'Dart Developers',
    description: 'A community for Dart and Flutter developers',
    rules: 'Be respectful',
    moderators: [Keys(secretKey).public],
  );
  assert(event.kind == 34550);

  final community = Nip72.decodeCommunity(event);
  assert(community.name == 'Dart Developers');
  assert(community.moderators.length == 1);
  print('Community: ${community.name}');
}
