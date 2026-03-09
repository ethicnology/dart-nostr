import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip032', () {
    test('decode label event with namespace and targets', () {
      final event = Event.partial(
        kind: 1985,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['L', 'social.ontolo.categories'],
          ['l', 'Technology', 'social.ontolo.categories'],
          ['l', 'Science', 'social.ontolo.categories'],
          ['e', 'target-event-id', 'wss://relay.example.com'],
        ],
      );

      final label = Nip32.decode(event);

      expect(label.namespaces, ['social.ontolo.categories']);
      expect(label.labels.length, 2);
      expect(label.labels[0].value, 'Technology');
      expect(label.labels[0].namespace, 'social.ontolo.categories');
      expect(label.labels[1].value, 'Science');
      expect(label.labels[1].namespace, 'social.ontolo.categories');
      expect(label.targetEvents, ['target-event-id']);
      expect(label.content, '');
      expect(label.pubkey,
          'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233');
    });

    test('decode label with multiple namespaces and target types', () {
      final event = Event.partial(
        kind: 1985,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['L', 'com.example.rating'],
          ['L', 'com.example.topic'],
          ['l', '5-star', 'com.example.rating'],
          ['l', 'Dart', 'com.example.topic'],
          ['p', 'target-pubkey-hex'],
          ['r', 'wss://relay.example.com'],
          ['t', 'nostr'],
          ['a', '30023:author:article-id'],
        ],
        content: 'review',
      );

      final label = Nip32.decode(event);

      expect(label.namespaces, ['com.example.rating', 'com.example.topic']);
      expect(label.labels.length, 2);
      expect(label.targetPubkeys, ['target-pubkey-hex']);
      expect(label.targetUrls, ['wss://relay.example.com']);
      expect(label.targetTopics, ['nostr']);
      expect(label.targetCoordinates, ['30023:author:article-id']);
      expect(label.content, 'review');
    });

    test('decode label without namespace (implied ugc)', () {
      final event = Event.partial(
        kind: 1985,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['l', 'spam'],
          ['e', 'some-event-id'],
        ],
      );

      final label = Nip32.decode(event);

      expect(label.namespaces, isEmpty);
      expect(label.labels.length, 1);
      expect(label.labels[0].value, 'spam');
      expect(label.labels[0].namespace, isNull);
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip32.decode(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('LabelEntry equality', () {
      const a = LabelEntry(value: 'foo', namespace: 'bar');
      const b = LabelEntry(value: 'foo', namespace: 'bar');
      const c = LabelEntry(value: 'foo', namespace: 'baz');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('encode label event', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip32.encode(
        labels: [
          const LabelEntry(value: 'Technology', namespace: 'social.ontolo.categories'),
          const LabelEntry(value: 'spam'),
        ],
        targetEvents: ['abc123'],
        secretKey: secretKey,
        content: 'review note',
      );
      expect(event.kind, 1985);
      expect(event.tags[0], ['L', 'social.ontolo.categories']);
      expect(event.tags[1], ['l', 'Technology', 'social.ontolo.categories']);
      expect(event.tags[2], ['l', 'spam']);
      expect(event.tags[3], ['e', 'abc123']);
      expect(event.content, 'review note');
    });

    test('encode and decode round-trip', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip32.encode(
        labels: [
          const LabelEntry(value: 'en', namespace: 'ISO-639-1'),
        ],
        targetPubkeys: ['def456'],
        secretKey: secretKey,
      );
      final label = Nip32.decode(event);
      expect(label.namespaces, ['ISO-639-1']);
      expect(label.labels[0].value, 'en');
      expect(label.labels[0].namespace, 'ISO-639-1');
      expect(label.targetPubkeys, ['def456']);
    });

    test('decode real-world kind 1985 label from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['1985'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final label = Nip32.decode(event);
      expect(label.namespaces, contains('ISO-639-1'));
      expect(label.labels.length, 1);
      expect(label.labels[0].value, 'en');
      expect(label.labels[0].namespace, 'ISO-639-1');
      expect(label.targetEvents, isNotEmpty);
      expect(label.pubkey, event.pubkey);
    });

    test('typedef alias works', () {
      expect(Labels.kindLabel, 1985);
    });
  });
}
