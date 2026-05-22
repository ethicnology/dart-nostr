import 'package:nostr/nostr.dart';

void main() {
  final root = Nip10.rootTag('event-root-id', 'wss://relay.example.com');
  final reply = Nip10.replyTag('event-reply-id', 'wss://relay.example.com');
  final thread = Thread(root: root, etags: [reply]);

  final tags = Nip10.toTags(thread);
  assert(tags[0][3] == 'root');
  assert(tags[1][3] == 'reply');

  final parsed = Nip10.parseTags(tags);
  assert(parsed.root.eventId == 'event-root-id');
  assert(parsed.etags[0].marker == 'reply');
  print('Root: ${parsed.root.eventId}');
}
