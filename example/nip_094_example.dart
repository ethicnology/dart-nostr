import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Create a file metadata event (kind 1063)
  final event = FileMetadata.create(
    url: 'https://image.nostr.build/example.jpg',
    mimeType: 'image/jpeg',
    sha256:
        '1aea8e98e0e5d969b7124f553b88dfae47d1f00472ea8c0dbf4ac4577d39ef02',
    secretKey: secretKey,
    content: 'A beautiful sunset photo',
    originalSha256:
        'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    size: 524288,
    dimensions: '1920x1080',
    blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
    thumb: (url: 'https://image.nostr.build/thumb.jpg', sha256: null),
    alt: 'Photo of a sunset with orange and purple sky',
  );
  assert(event.kind == 1063);
  print('File metadata: ${findTagValue(event.tags, 'url')}');

  // Parse it back
  final data = FileMetadata.parse(event);
  assert(data.url == 'https://image.nostr.build/example.jpg');
  assert(data.mimeType == 'image/jpeg');
  assert(data.size == 524288);
  assert(data.dimensions == '1920x1080');
  assert(data.content == 'A beautiful sunset photo');
  assert(data.alt == 'Photo of a sunset with orange and purple sky');
  print('Parsed: ${data.mimeType} ${data.dimensions} (${data.size} bytes)');
}
