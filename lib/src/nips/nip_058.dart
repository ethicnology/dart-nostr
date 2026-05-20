import 'package:nostr/nostr.dart';

/// Badges — [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md)
///
/// Three event kinds for creating, awarding, and displaying badges:
/// - Kind 30009: Badge definition (addressable, updatable)
/// - Kind 8: Badge award (immutable)
/// - Kind 10008: Profile badges (user-curated display) — current spec
/// - Kind 30008: Profile badges (legacy, used by clients before the
///   10008 migration). [parseProfileBadges] accepts both for backward
///   compatibility but [profileBadges] only emits 10008.
class Badge {
  /// Event kind for badge definitions.
  static const int kindDefinition = 30009;

  /// Event kind for badge awards.
  static const int kindAward = 8;

  /// Event kind for profile badges (current spec).
  static const int kindProfileBadges = 10008;

  /// Legacy kind for profile badges (with `d=profile_badges`). Kept for
  /// reading old events. Newer clients use [kindProfileBadges] (10008).
  static const int kindProfileBadgesLegacy = 30008;

  /// Creates a kind-30009 badge definition event.
  ///
  /// [badgeId] is the unique identifier (`d` tag), e.g. `"bravery"`.
  /// [secretKey] is the hex-encoded secret key.
  /// [name], [description], [image], [imageSize] are optional metadata.
  /// [thumbnails] is a list of (url, size?) pairs where size is `"WxH"`.
  static Event definition({
    required String badgeId,
    required String secretKey,
    String? name,
    String? description,
    String? image,
    String? imageSize,
    List<BadgeImage> thumbnails = const [],
  }) {
    final tags = <List<String>>[
      ['d', badgeId],
    ];

    if (name != null) tags.add(['name', name]);
    if (description != null) tags.add(['description', description]);
    if (image != null) {
      tags.add(imageSize != null ? ['image', image, imageSize] : ['image', image]);
    }
    for (final thumb in thumbnails) {
      tags.add(thumb.size != null
          ? ['thumb', thumb.url, thumb.size!]
          : ['thumb', thumb.url]);
    }

    return Event.from(
      kind: kindDefinition,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Creates a kind-8 badge award event.
  ///
  /// [badgeDefinition] must be a kind-30009 event with a `d` tag.
  /// [awardees] is a non-empty list of pubkeys (with optional relay URL)
  /// to award.
  ///
  /// Throws [InvalidKindException] if [badgeDefinition] is not kind 30009.
  /// Throws [MissingTagException] if [badgeDefinition] has no `d` tag.
  /// Throws [NostrException] if [awardees] is empty (spec MUST ≥1 `p` tag).
  static Event award({
    required Event badgeDefinition,
    required List<({String pubkey, String? relay})> awardees,
    required String secretKey,
  }) {
    if (badgeDefinition.kind != kindDefinition) {
      throw InvalidKindException(badgeDefinition.kind, [kindDefinition]);
    }
    if (awardees.isEmpty) {
      throw InvalidArgumentException(
        'awardees',
        'must be non-empty (NIP-58: badge award MUST have ≥1 p tag)',
      );
    }

    final dTag = findTagValue(badgeDefinition.tags, 'd');
    if (dTag == null) throw MissingTagException('d');

    // Build the "a" coordinate: kind:pubkey:d-tag
    final coordinate =
        '$kindDefinition:${badgeDefinition.pubkey}:$dTag';

    final tags = <List<String>>[
      ['a', coordinate],
    ];

    for (final awardee in awardees) {
      tags.add(awardee.relay != null
          ? ['p', awardee.pubkey, awardee.relay!]
          : ['p', awardee.pubkey]);
    }

    return Event.from(
      kind: kindAward,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Creates a kind-10008 profile badges event.
  ///
  /// Current spec uses kind 10008 (a replaceable list). Older clients
  /// emitted kind 30008 with `d=profile_badges`; that form is still
  /// readable via [parseProfileBadges] but no longer produced by the
  /// library.
  ///
  /// [badges] is a list of paired (definition, award) events the user
  /// wants to display. Order determines display priority.
  /// [pubkey] is the awarded user's public key — each award must contain
  /// a `p` tag referencing this pubkey.
  ///
  /// Throws [InvalidKindException] if any definition is not kind 30009
  /// or any award is not kind 8.
  /// Throws [MissingTagException] if a definition has no `d` tag.
  /// Throws [NostrException] if an award does not contain the awarded pubkey.
  static Event profileBadges({
    required List<({Event definition, Event award})> badges,
    required String secretKey,
    required String pubkey,
  }) {
    final tags = <List<String>>[];

    for (final badge in badges) {
      if (badge.definition.kind != kindDefinition) {
        throw InvalidKindException(badge.definition.kind, [kindDefinition]);
      }
      if (badge.award.kind != kindAward) {
        throw InvalidKindException(badge.award.kind, [kindAward]);
      }

      // Verify the award contains the awarded pubkey
      final awardedPubkeys = findAllTagValues(badge.award.tags, 'p');
      if (!awardedPubkeys.contains(pubkey)) {
        throw InvalidArgumentException(
          'badges[].award',
          'event ${badge.award.id} does not contain a p tag for the '
              'awarded pubkey $pubkey',
        );
      }

      final dTag = findTagValue(badge.definition.tags, 'd');
      if (dTag == null) throw MissingTagException('d');

      final coordinate =
          '$kindDefinition:${badge.definition.pubkey}:$dTag';
      // Emit `a` immediately followed by `e` so consumers that pair by
      // adjacency (per spec) match the pair correctly.
      tags.add(['a', coordinate]);
      tags.add(['e', badge.award.id]);
    }

    return Event.from(
      kind: kindProfileBadges,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Parses a kind-30009 event into a [BadgeDefinitionData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 30009.
  /// Throws [MissingTagException] if the `d` tag is absent and
  /// [permissive] is false.
  static BadgeDefinitionData parseDefinition(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindDefinition) {
      throw InvalidKindException(event.kind, [kindDefinition]);
    }

    final missing = <String>{};
    final badgeId = findTagValue(event.tags, 'd');
    if (badgeId == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    String? imageUrl;
    String? imageSize;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'image' && tag.length > 1) {
        imageUrl = tag[1];
        if (tag.length > 2) imageSize = tag[2];
        break;
      }
    }

    final thumbnails = <BadgeImage>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'thumb' && tag.length > 1) {
        thumbnails.add(BadgeImage(
          url: tag[1],
          size: tag.length > 2 ? tag[2] : null,
        ));
      }
    }

    return BadgeDefinitionData(
      badgeId: badgeId ?? '',
      name: findTagValue(event.tags, 'name'),
      description: findTagValue(event.tags, 'description'),
      image: imageUrl != null
          ? BadgeImage(url: imageUrl, size: imageSize)
          : null,
      thumbnails: thumbnails,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }

  /// Parses a kind-8 event into a [BadgeAwardData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 8.
  /// Spec requires an `a` tag (coordinate) and ≥1 `p` tag (awardee).
  /// In strict mode missing `a` or empty `p` set throws
  /// [MissingTagException]; in permissive mode both are recorded on
  /// [BadgeAwardData.missingTags].
  static BadgeAwardData parseAward(Event event, {bool permissive = false}) {
    if (event.kind != kindAward) {
      throw InvalidKindException(event.kind, [kindAward]);
    }

    final missing = <String>{};
    final coordinate = findTagValue(event.tags, 'a');
    if (coordinate == null) {
      if (!permissive) throw MissingTagException('a');
      missing.add('a');
    }

    final awardees = <({String pubkey, String? relay})>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        awardees.add((
          pubkey: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
        ));
      }
    }
    if (awardees.isEmpty) {
      if (!permissive) throw MissingTagException('p');
      missing.add('p');
    }

    return BadgeAwardData(
      coordinate: coordinate ?? '',
      awardees: awardees,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }

  /// Parses a profile-badges event into a [ProfileBadgesData].
  ///
  /// Accepts both the current kind 10008 and the legacy kind 30008
  /// (with `d=profile_badges`). Paired `a` and `e` tags are matched by
  /// adjacency in the original tag list — when an `a` is immediately
  /// followed (across any non-`a`/`e` tags) by an `e`, they form one
  /// badge entry. Unpaired tags are discarded per spec.
  ///
  /// Throws [InvalidKindException] if the event kind is not 10008 or
  /// 30008.
  static ProfileBadgesData parseProfileBadges(Event event) {
    if (event.kind != kindProfileBadges &&
        event.kind != kindProfileBadgesLegacy) {
      throw InvalidKindException(
        event.kind,
        [kindProfileBadges, kindProfileBadgesLegacy],
      );
    }

    final badges = <({String coordinate, String awardEventId})>[];
    String? pendingA;
    for (final tag in event.tags) {
      if (tag.length < 2) continue;
      if (tag[0] == 'a') {
        // A new `a` without an intervening `e` discards the previous one
        // (per spec — pairs are adjacent).
        pendingA = tag[1];
      } else if (tag[0] == 'e' && pendingA != null) {
        badges.add((coordinate: pendingA, awardEventId: tag[1]));
        pendingA = null;
      }
    }

    return ProfileBadgesData(
      badges: badges,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// An image URL with optional `"WxH"` dimensions.
class BadgeImage {
  /// The image URL.
  final String url;

  /// Optional dimensions as `"WxH"` (e.g. `"1024x1024"`).
  final String? size;

  /// Creates a [BadgeImage].
  const BadgeImage({required this.url, this.size});

  @override
  String toString() => 'BadgeImage(url: $url, size: $size)';
}

/// Parsed badge definition (kind 30009).
class BadgeDefinitionData {
  /// The badge identifier (`d` tag).
  final String badgeId;

  /// Short badge name.
  final String? name;

  /// Badge description.
  final String? description;

  /// Main badge image with optional dimensions.
  final BadgeImage? image;

  /// Thumbnail images with optional dimensions.
  final List<BadgeImage> thumbnails;

  /// The public key of the badge creator.
  final String pubkey;

  /// Unix timestamp of the definition event.
  final int createdAt;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-58: `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [BadgeDefinitionData].
  const BadgeDefinitionData({
    required this.badgeId,
    required this.pubkey,
    required this.createdAt,
    this.name,
    this.description,
    this.image,
    this.thumbnails = const [],
    this.missingTags = const {},
  });
}

/// Parsed badge award (kind 8).
class BadgeAwardData {
  /// The `a` tag coordinate referencing the badge definition.
  final String coordinate;

  /// Awardees with optional relay hints.
  final List<({String pubkey, String? relay})> awardees;

  /// The public key of the badge issuer.
  final String pubkey;

  /// Unix timestamp of the award event.
  final int createdAt;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-58: `a`, `p`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [BadgeAwardData].
  const BadgeAwardData({
    required this.coordinate,
    required this.awardees,
    required this.pubkey,
    required this.createdAt,
    this.missingTags = const {},
  });
}

/// Parsed profile badges. Returned by [Badge.parseProfileBadges] for both
/// the current kind 10008 events and the legacy kind 30008 form.
class ProfileBadgesData {
  /// Ordered list of badge coordinate + award event ID pairs.
  final List<({String coordinate, String awardEventId})> badges;

  /// The public key of the profile owner.
  final String pubkey;

  /// Unix timestamp of the profile badges event.
  final int createdAt;

  /// Creates a [ProfileBadgesData].
  const ProfileBadgesData({
    required this.badges,
    required this.pubkey,
    required this.createdAt,
  });
}

typedef Nip58 = Badge;
