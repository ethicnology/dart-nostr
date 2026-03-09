import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip38.create(
    statusType: 'general',
    content: 'Working on dart-nostr',
    secretKey: secretKey,
    url: 'https://github.com/ethicnology/dart-nostr',
  );
  assert(event.kind == 30315);

  final status = Nip38.parse(event);
  assert(status.statusType == 'general');
  assert(status.content == 'Working on dart-nostr');
  print('Status: ${status.content}');
}
