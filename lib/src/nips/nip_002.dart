import 'package:nostr/nostr.dart';

/// Follow list and petnames — [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md)
///
/// A kind 3 event with a list of p tags representing the followed profiles.
class Nip2 {
  /// Returns the profiles from a follow list event (kind=3).
  ///
  /// Throws [InvalidKindException] if the event kind is not 3.
  static List<Profile> decode(Event event) {
    if (event.kind == 3) {
      return toProfiles(event.tags);
    }
    throw InvalidKindException(event.kind, [3]);
  }

  /// Returns profiles from event.tags.
  static List<Profile> toProfiles(List<List<String>> tags) {
    final List<Profile> result = [];
    for (final tag in tags) {
      if (tag[0] == "p") result.add(Profile(tag[1], tag[2], tag[3]));
    }
    return result;
  }

  /// Returns tags from profiles list.
  static List<List<String>> toTags(List<Profile> profiles) {
    final List<List<String>> result = [];
    for (final profile in profiles) {
      result.add(["p", profile.pubkey, profile.relay, profile.petname]);
    }
    return result;
  }
}

/// A profile entry in a follow list (NIP-02).
///
/// Tag format: ["p", "32-bytes hex key", "relay URL", "petname"]
class Profile {
  /// 32-bytes hex-encoded public key of the profile.
  String pubkey;

  /// A relay URL where events from that key can be found (can be empty).
  String relay;

  /// A local name ("petname") for that profile (can be empty).
  String petname;

  /// Creates a [Profile] with the given [pubkey], [relay], and [petname].
  Profile(this.pubkey, this.relay, this.petname);
}

typedef FollowList = Nip2;
