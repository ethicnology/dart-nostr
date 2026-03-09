import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip28.createChannel(
    name: 'dart-nostr',
    about: 'Discussion about the dart-nostr package',
    picture: 'https://example.com/logo.png',
    secretKey: secretKey,
  );
  assert(event.kind == 40);

  final channel = Nip28.getChannelCreation(event);
  assert(channel.name == 'dart-nostr');
  print('Channel: ${channel.name}');
}
