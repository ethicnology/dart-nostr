import 'package:nostr/nostr.dart';

/// Long-form content — [NIP-23](https://github.com/nostr-protocol/nips/blob/master/23.md)
///
/// A utility class to handle Nostr long-form content a.k.a. Articles according to NIP-23.
/// Provides decoding, and validation functionalities for Nostr articles.
///
/// Example usage:
/// ```dart
/// var article = Nip23.decode(event);
/// ```
class Nip23 {
  /// Event kind for a published article.
  static const int kindArticle = 30023;

  /// Event kind for a draft article.
  static const int kindDraft = 30024;

  /// Returns a [Nip23Article] instance representing the decoded event.
  ///
  /// Throws [InvalidKindException] if the event is not a valid NIP-23 kind.
  static Nip23Article decode(Event event) => Nip23Article.fromEvent(event);
}

/// Represents a Nostr long-form content event according to NIP-23.
///
/// Provides a structured way to handle article events instead of using raw Maps.
class Nip23Article {
  /// The article's content in Markdown format.
  final String content;

  /// The public key of the author.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// A unique identifier for the article a.k.a `d` tag.
  final String articleId;

  /// The title of the article (optional).
  final String? title;

  /// URL of an image associated with the article (optional).
  final String? image;

  /// A short summary of the article (optional).
  final String? summary;

  /// Unix timestamp of the first publication (optional).
  final int? publishedAt;

  /// List of topics (hashtags) (optional).
  final List<String>? topics;

  /// Extra tags for metadata (optional).
  final List<List<String>>? additionalTags;

  /// The event kind, should be either [Nip23.kindArticle] or [Nip23.kindDraft].
  final int kind;

  /// Constructs a [Nip23Article].
  ///
  /// Throws [InvalidKindException] if [kind] is not [Nip23.kindArticle] or [Nip23.kindDraft].
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
      throw InvalidKindException(kind, [Nip23.kindArticle, Nip23.kindDraft]);
    }
  }

  /// Factory constructor to create a [Nip23Article] from an [Event] instance.
  ///
  /// Throws [InvalidKindException] if the event kind is not valid for NIP-23.
  /// Throws [MissingTagException] if the required `d` tag is absent.
  factory Nip23Article.fromEvent(Event event) {
    if (event.kind != Nip23.kindArticle && event.kind != Nip23.kindDraft) {
      throw InvalidKindException(event.kind, [Nip23.kindArticle, Nip23.kindDraft]);
    }

    final articleId = _getTagValue(event.tags, 'd');
    if (articleId == null) {
      throw MissingTagException('d');
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
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName) {
        return tag.length > 1 ? tag[1] : null;
      }
    }
    return null;
  }

  // Helper to extract multiple tag values.
  static List<String>? _getTagValues(List<List<String>> tags, String tagName) {
    final values = <String>[];
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName && tag.length > 1) {
        values.add(tag[1]);
      }
    }
    return values.isNotEmpty ? values : null;
  }
}

typedef Article = Nip23;
