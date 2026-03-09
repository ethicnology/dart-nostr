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
      if (tag[0] == "p" && tag.length >= 2) {
        result.add(Profile(
          pubkey: tag[1],
          relay: tag.length > 2 ? tag[2] : '',
          petname: tag.length > 3 ? tag[3] : '',
        ));
      }
    }
    return result;
  }

  /// Creates a kind-3 follow list event from a list of [Profile]s.
  ///
  /// [profiles] are the followed profiles.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [content] is optional (some clients store relay JSON here).
  static Event encode({
    required List<Profile> profiles,
    required String secretKey,
    String content = '',
  }) {
    return Event.from(
      kind: 3,
      tags: toTags(profiles),
      content: content,
      secretKey: secretKey,
    );
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
  final String pubkey;

  /// A relay URL where events from that key can be found (can be empty).
  final String relay;

  /// A local name ("petname") for that profile (can be empty).
  final String petname;

  /// Creates a [Profile] with the given fields.
  const Profile({
    required this.pubkey,
    this.relay = '',
    this.petname = '',
  });
}

typedef FollowList = Nip2;
