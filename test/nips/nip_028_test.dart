import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";

void main() {
  group('nip028', () {
    test('channel and parseChannel', () {
      final event = PublicChat.channel(
        name: 'name',
        about: 'about',
        picture: 'http://image.jpg',
        additional: {'badges': 'abc123'},
        secretKey: secretKey,
      );
      final channel = PublicChat.parseChannel(event);
      expect(channel.name, 'name');
      expect(channel.about, 'about');
      expect(channel.picture, 'http://image.jpg');
      expect(channel.additional['badges'], 'abc123');
      expect(channel.owner, event.pubkey);
    });

    test('parseChannel handles spec-defined relays array', () {
      // Per NIP-28, kind-40 content may include a `relays` array alongside
      // name/about/picture. Pre-fix this crashed with TypeError on the
      // Map<String, String>.from cast.
      const json ='{"name":"hi","about":"","picture":"","relays":["wss://a","wss://b"]}';
      final event = Event.from(
        kind: 40,
        tags: [],
        content: json,
        secretKey: secretKey,
      );
      final channel = PublicChat.parseChannel(event);
      expect(channel.name, 'hi');
      expect(channel.relays, ['wss://a', 'wss://b']);
      expect(channel.additional, isEmpty);
    });

    test('channel emits relays array when provided', () {
      final event = PublicChat.channel(
        name: 'n',
        about: '',
        picture: '',
        relays: ['wss://x'],
        secretKey: secretKey,
      );
      final channel = PublicChat.parseChannel(event);
      expect(channel.relays, ['wss://x']);
    });

    test('parseChannel silently drops non-string additional values', () {
      // Forward-compat: a future client may add a structured field; we
      // keep only string-typed fields in `additional` and don't crash.
      const json ='{"name":"x","about":"","picture":"","verified":true,"score":42}';
      final event = Event.from(
        kind: 40,
        tags: [],
        content: json,
        secretKey: secretKey,
      );
      final channel = PublicChat.parseChannel(event);
      expect(channel.name, 'x');
      expect(channel.additional, isEmpty);
    });

    test('channelMetadata includes root marker in e tag', () {
      final event = PublicChat.channelMetadata(
        name: 'name',
        about: 'about',
        picture: 'http://image.jpg',
        channelId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        relayURL: 'wss://example.com',
        secretKey: secretKey,
      );
      // Per spec, e tag should have "root" marker
      expect(event.tags[0], [
        'e',
        'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        'wss://example.com',
        'root'
      ]);

      final channel = PublicChat.parseMetadata(event);
      expect(channel.channelId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(channel.relay, 'wss://example.com');
    });

    test('channelMessage', () {
      final event = PublicChat.channelMessage(
        channelId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        content: 'content',
        secretKey: secretKey,
      );
      final msg = PublicChat.parseMessage(event);
      expect(msg.channelId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(msg.content, 'content');
    });

    test('channelMessage with replies', () {
      const eTag = ETag(
          eventId: '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181',
          relayURL: 'wss://example.com',
          marker: 'reply');
      const pTag = PTag(
          pubkey: '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1',
          relayURL: 'wss://example.com');
      final event = PublicChat.channelMessage(
        channelId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        content: 'reply',
        secretKey: secretKey,
        etags: [eTag],
        ptags: [pTag],
      );
      final msg = PublicChat.parseMessage(event);
      expect(msg.thread.etags[0].eventId,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(msg.thread.ptags[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
    });

    test('hideMessage', () {
      final event = PublicChat.hideMessage(
        messageId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        reason: 'spam',
        secretKey: secretKey,
      );
      final hidden = PublicChat.parseHidden(event);
      expect(hidden.messageId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(hidden.reason, 'spam');
    });

    test('muteUser', () {
      final event = PublicChat.muteUser(
        pubkey: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        reason: 'harassment',
        secretKey: secretKey,
      );
      final muted = PublicChat.parseMuted(event);
      expect(muted.userPubkey,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(muted.reason, 'harassment');
    });

    test('decode real-world kind 42 channel message from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['42'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final msg = PublicChat.parseMessage(event);
      expect(msg.channelId, isNotEmpty);
      expect(msg.content, isNotEmpty);
      expect(msg.pubkey, event.pubkey);
    });

    test('decode real-world kind 43 hidden message from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['43'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final hidden = PublicChat.parseHidden(event);
      expect(hidden.pubkey, event.pubkey);
    });

    test('typedef Nip28 works', () {
      final event = Nip28.channel(
        name: 'test',
        about: 'test',
        picture: '',
        secretKey: secretKey,
      );
      expect(event.kind, 40);
    });
  });
}
