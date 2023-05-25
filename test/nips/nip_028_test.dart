import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('nip028', () {
    test('createChannel', () {
      String privkey =
          "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
      Event event = Nip28.createChannel(
          'name',
          'about',
          'http://image.jpg',
          {
            'badges':
                '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181'
          },
          privkey);
      Channel channel = Nip28.getChannelCreation(event);
      expect(channel.picture, 'http://image.jpg');
      expect(channel.additional['badges'],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });

    test('setMetadata', () {
      String privkey =
          "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
      Event event = Nip28.setChannelMetaData(
          'name',
          'about',
          'http://image.jpg',
          {
            'badges':
                '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181'
          },
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9',
          'wss://example.com',
          privkey);
      Channel channel = Nip28.getChannelMetadata(event);
      expect(channel.channelId,
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9");
      expect(channel.picture, 'http://image.jpg');
      expect(channel.additional['badges'],
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
    });

    test('sendChannelMessage', () {
      String privkey =
          "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
      Event event = Nip28.sendChannelMessage(
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9",
          'content',
          privkey);
      ChannelMessage channelMessage = Nip28.getChannelMessage(event);

      expect(channelMessage.channelId,
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9");
      expect(channelMessage.content, 'content');

      /// reply & p
      ETag eTag = ETag(
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181',
          "wss://example.com",
          'reply');
      PTag pTag = PTag(
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1',
          "wss://example.com");
      Event event2 = Nip28.sendChannelMessage(
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9",
          'content',
          privkey,
          etags: [eTag],
          ptags: [pTag]);
      ChannelMessage channelMessage2 = Nip28.getChannelMessage(event2);

      expect(channelMessage2.channelId,
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9");
      expect(channelMessage2.content, 'content');
      expect(channelMessage2.thread.etags[0].eventId,
          '0f76c800a7ea76b83a3ae87de94c6046b98311bda8885cedd8420885b50de181');
      expect(channelMessage2.thread.ptags[0].pubkey,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
    });

    test('hideChannelMessage', () {
      String privkey =
          "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
      Event event = Nip28.hideChannelMessage(
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9",
          "reason",
          privkey);
      ChannelMessageHidden channelMessageHidden = Nip28.getMessageHidden(event);

      expect(channelMessageHidden.operator,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(channelMessageHidden.messageId,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
    });

    test('muteUser', () {
      String privkey =
          "826ef0e93c1278bd89945377fadb6b6b51d9eedf74ecdb64a96f1897bb670be8";
      Event event = Nip28.muteUser(
          "b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9",
          "reason",
          privkey);
      ChannelUserMuted channelUserMuted = Nip28.getUserMuted(event);

      expect(channelUserMuted.operator,
          '2d38a56c4303bc722370c50c86fc8dd3327f06a8fe59b3ff3d670738d71dd1e1');
      expect(channelUserMuted.userPubkey,
          'b83a3326b63470df6a86dca9456184e09ea1a237b2b41b36e0af740badf329e9');
    });
  });
}
