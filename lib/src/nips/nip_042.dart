import 'package:nostr/nostr.dart';

/// Client Authentication — [NIP-42](https://github.com/nostr-protocol/nips/blob/master/42.md)
///
/// Relays may send `["AUTH", <challenge>]` at any point during a connection.
/// The client responds with a kind 22242 ephemeral event containing the
/// challenge and relay URL. The authenticated session is valid for the
/// remainder of the WebSocket connection.
class Nip42 {
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
  static Event encode({
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

  /// Validates an authentication event against the expected relay URL
  /// and challenge string.
  ///
  /// Returns `true` if the event is a valid kind 22242 with matching
  /// `relay` and `challenge` tags.
  static bool validate({
    required Event event,
    required String relayUrl,
    required String challenge,
  }) {
    if (event.kind != kindAuth) return false;

    final eventRelay = findTagValue(event.tags, 'relay');
    if (eventRelay != relayUrl) return false;

    final eventChallenge = findTagValue(event.tags, 'challenge');
    if (eventChallenge != challenge) return false;

    return true;
  }
}

typedef Auth = Nip42;
