// test/nip23_test.dart

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Nip23.parse', () {
    test('should parse a valid event map into an ArticleData', () {
      // Arrange
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

      // Assert
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
  });
}
