/// A Dart library for the Nostr protocol.
///
/// Provides event creation, signing, serialization, key management,
/// and implementations of commonly used NIPs.
library;

export 'src/close.dart';
export 'src/eose.dart';
export 'src/error.dart';
export 'src/event.dart';
export 'src/filter.dart';
export 'src/keys.dart';
export 'src/message.dart';
export 'src/nips/nip_001.dart';
export 'src/nips/nip_002.dart';
export 'src/nips/nip_005.dart';
export 'src/nips/nip_009.dart';
export 'src/nips/nip_010.dart';
export 'src/nips/nip_011.dart';
export 'src/nips/nip_013.dart';
export 'src/nips/nip_017.dart';
export 'src/nips/nip_018.dart';
export 'src/nips/nip_019.dart';
export 'src/nips/nip_020.dart';
export 'src/nips/nip_021.dart';
export 'src/nips/nip_022.dart';
export 'src/nips/nip_023.dart';
export 'src/nips/nip_025.dart';
export 'src/nips/nip_027.dart';
export 'src/nips/nip_028.dart';
export 'src/nips/nip_029.dart';
export 'src/nips/nip_032.dart';
export 'src/nips/nip_038.dart';
export 'src/nips/nip_040.dart';
export 'src/nips/nip_042.dart';
export 'src/nips/nip_044.dart';
// nip_044_utils.dart intentionally not exported. The low-level primitives
// (pad, unpad, chacha20, hkdf, calculateMac, etc.) are easy to misuse and
// should not be part of the public surface. Use `Encryption.encrypt` /
// `Encryption.decrypt` from `nip_044.dart` instead. Tests that need the
// primitives import the file path directly.
export 'src/nips/nip_046.dart';
export 'src/nips/nip_047.dart';
export 'src/nips/nip_051.dart';
export 'src/nips/nip_053.dart';
export 'src/nips/nip_057.dart';
export 'src/nips/nip_058.dart';
export 'src/nips/nip_059.dart';
export 'src/nips/nip_065.dart';
export 'src/nips/nip_072.dart';
export 'src/nips/nip_089.dart';
export 'src/nips/nip_094.dart';
export 'src/nips/nip_098.dart';
export 'src/request.dart';
export 'src/schnorr.dart';
export 'src/utils.dart';
