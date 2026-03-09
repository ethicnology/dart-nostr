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

  /// Creates a kind-30023 (or 30024 draft) long-form content event.
  ///
  /// [articleId] is the unique `d` tag identifier.
  /// [content] is the Markdown body.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [draft] creates a kind-30024 draft instead of a published article.
  static Event encode({
    required String articleId,
    required String content,
    required String secretKey,
    String? title,
    String? image,
    String? summary,
    int? publishedAt,
    List<String> topics = const [],
    bool draft = false,
  }) {
    final List<List<String>> tags = [
      ['d', articleId],
      if (title != null) ['title', title],
      if (image != null) ['image', image],
      if (summary != null) ['summary', summary],
      if (publishedAt != null) ['published_at', publishedAt.toString()],
      for (final t in topics) ['t', t],
    ];

    return Event.from(
      kind: draft ? kindDraft : kindArticle,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

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

  /// List of topics (hashtags).
  final List<String> topics;

  /// Extra tags for metadata.
  final List<List<String>> additionalTags;

  /// The event kind, should be either [Nip23.kindArticle] or [Nip23.kindDraft].
  final int kind;

  /// Creates a [Nip23Article] with the given fields.
  const Nip23Article({
    required this.content,
    required this.pubkey,
    required this.createdAt,
    required this.articleId,
    this.title,
    this.image,
    this.summary,
    this.publishedAt,
    this.topics = const [],
    this.additionalTags = const [],
    this.kind = Nip23.kindArticle,
  });

  /// Factory constructor to create a [Nip23Article] from an [Event] instance.
  ///
  /// Throws [InvalidKindException] if the event kind is not valid for NIP-23.
  /// Throws [MissingTagException] if the required `d` tag is absent.
  factory Nip23Article.fromEvent(Event event) {
    if (event.kind != Nip23.kindArticle && event.kind != Nip23.kindDraft) {
      throw InvalidKindException(event.kind, [Nip23.kindArticle, Nip23.kindDraft]);
    }

    final articleId = findTagValue(event.tags, 'd');
    if (articleId == null) {
      throw MissingTagException('d');
    }

    final title = findTagValue(event.tags, 'title');
    final image = findTagValue(event.tags, 'image');
    final summary = findTagValue(event.tags, 'summary');
    final publishedAtStr = findTagValue(event.tags, 'published_at');
    final topics = findAllTagValues(event.tags, 't');

    // Extract additional tags by excluding known tag types
    final additionalTags = event.tags.where((tag) {
      return !['d', 'title', 'image', 'summary', 'published_at', 't']
          .contains(tag[0]);
    }).toList();

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

}

typedef Article = Nip23;
