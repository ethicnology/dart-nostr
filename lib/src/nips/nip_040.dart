import 'package:nostr/nostr.dart';

/// Expiration Timestamp — [NIP-40](https://github.com/nostr-protocol/nips/blob/master/40.md)
///
/// An `["expiration", "<unix-timestamp>"]` tag that signals when an event
/// SHOULD be considered expired by relays and clients.
///
/// Clients SHOULD ignore events that have expired. Relays SHOULD NOT send
/// expired events to clients and SHOULD drop expired events on publish.
///
/// **Warning:** events remain publicly accessible on relays — expiration
/// must not be relied upon for sensitive-content confidentiality.
class Expiration {
  /// Creates an expiration tag.
  ///
  /// [timestamp] is the unix timestamp (seconds) at which the event expires.
  static List<String> tag(int timestamp) =>
      ['expiration', timestamp.toString()];

  /// Extracts the expiration timestamp from [event], or `null` if absent.
  static int? findExpiration(Event event) {
    final value = findTagValue(event.tags, 'expiration');
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Returns `true` if [event] has an expiration tag and the timestamp
  /// is in the past.
  static bool isExpired(Event event) {
    final expiration = findExpiration(event);
    if (expiration == null) return false;
    return currentUnixTimestampSeconds() > expiration;
  }
}

typedef Nip40 = Expiration;
