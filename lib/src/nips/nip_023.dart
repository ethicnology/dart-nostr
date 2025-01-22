import 'package:nostr/nostr.dart';

/// A utility class to handle Nostr long-form content a.k.a. Articles according to NIP-23.
/// Provides decoding, and validation functionalities for Nostr articles.
///
/// Example usage:
/// ```dart
/// var article = Nip23.decode(event);
/// ```
class Nip23 {
  static const int kindArticle = 30023;
  static const int kindDraft = 30024;

  /// Returns a [Nip23Article] instance representing the decoded event.
  ///
  /// Throws an [Exception] if the event is not a valid NIP-23 kind.
  static Nip23Article decode(Event event) => Nip23Article.fromEvent(event);
}

/// Represents a Nostr long-form content event according to NIP-23.
/// Provides a structured way to handle article events instead of using raw Maps.
class Nip23Article {
  ///  The article's content in Markdown format.
  final String content;

  ///  The public key of the author.
  final String pubkey;

  ///  Unix timestamp of the event creation.
  final int createdAt;

  ///  A unique identifier for the article a.k.a `d` tag.
  final String articleId;

  ///  (Optional) The title of the article.
  final String? title;

  ///  (Optional) URL of an image associated with the article.
  final String? image;

  ///  (Optional) A short summary of the article.
  final String? summary;

  ///  (Optional) Unix timestamp of the first publication.
  final int? publishedAt;

  ///  (Optional) List of topics (hashtags).
  final List<String>? topics;

  ///  (Optional) Extra tags for metadata.
  final List<List<String>>? additionalTags;

  ///  should be either [Nip23.kindArticle] or [Nip23.kindDraft].
  final int kind;

  /// Constructs a [Nip23Article].
  Nip23Article({
    required this.content,
    required this.pubkey,
    required this.createdAt,
    required this.articleId,
    this.title,
    this.image,
    this.summary,
    this.publishedAt,
    this.topics,
    this.additionalTags,
    this.kind = Nip23.kindArticle,
  }) {
    if (kind != Nip23.kindArticle && kind != Nip23.kindDraft) {
      throw Exception('Invalid kind for Nip23Article');
    }
  }

  /// Factory constructor to create a [Nip23Article] from an [Event] instance.
  ///
  /// Throws an [Exception] if any required field is missing or invalid.
  factory Nip23Article.fromEvent(Event event) {
    if (event.kind != Nip23.kindArticle && event.kind != Nip23.kindDraft) {
      throw Exception('Invalid NIP-23 kind: ${event.kind}.');
    }

    final articleId = _getTagValue(event.tags, 'd');
    if (articleId == null) {
      throw Exception('Missing required tag: d (articleId).');
    }

    final title = _getTagValue(event.tags, 'title');
    final image = _getTagValue(event.tags, 'image');
    final summary = _getTagValue(event.tags, 'summary');
    final publishedAtStr = _getTagValue(event.tags, 'published_at');
    final topics = _getTagValues(event.tags, 't');

    // Extract additional tags by excluding known event.tags
    List<List<String>>? additionalTags = event.tags.where((tag) {
      return !['d', 'title', 'image', 'summary', 'published_at', 't']
          .contains(tag[0]);
    }).toList();
    if (additionalTags.isEmpty) additionalTags = null;

    return Nip23Article(
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      articleId: articleId,
      title: title,
      image: image,
      summary: summary,
      publishedAt: publishedAtStr != null ? int.tryParse(publishedAtStr) : null,
      topics: topics,
      additionalTags: additionalTags,
      kind: event.kind,
    );
  }

  // Helper to extract single tag value.
  static String? _getTagValue(List<List<String>> tags, String tagName) {
    for (var tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName) {
        return tag.length > 1 ? tag[1] : null;
      }
    }
    return null;
  }

  // Helper to extract multiple tag values.
  static List<String>? _getTagValues(List<List<String>> tags, String tagName) {
    List<String> values = [];
    for (var tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName && tag.length > 1) {
        values.add(tag[1]);
      }
    }
    return values.isNotEmpty ? values : null;
  }
}
