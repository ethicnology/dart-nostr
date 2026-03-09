import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip9.request(
    eventIds: ['abc123', 'def456'],
    content: 'published by accident',
    secretKey: secretKey,
  );
  assert(event.kind == 5);

  final req = Nip9.parse(event);
  assert(req.eventIds.length == 2);
  assert(req.reason == 'published by accident');
  print('Deletion request: ${req.eventIds}');
}
