import 'package:nostr/nostr.dart';

void main() {
  const npub =
      'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';

  final uri = Nip21.encode(npub);
  assert(uri == 'nostr:$npub');
  print('URI: $uri');

  final decoded = Nip21.decode(uri);
  assert(decoded == npub);
  print('Decoded: $decoded');
}
