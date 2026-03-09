import 'package:nostr/nostr.dart';

void main() {
  final bits = Nip13.countLeadingZeroes(
    '000000000e9d97a1ab09fc381030b346cdd7a142ad57e6df0b46dc9bef6c7e2d',
  );
  assert(bits == 36);
  print('Leading zero bits: $bits (difficulty: 36)');

  assert(Nip13.countLeadingZeroes('00ff') == 8);
  assert(Nip13.countLeadingZeroes('f000') == 0);
}
