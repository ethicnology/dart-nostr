import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip1.encodeTextNote(
    content: 'Hello Nostr!',
    secretKey: secretKey,
    hashTags: ['nostr', 'dart'],
  );
  assert(event.kind == 1);

  final note = Nip1.decodeTextNote(event);
  assert(note.content == 'Hello Nostr!');
  assert(note.hashTags.contains('nostr'));
  print('Note: ${note.content}');
}
