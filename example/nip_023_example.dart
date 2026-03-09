import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Encode a long-form article (kind 30023)
  final event = Nip23.create(
    articleId: 'my-first-article',
    content: '# Hello World\n\nThis is my first long-form article on Nostr.',
    secretKey: secretKey,
    title: 'Hello World',
    summary: 'A brief introduction',
    topics: ['nostr', 'introduction'],
  );
  assert(event.kind == 30023);
  assert(findTagValue(event.tags, 'd') == 'my-first-article');
  assert(findTagValue(event.tags, 'title') == 'Hello World');

  // Decode an article
  final article = Nip23.parse(event);
  assert(article.articleId == 'my-first-article');
  assert(article.title == 'Hello World');
  assert(article.topics.contains('nostr'));
  assert(article.content.contains('Hello World'));

  // Encode a draft (kind 30024)
  final draft = Nip23.create(
    articleId: 'wip-article',
    content: 'Work in progress...',
    secretKey: secretKey,
    draft: true,
  );
  assert(draft.kind == 30024);
}
