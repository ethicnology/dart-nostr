import 'package:nostr/nostr.dart';

void main() {
  final event = Event.partial(
    kind: 9,
    pubkey: 'aabbccdd' * 8,
    createdAt: 1700000000,
    tags: [
      ['h', 'my-group'],
      ['previous', 'prev-event-id'],
    ],
    content: 'Hello group!',
  );

  final msg = Nip29.decode(event);
  assert(msg.groupId == 'my-group');
  assert(msg.content == 'Hello group!');
  print('Group message in ${msg.groupId}: ${msg.content}');
}
