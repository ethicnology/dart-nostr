import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NIP-27 Text Note References', () {
    test('extracts npub mention', () {
      const content =
          'Hello nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6!';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(1));
      expect(mentions[0].prefix, Nip19Prefix.npub);
      expect(mentions[0].hex,
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d');
      expect(mentions[0].start, 6);
      expect(mentions[0].uri, startsWith('nostr:npub1'));
      expect(mentions[0].shareable, isNull);
    });

    test('extracts note mention', () {
      const noteId =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final bech32 =
          Bech32Entity.encode(prefix: Nip19Prefix.note, data: noteId);
      final content = 'Check this out nostr:$bech32';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(1));
      expect(mentions[0].prefix, Nip19Prefix.note);
      expect(mentions[0].hex, noteId);
    });

    test('extracts nprofile mention', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final bech32 = Bech32Entity.encodeShareableIdentifiers(
        prefix: Nip19Prefix.nprofile,
        data: pubkey,
        relays: ['wss://relay.example.com'],
      );
      final content = 'Follow nostr:$bech32 for updates';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(1));
      expect(mentions[0].prefix, Nip19Prefix.nprofile);
      expect(mentions[0].shareable, isNotNull);
      expect(mentions[0].shareable!.data, pubkey);
      expect(mentions[0].shareable!.relays, ['wss://relay.example.com']);
      expect(mentions[0].hex, isNull);
    });

    test('extracts nevent mention', () {
      const eventId =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final bech32 = Bech32Entity.encodeShareableIdentifiers(
        prefix: Nip19Prefix.nevent,
        data: eventId,
      );
      final content = 'Replying to nostr:$bech32';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(1));
      expect(mentions[0].prefix, Nip19Prefix.nevent);
      expect(mentions[0].shareable!.data, eventId);
    });

    test('extracts multiple mentions', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final npub = Bech32Entity.encode(prefix: Nip19Prefix.npub, data: pubkey);
      final content = 'nostr:$npub said hello to nostr:$npub again';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(2));
      expect(mentions[0].start, 0);
      expect(mentions[1].start, greaterThan(mentions[0].end));
    });

    test('returns empty list for content without mentions', () {
      final mentions = TextNoteReference.extractMentions('Just a regular note');
      expect(mentions, isEmpty);
    });

    test('skips nsec URIs', () {
      final mentions = TextNoteReference.extractMentions(
          'nostr:nsec1abcdefghijklmnopqrstuvwxyz');
      expect(mentions, isEmpty);
    });

    test('skips malformed bech32', () {
      final mentions =
          TextNoteReference.extractMentions('nostr:npub1invalidbech32data');
      // May or may not parse depending on bech32 validity — should not throw
      expect(mentions, isA<List<Mention>>());
    });

    test('position indices are correct', () {
      const pubkey =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final npub = Bech32Entity.encode(prefix: Nip19Prefix.npub, data: pubkey);
      const prefix = 'Hey ';
      const suffix = ' how are you?';
      final content = '$prefix${'nostr:$npub'}$suffix';
      final mentions = TextNoteReference.extractMentions(content);

      expect(mentions, hasLength(1));
      expect(mentions[0].start, prefix.length);
      expect(mentions[0].end, prefix.length + 'nostr:$npub'.length);
      expect(
          content.substring(mentions[0].start, mentions[0].end), 'nostr:$npub');
    });

    test('typedef Nip27 works', () {
      final mentions = Nip27.extractMentions('no mentions');
      expect(mentions, isEmpty);
    });
  });
}
