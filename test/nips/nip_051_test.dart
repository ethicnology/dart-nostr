import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip051', () {
    test('createCategorizedPeople', () {
      final Keys user = Keys.generate();
      final People publicFriend = People(
          "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1",
          'wss://example.com',
          'alias',
          "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181");
      final People privateFriend = People(
          "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181",
          'wss://example2.com',
          'bob',
          "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1");
      final Event event = Nip51.createCategorizedPeople(
          "friends", [publicFriend], [privateFriend], user.secret, user.public);

      final Lists lists = Nip51.getLists(event, user.secret);
      expect(lists.people[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(lists.people[0].petName, 'alias');
      expect(lists.people[1].pubkey,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(lists.people[1].petName, 'bob');
    });

    test('createCategorizedBookmarks', () {
      final Keys user = Keys.generate();
      const String bookmark =
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1';
      const String encryptedBookmark =
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181';
      final Event event = Nip51.createCategorizedBookmarks("bookmarks",
          [bookmark], [encryptedBookmark], user.secret, user.public);

      final Lists lists = Nip51.getLists(event, user.secret);
      expect(lists.bookmarks[0],
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(lists.bookmarks[1],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });

    test('createMutePeople', () {
      final Keys user = Keys.generate();
      final People publicFriend = People(
          "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1",
          'wss://example.com',
          'alias',
          "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181");
      final People privateFriend = People(
          "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181",
          'wss://example2.com',
          'bob',
          "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1");
      final Event event = Nip51.createMutePeople(
          [publicFriend], [privateFriend], user.secret, user.public);
      final Lists lists = Nip51.getLists(event, user.secret);
      expect(lists.people[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(lists.people[0].petName, 'alias');
      expect(lists.people[1].pubkey,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(lists.people[1].petName, 'bob');
    });

    test('createPinEvent', () {
      final Keys user = Keys.generate();
      const String bookmark =
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1';
      const String encryptedBookmark =
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181';
      final Event event = Nip51.createPinEvent(
          [bookmark], [encryptedBookmark], user.secret, user.public);

      final Lists lists = Nip51.getLists(event, user.secret);
      expect(lists.bookmarks[0],
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(lists.bookmarks[1],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });
  });
}
