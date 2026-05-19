import 'package:nostr/nostr.dart';

Future<void> main() async {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  final pubkey = Keys(secretKey).public;

  final event = await Nip51.mutePeople(
    [const Contact('pubkey-to-mute', '', '')],
    [],
    secretKey,
    pubkey,
  );
  assert(event.kind == 10000);

  final userList = await Nip51.parse(event, secretKey: secretKey);
  assert(userList.identifier == 'Mute');
  assert(userList.contacts.length == 1);
  print('Mute list: ${userList.contacts.length} contacts');
}
