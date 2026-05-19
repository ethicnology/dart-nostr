import 'package:nostr/nostr.dart';

/// Client Authentication — [NIP-42](https://github.com/nostr-protocol/nips/blob/master/42.md)
///
/// Relays may send `["AUTH", <challenge>]` at any point during a connection.
/// The client responds with a kind 22242 ephemeral event containing the
/// challenge and relay URL. The authenticated session is valid for the
/// remainder of the WebSocket connection.
class RelayAuth {
  /// Event kind for authentication.
  static const int kindAuth = 22242;

  /// Creates a kind 22242 authentication response event.
  ///
  /// [challenge] is the challenge string received from the relay.
  /// [relayUrl] is the WebSocket URL of the relay requesting auth.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  ///
  /// The relay verifies that:
  /// - kind is 22242
  /// - created_at is within ~10 minutes of current time
  /// - the challenge tag matches the one sent
  /// - the relay tag matches its own URL
  static Event create({
    required String challenge,
    required String relayUrl,
    required String secretKey,
  }) {
    return Event.from(
      kind: kindAuth,
      tags: [
        ["relay", relayUrl],
        ["challenge", challenge],
      ],
      content: '',
      secretKey: secretKey,
    );
  }

  /// Validates an authentication event per NIP-42 spec.
  ///
  /// Checks (in order):
  /// 1. Event id + Schnorr signature are valid for the claimed pubkey
  /// 2. kind is 22242
  /// 3. created_at is within ~10 minutes of current time
  /// 4. challenge tag matches
  /// 5. relay tag matches
  ///
  /// The signature check is defense in depth: NIP-42 doesn't list it in
  /// the relay's per-spec checks (NIP-01 covers signature for any event),
  /// but a relay that calls `validate` without independent verification
  /// would otherwise accept forged events. Mirrors NIP-98's pattern.
  static bool validate({
    required Event event,
    required String relayUrl,
    required String challenge,
  }) {
    if (!event.isValid()) return false;
    if (event.kind != kindAuth) return false;

    // Timestamp must be within ~10 minutes
    final now = currentUnixTimestampSeconds();
    const tenMinutes = 10 * 60;
    if ((event.createdAt - now).abs() > tenMinutes) return false;

    final eventRelay = findTagValue(event.tags, 'relay');
    if (eventRelay != relayUrl) return false;

    final eventChallenge = findTagValue(event.tags, 'challenge');
    if (eventChallenge != challenge) return false;

    return true;
  }
}

typedef Nip42 = RelayAuth;
