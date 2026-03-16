import 'package:nostr/nostr.dart';

/// File Metadata — [NIP-94](https://github.com/nostr-protocol/nips/blob/master/94.md)
///
/// Publishes metadata about shared files (kind 1063) for organization,
/// classification, and integrity verification by file-sharing clients.
class FileMetadata {
  /// Event kind for file metadata.
  static const int kindFileMetadata = 1063;

  /// Creates a kind-1063 file metadata event.
  ///
  /// [url] is the direct URL to download the file.
  /// [mimeType] is the MIME type in lowercase (e.g. `"image/jpeg"`).
  /// [sha256] is the SHA-256 hex-encoded hash of the file.
  /// [secretKey] is the hex-encoded secret key.
  /// [content] is an optional caption / description of the file.
  /// [originalSha256] is the SHA-256 hash of the original file before any
  /// transformations done by the upload server (`ox` tag).
  /// [size] is the file size in bytes.
  /// [dimensions] is the image size as `"WxH"` (e.g. `"640x480"`).
  /// [magnet] is a magnet URI.
  /// [torrentInfoHash] is a torrent infohash (`i` tag).
  /// [blurhash] is a blurhash string for progressive loading placeholders.
  /// [thumb] is a thumbnail URL with optional SHA-256 hash.
  /// [image] is a preview image URL with optional SHA-256 hash.
  /// [summary] is a text excerpt of the file content.
  /// [alt] is an accessibility description.
  /// [fallback] is a list of fallback URLs in case the primary URL fails.
  /// [service] is the service type serving the file (e.g. NIP-96).
  static Event create({
    required String url,
    required String mimeType,
    required String sha256,
    required String secretKey,
    String content = '',
    String? originalSha256,
    int? size,
    String? dimensions,
    String? magnet,
    String? torrentInfoHash,
    String? blurhash,
    ({String url, String? sha256})? thumb,
    ({String url, String? sha256})? image,
    String? summary,
    String? alt,
    List<String> fallback = const [],
    String? service,
  }) {
    final tags = <List<String>>[
      ['url', url],
      ['m', mimeType],
      ['x', sha256],
    ];

    if (originalSha256 != null) tags.add(['ox', originalSha256]);
    if (size != null) tags.add(['size', size.toString()]);
    if (dimensions != null) tags.add(['dim', dimensions]);
    if (magnet != null) tags.add(['magnet', magnet]);
    if (torrentInfoHash != null) tags.add(['i', torrentInfoHash]);
    if (blurhash != null) tags.add(['blurhash', blurhash]);
    if (thumb != null) {
      tags.add(thumb.sha256 != null
          ? ['thumb', thumb.url, thumb.sha256!]
          : ['thumb', thumb.url]);
    }
    if (image != null) {
      tags.add(image.sha256 != null
          ? ['image', image.url, image.sha256!]
          : ['image', image.url]);
    }
    if (summary != null) tags.add(['summary', summary]);
    if (alt != null) tags.add(['alt', alt]);
    for (final fb in fallback) {
      tags.add(['fallback', fb]);
    }
    if (service != null) tags.add(['service', service]);

    return Event.from(
      kind: kindFileMetadata,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-1063 event into a [FileMetadataData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 1063.
  /// Throws [MissingTagException] if `url`, `m`, or `x` tags are absent.
  static FileMetadataData parse(Event event) {
    if (event.kind != kindFileMetadata) {
      throw InvalidKindException(event.kind, [kindFileMetadata]);
    }

    final url = findTagValue(event.tags, 'url');
    if (url == null) throw MissingTagException('url');

    final mimeType = findTagValue(event.tags, 'm');
    if (mimeType == null) throw MissingTagException('m');

    final sha256 = findTagValue(event.tags, 'x');
    if (sha256 == null) throw MissingTagException('x');

    // Parse thumb and image tags (may have a second element with SHA-256)
    ({String url, String? sha256})? thumb;
    ({String url, String? sha256})? image;
    final fallback = <String>[];

    for (final tag in event.tags) {
      if (tag.length < 2) continue;
      switch (tag[0]) {
        case 'thumb':
          thumb = (url: tag[1], sha256: tag.length > 2 ? tag[2] : null);
        case 'image':
          image = (url: tag[1], sha256: tag.length > 2 ? tag[2] : null);
        case 'fallback':
          fallback.add(tag[1]);
      }
    }

    final sizeStr = findTagValue(event.tags, 'size');

    return FileMetadataData(
      url: url,
      mimeType: mimeType,
      sha256: sha256,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      content: event.content,
      originalSha256: findTagValue(event.tags, 'ox'),
      size: sizeStr != null ? int.tryParse(sizeStr) : null,
      dimensions: findTagValue(event.tags, 'dim'),
      magnet: findTagValue(event.tags, 'magnet'),
      torrentInfoHash: findTagValue(event.tags, 'i'),
      blurhash: findTagValue(event.tags, 'blurhash'),
      thumb: thumb,
      image: image,
      summary: findTagValue(event.tags, 'summary'),
      alt: findTagValue(event.tags, 'alt'),
      fallback: fallback,
      service: findTagValue(event.tags, 'service'),
    );
  }
}

/// Parsed file metadata (kind 1063).
class FileMetadataData {
  /// The direct URL to download the file.
  final String url;

  /// MIME type in lowercase (e.g. `"image/jpeg"`).
  final String mimeType;

  /// SHA-256 hex-encoded hash of the file.
  final String sha256;

  /// Caption / description of the file.
  final String content;

  /// SHA-256 hash of the original file before upload server transformations.
  final String? originalSha256;

  /// File size in bytes.
  final int? size;

  /// Image dimensions as `"WxH"` (e.g. `"640x480"`).
  final String? dimensions;

  /// Magnet URI.
  final String? magnet;

  /// Torrent infohash.
  final String? torrentInfoHash;

  /// Blurhash for progressive loading placeholders.
  final String? blurhash;

  /// Thumbnail URL with optional SHA-256 hash.
  final ({String url, String? sha256})? thumb;

  /// Preview image URL with optional SHA-256 hash.
  final ({String url, String? sha256})? image;

  /// Text excerpt of the file content.
  final String? summary;

  /// Accessibility description.
  final String? alt;

  /// Fallback URLs in case the primary URL fails.
  final List<String> fallback;

  /// Service type serving the file (e.g. NIP-96).
  final String? service;

  /// The public key of the event author.
  final String pubkey;

  /// Unix timestamp of the event.
  final int createdAt;

  /// Creates a [FileMetadataData].
  const FileMetadataData({
    required this.url,
    required this.mimeType,
    required this.sha256,
    required this.pubkey,
    required this.createdAt,
    this.content = '',
    this.originalSha256,
    this.size,
    this.dimensions,
    this.magnet,
    this.torrentInfoHash,
    this.blurhash,
    this.thumb,
    this.image,
    this.summary,
    this.alt,
    this.fallback = const [],
    this.service,
  });
}

typedef Nip94 = FileMetadata;
