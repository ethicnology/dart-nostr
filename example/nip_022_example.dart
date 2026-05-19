import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // NIP-22 commenting on external content: uppercase `I` for the root
  // scope, lowercase `i` for the immediate parent (here root == parent
  // because we're commenting directly on the article).
  final event = Nip22.create(
    content: 'Great article!',
    secretKey: secretKey,
    rootTag: ['I', 'https://example.com/article'],
    rootKind: 'https',
    parentTag: ['i', 'https://example.com/article'],
    parentKind: 'https',
  );
  assert(event.kind == 1111);

  final comment = Nip22.parse(event);
  assert(comment.content == 'Great article!');
  print('Comment: ${comment.content}');
}
