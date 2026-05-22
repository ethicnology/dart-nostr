import 'package:nostr/nostr.dart';

void main() {
  const content =
      'Hello nostr:npub14f8usejl26twx0dhuxjh9cas7keav9vr0v8nvtwtrjqx3vycc76qqh9nsy! '
      'Check this note nostr:note1m99r7nwc0wdrkzldrqan96gklg5usqspq7z9696j6unf0ljnpxjspqfw99';

  final mentions = TextNoteReference.extractMentions(content);
  assert(mentions.length == 2);
  assert(mentions[0].prefix == Nip19Prefix.npub);
  assert(mentions[1].prefix == Nip19Prefix.note);
  print('Found ${mentions.length} mentions');
  for (final m in mentions) {
    print('  ${m.prefix.name}: ${m.uri}');
  }
}
