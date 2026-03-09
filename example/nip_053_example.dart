import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip53.create(
    identifier: 'my-stream',
    secretKey: secretKey,
    title: 'Live Coding Session',
    status: 'live',
    streaming: 'https://stream.example.com/live.m3u8',
    participants: [
      const LiveParticipant(pubkey: 'host-pubkey', role: 'Host'),
    ],
  );
  assert(event.kind == 30311);

  final activity = Nip53.parse(event);
  assert(activity.title == 'Live Coding Session');
  assert(activity.status == 'live');
  print('Live: ${activity.title} (${activity.status})');
}
