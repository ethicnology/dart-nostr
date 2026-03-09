import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip051', () {
    test('createCategorizedPeople', () async {
      final Keys user = Keys.generate();
      const Contact publicFriend = Contact(
        "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1",
        'wss://example.com',
        'alias',
      );
      const Contact privateFriend = Contact(
        "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181",
        'wss://example2.com',
        'bob',
      );
      final Event event = await Nip51.createCategorizedPeople(
          "friends", [publicFriend], [privateFriend], user.secret, user.public);

      final UserList list = await Nip51.getLists(event, user.secret);
      expect(list.contacts[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(list.contacts[0].petName, 'alias');
      expect(list.contacts[1].pubkey,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(list.contacts[1].petName, 'bob');
    });

    test('createCategorizedBookmarks', () async {
      final Keys user = Keys.generate();
      const String bookmark =
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1';
      const String encryptedBookmark =
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181';
      final Event event = await Nip51.createCategorizedBookmarks("bookmarks",
          [bookmark], [encryptedBookmark], user.secret, user.public);

      final UserList list = await Nip51.getLists(event, user.secret);
      expect(list.bookmarks[0],
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(list.bookmarks[1],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });

    test('createMutePeople', () async {
      final Keys user = Keys.generate();
      const Contact publicFriend = Contact(
        "2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1",
        'wss://example.com',
        'alias',
      );
      const Contact privateFriend = Contact(
        "0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181",
        'wss://example2.com',
        'bob',
      );
      final Event event = await Nip51.createMutePeople(
          [publicFriend], [privateFriend], user.secret, user.public);
      final UserList list = await Nip51.getLists(event, user.secret);
      expect(list.contacts[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(list.contacts[0].petName, 'alias');
      expect(list.contacts[1].pubkey,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(list.contacts[1].petName, 'bob');
    });

    test('createPinEvent', () async {
      final Keys user = Keys.generate();
      const String bookmark =
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1';
      const String encryptedBookmark =
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181';
      final Event event = await Nip51.createPinEvent(
          [bookmark], [encryptedBookmark], user.secret, user.public);

      final UserList list = await Nip51.getLists(event, user.secret);
      expect(list.bookmarks[0],
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(list.bookmarks[1],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });

    test('real-world kind 10002 relay list parses as Event', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['10002'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);
      expect(event.kind, 10002);
      expect(event.pubkey, isNotEmpty);
    });
  });
}
