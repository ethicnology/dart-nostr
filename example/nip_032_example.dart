import 'package:nostr/nostr.dart';

void main() {
  const secretKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

  final event = Nip32.create(
    labels: [
      const LabelEntry(value: 'IT', namespace: 'ugc'),
      const LabelEntry(value: 'bitcoin', namespace: 'ugc'),
    ],
    secretKey: secretKey,
    targetEvents: ['abc123'],
  );
  assert(event.kind == 1985);

  final label = Nip32.parse(event);
  assert(label.namespaces.contains('ugc'));
  assert(label.labels.length == 2);
  print('Labels: ${label.labels.map((l) => l.value).join(', ')}');
}
