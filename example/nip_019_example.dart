import 'package:nostr/nostr.dart';

void main() {
  const hex =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final nsec = Nip19.encode(prefix: Nip19Prefix.nsec, data: hex);
  print('nsec: $nsec');

  final decoded = Nip19.decode(payload: nsec);
  assert(decoded.prefix == Nip19Prefix.nsec);
  assert(decoded.data == hex);

  final keys = Keys(hex);
  final npub = Nip19.encode(prefix: Nip19Prefix.npub, data: keys.public);
  print('npub: $npub');

  // Keys also provide nsec/npub directly
  assert(keys.nsec == nsec);
  assert(keys.npub == npub);
}
