import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  final vectors = jsonDecode(
    File('test/fixtures/rust_nostr_vectors.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final nip94 = vectors['nip94'] as Map<String, dynamic>;

  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Rust-nostr test vectors
  final imageUrl = nip94['image_url'] as String;
  final imageHash = nip94['image_hash'] as String;
  final mimeType = nip94['mime_type'] as String;
  final dimensions = nip94['dimensions'] as String;

  const originalSha256 =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';

  group('NIP-94 File Metadata (kind 1063)', () {
    test('creates a minimal file metadata event', () {
      final event = FileMetadata.create(
        url: imageUrl,
        mimeType: mimeType,
        sha256: imageHash,
        secretKey: secretKey,
      );

      expect(event.kind, 1063);
      expect(event.content, '');
      expect(findTagValue(event.tags, 'url'), imageUrl);
      expect(findTagValue(event.tags, 'm'), mimeType);
      expect(findTagValue(event.tags, 'x'), imageHash);
    });

    test('creates a file metadata event with all spec tags', () {
      final event = FileMetadata.create(
        url: imageUrl,
        mimeType: mimeType,
        sha256: imageHash,
        secretKey: secretKey,
        content: 'A beautiful sunset photo',
        originalSha256: originalSha256,
        size: 524288,
        dimensions: dimensions,
        magnet: 'magnet:?xt=urn:btih:abc123',
        torrentInfoHash: 'abc123def456',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        thumb: (url: 'https://example.com/thumb.jpg', sha256: imageHash),
        image: (url: 'https://example.com/preview.jpg', sha256: null),
        summary: 'Sunset over the ocean',
        alt: 'Photo of a sunset with orange and purple sky',
        fallback: [
          'https://fallback1.example.com/file.jpg',
          'https://fallback2.example.com/file.jpg',
        ],
        service: 'nip96',
      );

      expect(event.kind, 1063);
      expect(event.content, 'A beautiful sunset photo');
      expect(findTagValue(event.tags, 'url'), imageUrl);
      expect(findTagValue(event.tags, 'm'), mimeType);
      expect(findTagValue(event.tags, 'x'), imageHash);
      expect(findTagValue(event.tags, 'ox'), originalSha256);
      expect(findTagValue(event.tags, 'size'), '524288');
      expect(findTagValue(event.tags, 'dim'), dimensions);
      expect(findTagValue(event.tags, 'magnet'), 'magnet:?xt=urn:btih:abc123');
      expect(findTagValue(event.tags, 'i'), 'abc123def456');
      expect(
          findTagValue(event.tags, 'blurhash'), 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      expect(findTagValue(event.tags, 'summary'), 'Sunset over the ocean');
      expect(findTagValue(event.tags, 'alt'),
          'Photo of a sunset with orange and purple sky');
      expect(findTagValue(event.tags, 'service'), 'nip96');

      // thumb with sha256
      final thumbTag = event.tags.firstWhere((t) => t[0] == 'thumb');
      expect(thumbTag[1], 'https://example.com/thumb.jpg');
      expect(thumbTag[2], imageHash);

      // image without sha256
      final imageTag = event.tags.firstWhere((t) => t[0] == 'image');
      expect(imageTag[1], 'https://example.com/preview.jpg');
      expect(imageTag.length, 2);

      // fallback URLs
      final fallbackTags = event.tags.where((t) => t[0] == 'fallback').toList();
      expect(fallbackTags, hasLength(2));
      expect(fallbackTags[0][1], 'https://fallback1.example.com/file.jpg');
      expect(fallbackTags[1][1], 'https://fallback2.example.com/file.jpg');
    });

    test('parses tags in arbitrary order (rust-nostr vector)', () {
      // Mirrors rust-nostr test: parses_valid_tag_vector
      // Tags are intentionally NOT in canonical order
      final parseVector = nip94['parse_from_tags'] as Map<String, dynamic>;
      final tags = (parseVector['tags'] as List)
          .map((t) => (t as List).cast<String>().toList())
          .toList();

      final event = Event.from(
        kind: 1063,
        tags: tags,
        content: '',
        secretKey: secretKey,
      );

      final data = FileMetadata.parse(event);
      expect(data.url, imageUrl);
      expect(data.mimeType, mimeType);
      expect(data.sha256, imageHash);
      expect(data.dimensions, dimensions);
    });

    test('parses a minimal file metadata event', () {
      final event = FileMetadata.create(
        url: imageUrl,
        mimeType: mimeType,
        sha256: imageHash,
        secretKey: secretKey,
      );

      final data = FileMetadata.parse(event);
      expect(data.url, imageUrl);
      expect(data.mimeType, mimeType);
      expect(data.sha256, imageHash);
      expect(data.content, '');
      expect(data.originalSha256, isNull);
      expect(data.size, isNull);
      expect(data.dimensions, isNull);
      expect(data.magnet, isNull);
      expect(data.torrentInfoHash, isNull);
      expect(data.blurhash, isNull);
      expect(data.thumb, isNull);
      expect(data.image, isNull);
      expect(data.summary, isNull);
      expect(data.alt, isNull);
      expect(data.fallback, isEmpty);
      expect(data.service, isNull);
    });

    test('parses a fully populated file metadata event', () {
      final event = FileMetadata.create(
        url: imageUrl,
        mimeType: 'application/pdf',
        sha256: imageHash,
        secretKey: secretKey,
        content: 'Research paper',
        originalSha256: originalSha256,
        size: 1048576,
        dimensions: '1920x1080',
        magnet: 'magnet:?xt=urn:btih:xyz',
        torrentInfoHash: 'xyz789',
        blurhash: 'LGF5]+Yk^6#M@-5c,1J5@[or[Q6.',
        thumb: (url: 'https://example.com/thumb.png', sha256: imageHash),
        image: (url: 'https://example.com/preview.png', sha256: originalSha256),
        summary: 'A research paper on distributed systems',
        alt: 'PDF document about distributed systems',
        fallback: ['https://mirror.example.com/paper.pdf'],
        service: 'nip96',
      );

      final data = FileMetadata.parse(event);
      expect(data.url, imageUrl);
      expect(data.mimeType, 'application/pdf');
      expect(data.sha256, imageHash);
      expect(data.content, 'Research paper');
      expect(data.originalSha256, originalSha256);
      expect(data.size, 1048576);
      expect(data.dimensions, '1920x1080');
      expect(data.magnet, 'magnet:?xt=urn:btih:xyz');
      expect(data.torrentInfoHash, 'xyz789');
      expect(data.blurhash, 'LGF5]+Yk^6#M@-5c,1J5@[or[Q6.');
      expect(data.thumb!.url, 'https://example.com/thumb.png');
      expect(data.thumb!.sha256, imageHash);
      expect(data.image!.url, 'https://example.com/preview.png');
      expect(data.image!.sha256, originalSha256);
      expect(data.summary, 'A research paper on distributed systems');
      expect(data.alt, 'PDF document about distributed systems');
      expect(data.fallback, hasLength(1));
      expect(data.fallback[0], 'https://mirror.example.com/paper.pdf');
      expect(data.service, 'nip96');
    });

    test('parse throws on wrong kind', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['url', imageUrl],
          ['m', mimeType],
          ['x', imageHash],
        ],
        content: '',
        secretKey: secretKey,
      );

      expect(
        () => FileMetadata.parse(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('parse throws on missing url tag (rust-nostr vector)', () {
      final tags = (nip94['missing_url_tags'] as List)
          .map((t) => (t as List).cast<String>().toList())
          .toList();

      final event = Event.from(
        kind: 1063,
        tags: tags,
        content: '',
        secretKey: secretKey,
      );

      expect(
        () => FileMetadata.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('parse throws on missing m tag (rust-nostr vector)', () {
      final tags = (nip94['missing_mime_tags'] as List)
          .map((t) => (t as List).cast<String>().toList())
          .toList();

      final event = Event.from(
        kind: 1063,
        tags: tags,
        content: '',
        secretKey: secretKey,
      );

      expect(
        () => FileMetadata.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('parse throws on missing x tag (rust-nostr vector)', () {
      final tags = (nip94['missing_sha_tags'] as List)
          .map((t) => (t as List).cast<String>().toList())
          .toList();

      final event = Event.from(
        kind: 1063,
        tags: tags,
        content: '',
        secretKey: secretKey,
      );

      expect(
        () => FileMetadata.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('roundtrip: create then parse preserves all data', () {
      final event = FileMetadata.create(
        url: imageUrl,
        mimeType: 'video/mp4',
        sha256: imageHash,
        secretKey: secretKey,
        content: 'Demo video',
        originalSha256: originalSha256,
        size: 10485760,
        dimensions: '1280x720',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        thumb: (url: 'https://example.com/thumb.jpg', sha256: null),
        alt: 'A demo video',
      );

      final data = FileMetadata.parse(event);
      expect(data.url, imageUrl);
      expect(data.mimeType, 'video/mp4');
      expect(data.sha256, imageHash);
      expect(data.content, 'Demo video');
      expect(data.originalSha256, originalSha256);
      expect(data.size, 10485760);
      expect(data.dimensions, '1280x720');
      expect(data.blurhash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      expect(data.thumb!.url, 'https://example.com/thumb.jpg');
      expect(data.thumb!.sha256, isNull);
      expect(data.alt, 'A demo video');
      expect(data.magnet, isNull);
      expect(data.image, isNull);
    });
  });

  group('NIP-94 typedef', () {
    test('Nip94 alias works', () {
      final event = Nip94.create(
        url: imageUrl,
        mimeType: 'image/png',
        sha256: imageHash,
        secretKey: secretKey,
      );
      expect(event.kind, 1063);
    });
  });
}
