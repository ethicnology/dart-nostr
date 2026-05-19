import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const _secret =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

void main() {
  group('Nip23.parse', () {
    test('should parse a valid event map into an ArticleData', () {
      final Map<String, dynamic> map = {
        'id': '',
        'kind': Nip23.kindArticle,
        'created_at': 1675642635,
        'content': 'This is a decoded article content.',
        'tags': [
          ['d', 'decoded-article'],
          ['title', 'Decoded Article'],
          ['image', 'https://example.com/decoded_image.png'],
          ['summary', 'A summary of the decoded article.'],
          ['published_at', '1296962229'],
          ['t', 'dart'],
          ['t', 'testing'],
          ['custom_tag', 'custom_value'],
        ],
        'pubkey': 'pubkey456',
        'sig': ''
      };

      final event = Event.fromMap(map, verify: false);
      final article = Nip23.parse(event);

      expect(article.kind, equals(Nip23.kindArticle));
      expect(article.content, equals('This is a decoded article content.'));
      expect(article.pubkey, equals('pubkey456'));
      expect(article.createdAt, equals(1675642635));
      expect(article.articleId, equals('decoded-article'));
      expect(article.title, equals('Decoded Article'));
      expect(article.image, equals('https://example.com/decoded_image.png'));
      expect(article.summary, equals('A summary of the decoded article.'));
      expect(article.publishedAt, equals(1296962229));
      expect(article.topics, equals(['dart', 'testing']));
      expect(
          article.additionalTags,
          equals([
            ['custom_tag', 'custom_value'],
          ]));
    });

    test('parses kind-30024 drafts identically', () {
      final event = Article.create(
        articleId: 'draft-1',
        content: 'wip',
        secretKey: _secret,
        draft: true,
      );
      expect(event.kind, Article.kindDraft);
      final article = Article.parse(event);
      expect(article.kind, Article.kindDraft);
      expect(article.articleId, 'draft-1');
    });

    test('rejects events outside kinds 30023/30024', () {
      final event = Event.from(
        kind: 1,
        tags: [
          ['d', 'x']
        ],
        content: '',
        secretKey: _secret,
      );
      expect(() => Article.parse(event), throwsA(isA<InvalidKindException>()));
    });

    test('strict mode throws on missing d tag', () {
      final event = Event.from(
        kind: Article.kindArticle,
        tags: [],
        content: 'content without identifier',
        secretKey: _secret,
      );
      expect(() => Article.parse(event), throwsA(isA<MissingTagException>()));
    });

    test('permissive mode flags missing d and yields empty articleId', () {
      final event = Event.from(
        kind: Article.kindArticle,
        tags: [],
        content: 'salvageable body',
        secretKey: _secret,
      );
      final data = Article.parse(event, permissive: true);
      expect(data.articleId, '');
      expect(data.missingTags, {'d'});
      expect(data.isComplete, isFalse);
      expect(data.content, 'salvageable body');
    });
  });

  group('Nip23.create', () {
    test('builds a kind-30023 article with the required d tag', () {
      final event = Article.create(
        articleId: 'my-post',
        content: '# Hello',
        secretKey: _secret,
        title: 'Hello',
        image: 'https://example.com/cover.png',
        summary: 'a summary',
        publishedAt: 1700000000,
        topics: ['nostr', 'dart'],
      );
      expect(event.kind, Article.kindArticle);
      expect(event.content, '# Hello');
      final dTag = event.tags.firstWhere((t) => t.isNotEmpty && t[0] == 'd');
      expect(dTag[1], 'my-post');
      final tTags =
          event.tags.where((t) => t.isNotEmpty && t[0] == 't').toList();
      expect(tTags.map((t) => t[1]), ['nostr', 'dart']);
    });

    test('draft flag flips kind to 30024', () {
      final event = Article.create(
        articleId: 'd',
        content: 'wip',
        secretKey: _secret,
        draft: true,
      );
      expect(event.kind, Article.kindDraft);
    });
  });
}
