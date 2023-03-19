import 'dart:io';

import 'package:nostr/src/nips/nip_04.dart';

void main() async {
  final userPrivateKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  // my public key : 981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b
  final String to =
      '0000a0fa65fcccd99e6fd32fc7870339af40f4a94703ea30999fc5c091daa222';
  String msg = getNip4Message(userPrivateKey, to, 'hello world');

  WebSocket webSocket = await WebSocket.connect(
    'wss://nostr-pub.wellorder.net', // or any nostr relay
  );

  webSocket.add(msg);

  await Future.delayed(Duration(seconds: 1));
  webSocket.listen((event) {
    print('Received event: $event');
  });

  // Close the WebSocket connection
  await webSocket.close();
}
