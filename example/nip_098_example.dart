import 'dart:convert';

import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  // Create HTTP auth event for a GET request
  final event = HttpAuth.create(
    url: 'https://api.example.com/resource',
    method: 'GET',
    secretKey: secretKey,
  );
  assert(event.kind == 27235);

  // Encode as Authorization header
  final header = HttpAuth.toAuthHeader(event);
  assert(header.startsWith('Nostr '));
  print('Authorization: $header');

  // Server-side: decode and parse
  final decoded = HttpAuth.fromAuthHeader(header);
  final data = HttpAuth.parse(decoded);
  print('URL: ${data.url}');
  print('Method: ${data.method}');
  print('Pubkey: ${data.pubkey}');

  // POST with payload hash
  final body = utf8.encode('{"amount": 21000}');
  final hash = HttpAuth.payloadHash(body);
  final postEvent = HttpAuth.create(
    url: 'https://api.example.com/pay',
    method: 'POST',
    secretKey: secretKey,
    payload: hash,
  );
  assert(findTagValue(postEvent.tags, 'payload') == hash);
  print('Payload hash: $hash');
}
