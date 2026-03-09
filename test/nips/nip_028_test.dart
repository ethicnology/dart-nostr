import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";

void main() {
  group('nip028', () {
    test('createChannel and decode', () {
      final event = Nip28.createChannel(
        name: 'name',
        about: 'about',
        picture: 'http://image.jpg',
        additional: {'badges': 'abc123'},
        secretKey: secretKey,
      );
      final channel = Nip28.getChannelCreation(event);
      expect(channel.name, 'name');
      expect(channel.about, 'about');
      expect(channel.picture, 'http://image.jpg');
      expect(channel.additional['badges'], 'abc123');
      expect(channel.owner, event.pubkey);
    });

    test('setMetadata includes root marker in e tag', () {
      final event = Nip28.setChannelMetaData(
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

      final channel = Nip28.getChannelMetadata(event);
      expect(channel.channelId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(channel.relay, 'wss://example.com');
    });

    test('sendChannelMessage', () {
      final event = Nip28.sendChannelMessage(
        channelId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        content: 'content',
        secretKey: secretKey,
      );
      final msg = Nip28.getChannelMessage(event);
      expect(msg.channelId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(msg.content, 'content');
    });

    test('sendChannelMessage with replies', () {
      const eTag = ETag(
          eventId: '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181',
          relayURL: 'wss://example.com',
          marker: 'reply');
      const pTag = PTag(
          pubkey: '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1',
          relayURL: 'wss://example.com');
      final event = Nip28.sendChannelMessage(
        channelId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        content: 'reply',
        secretKey: secretKey,
        etags: [eTag],
        ptags: [pTag],
      );
      final msg = Nip28.getChannelMessage(event);
      expect(msg.thread.etags[0].eventId,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(msg.thread.ptags[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
    });

    test('hideChannelMessage', () {
      final event = Nip28.hideChannelMessage(
        messageId: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        reason: 'spam',
        secretKey: secretKey,
      );
      final hidden = Nip28.getMessageHidden(event);
      expect(hidden.messageId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(hidden.reason, 'spam');
    });

    test('muteUser', () {
      final event = Nip28.muteUser(
        pubkey: 'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
        reason: 'harassment',
        secretKey: secretKey,
      );
      final muted = Nip28.getUserMuted(event);
      expect(muted.userPubkey,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
      expect(muted.reason, 'harassment');
    });

    test('decode real-world kind 42 channel message from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['42'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final msg = Nip28.getChannelMessage(event);
      expect(msg.channelId, isNotEmpty);
      expect(msg.content, isNotEmpty);
      expect(msg.pubkey, event.pubkey);
    });

    test('decode real-world kind 43 hidden message from nos.lol', () {
      final fixtures = json.decode(
          File('test/fixtures/samples_by_kind.json').readAsStringSync());
      final eventMap = fixtures['43'] as Map<String, dynamic>;
      final event = Event.fromMap(eventMap);

      final hidden = Nip28.getMessageHidden(event);
      expect(hidden.pubkey, event.pubkey);
    });

    test('typedef PublicChat works', () {
      final event = PublicChat.createChannel(
        name: 'test',
        about: 'test',
        picture: '',
        secretKey: secretKey,
      );
      expect(event.kind, 40);
    });
  });
}
