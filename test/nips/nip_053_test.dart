import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip053', () {
    test('decode live activity with all fields', () {
      final event = Event.partial(
        kind: 30311,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'live-stream-123'],
          ['title', 'My Live Stream'],
          ['summary', 'A great stream about Nostr development'],
          ['image', 'https://example.com/image.jpg'],
          ['streaming', 'https://stream.example.com/live.m3u8'],
          ['recording', 'https://stream.example.com/recording.mp4'],
          ['status', 'live'],
          ['starts', '1700000000'],
          ['ends', '1700100000'],
          ['current_participants', '42'],
          ['total_participants', '100'],
          ['t', 'nostr'],
          ['t', 'development'],
          ['p', 'host-pubkey-hex', 'wss://relay.example.com', 'Host'],
          ['p', 'speaker-pubkey-hex', '', 'Speaker'],
          ['p', 'participant-pubkey-hex', '', 'Participant'],
        ],
      );

      final activity = Nip53.parse(event);

      expect(activity.identifier, 'live-stream-123');
      expect(activity.title, 'My Live Stream');
      expect(activity.summary, 'A great stream about Nostr development');
      expect(activity.image, 'https://example.com/image.jpg');
      expect(activity.streaming, 'https://stream.example.com/live.m3u8');
      expect(activity.recording,
          'https://stream.example.com/recording.mp4');
      expect(activity.status, 'live');
      expect(activity.starts, 1700000000);
      expect(activity.ends, 1700100000);
      expect(activity.currentParticipants, 42);
      expect(activity.totalParticipants, 100);
      expect(activity.hashtags, ['nostr', 'development']);
      expect(activity.pubkey,
          'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233');
      expect(activity.createdAt, 1700000000);

      expect(activity.participants.length, 3);
      expect(activity.participants[0].pubkey, 'host-pubkey-hex');
      expect(activity.participants[0].relay, 'wss://relay.example.com');
      expect(activity.participants[0].role, 'Host');
      expect(activity.participants[1].pubkey, 'speaker-pubkey-hex');
      expect(activity.participants[1].relay, isNull);
      expect(activity.participants[1].role, 'Speaker');
      expect(activity.participants[2].pubkey, 'participant-pubkey-hex');
      expect(activity.participants[2].role, 'Participant');
    });

    test('decode live activity with minimal fields', () {
      final event = Event.partial(
        kind: 30311,
        pubkey:
            'aabbccdd00112233aabbccdd00112233aabbccdd00112233aabbccdd00112233',
        createdAt: 1700000000,
        tags: [
          ['d', 'minimal-stream'],
          ['status', 'planned'],
        ],
      );

      final activity = Nip53.parse(event);

      expect(activity.identifier, 'minimal-stream');
      expect(activity.title, isNull);
      expect(activity.summary, isNull);
      expect(activity.image, isNull);
      expect(activity.streaming, isNull);
      expect(activity.recording, isNull);
      expect(activity.status, 'planned');
      expect(activity.starts, isNull);
      expect(activity.ends, isNull);
      expect(activity.hashtags, isEmpty);
      expect(activity.participants, isEmpty);
    });

    test('decode throws InvalidKindException for wrong kind', () {
      final event = Event.partial();

      expect(
        () => Nip53.parse(event),
        throwsA(isA<InvalidKindException>()),
      );
    });

    test('decode throws MissingTagException for missing d tag', () {
      final event = Event.partial(
        kind: 30311,
      );

      expect(
        () => Nip53.parse(event),
        throwsA(isA<MissingTagException>()),
      );
    });

    test('LiveParticipant equality', () {
      const a = LiveParticipant(pubkey: 'abc', relay: 'wss://r', role: 'Host');
      const b = LiveParticipant(pubkey: 'abc', relay: 'wss://r', role: 'Host');
      const c =
          LiveParticipant(pubkey: 'abc', relay: 'wss://r', role: 'Speaker');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('encode live activity', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip53.create(
        identifier: 'my-stream',
        secretKey: secretKey,
        title: 'Test Stream',
        status: 'live',
        streaming: 'https://stream.example.com/live.m3u8',
        participants: [
          const LiveParticipant(pubkey: 'host-pk', role: 'Host'),
        ],
        hashtags: ['nostr'],
      );
      expect(event.kind, 30311);
      expect(event.tags[0], ['d', 'my-stream']);
      expect(event.tags[1], ['title', 'Test Stream']);
    });

    test('encode and decode round-trip', () {
      const secretKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      final event = Nip53.create(
        identifier: 'roundtrip',
        secretKey: secretKey,
        title: 'My Stream',
        status: 'planned',
        starts: 1700000000,
      );
      final activity = Nip53.parse(event);
      expect(activity.identifier, 'roundtrip');
      expect(activity.title, 'My Stream');
      expect(activity.status, 'planned');
      expect(activity.starts, 1700000000);
    });

    test('decode real-world kind 30311 live activity from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['30311'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final activity = Nip53.parse(event);
      expect(activity.identifier, isNotEmpty);
      expect(activity.pubkey, event.pubkey);
    });

    test('typedef alias works', () {
      expect(LiveActivities.kindLiveEvent, 30311);
    });
  });
}
