import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip89.encodeHandlerInfo(
    id: 'my-nostr-app',
    secretKey: secretKey,
    supportedKinds: [1, 30023],
    platforms: [
      const PlatformHandler(
        platform: 'web',
        url: 'https://app.example.com/<bech32>',
        entityType: 'nevent',
      ),
    ],
    metadata: {'name': 'My Nostr App', 'about': 'A great client'},
  );
  assert(event.kind == 31990);

  final handler = Nip89.decodeHandlerInfo(event);
  assert(handler.supportedKinds.contains(1));
  assert(handler.metadata!['name'] == 'My Nostr App');
  print('Handler: ${handler.metadata!['name']}');
}
