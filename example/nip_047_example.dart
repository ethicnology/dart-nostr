import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const walletPubkey =
      '32e1827635450ebb3c5a7d12c1f8e7b2b514439ac10a67eef3d9fd9c5c68e245';

  // Decode wallet info (kind 13194)
  final infoEvent = Event.from(
    kind: 13194,
    tags: [],
    content: 'pay_invoice get_balance make_invoice',
    secretKey: secretKey,
  );
  final info = Nip47.parseInfo(infoEvent);
  assert(info.capabilities.contains('pay_invoice'));
  print('Wallet capabilities: ${info.capabilities}');

  // Encode a request (kind 23194)
  final request = Nip47.request(
    encryptedContent: 'encrypted-payload',
    walletServicePubkey: walletPubkey,
    secretKey: secretKey,
  );
  assert(request.kind == 23194);
}
