import 'package:nostr/nostr.dart';

/// Badges — [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md)
///
/// Three event kinds for creating, awarding, and displaying badges:
/// - Kind 30009: Badge definition (addressable, updatable)
/// - Kind 8: Badge award (immutable)
/// - Kind 30008: Profile badges (user-curated display)
class Badge {
  /// Event kind for badge definitions.
  static const int kindDefinition = 30009;

  /// Event kind for badge awards.
  static const int kindAward = 8;

  /// Event kind for profile badges.
  static const int kindProfileBadges = 30008;

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
  /// [awardees] is a list of pubkeys (with optional relay URL) to award.
  ///
  /// Throws [InvalidKindException] if [badgeDefinition] is not kind 30009.
  /// Throws [MissingTagException] if [badgeDefinition] has no `d` tag.
  static Event award({
    required Event badgeDefinition,
    required List<({String pubkey, String? relay})> awardees,
    required String secretKey,
  }) {
    if (badgeDefinition.kind != kindDefinition) {
      throw InvalidKindException(badgeDefinition.kind, [kindDefinition]);
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

  /// Creates a kind-30008 profile badges event.
  ///
  /// [badges] is a list of paired (definition, award) events the user
  /// wants to display. Order determines display priority.
  /// [pubkey] is the awarded user's public key — each award must contain
  /// a `p` tag referencing this pubkey.
  ///
  /// Throws [InvalidKindException] if any definition is not kind 30009
  /// or any award is not kind 8.
  /// Throws [NostrException] if an award does not contain the awarded pubkey.
  static Event profileBadges({
    required List<({Event definition, Event award})> badges,
    required String secretKey,
    required String pubkey,
  }) {
    final tags = <List<String>>[
      ['d', 'profile_badges'],
    ];

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
        throw NostrException(
          'Badge award ${badge.award.id} does not contain awarded pubkey',
        );
      }

      final dTag = findTagValue(badge.definition.tags, 'd');
      if (dTag == null) continue;

      final coordinate =
          '$kindDefinition:${badge.definition.pubkey}:$dTag';
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
  /// Throws [MissingTagException] if the `d` tag is absent.
  static BadgeDefinitionData parseDefinition(Event event) {
    if (event.kind != kindDefinition) {
      throw InvalidKindException(event.kind, [kindDefinition]);
    }

    final badgeId = findTagValue(event.tags, 'd');
    if (badgeId == null) throw MissingTagException('d');

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
      badgeId: badgeId,
      name: findTagValue(event.tags, 'name'),
      description: findTagValue(event.tags, 'description'),
      image: imageUrl != null
          ? BadgeImage(url: imageUrl, size: imageSize)
          : null,
      thumbnails: thumbnails,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }

  /// Parses a kind-8 event into a [BadgeAwardData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 8.
  static BadgeAwardData parseAward(Event event) {
    if (event.kind != kindAward) {
      throw InvalidKindException(event.kind, [kindAward]);
    }

    final coordinate = findTagValue(event.tags, 'a');
    final awardees = <({String pubkey, String? relay})>[];

    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        awardees.add((
          pubkey: tag[1],
          relay: tag.length > 2 ? tag[2] : null,
        ));
      }
    }

    return BadgeAwardData(
      coordinate: coordinate ?? '',
      awardees: awardees,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }

  /// Parses a kind-30008 event into a [ProfileBadgesData].
  ///
  /// Paired `a` and `e` tags are matched in order per spec. Unpaired
  /// tags are discarded.
  ///
  /// Throws [InvalidKindException] if the event kind is not 30008.
  static ProfileBadgesData parseProfileBadges(Event event) {
    if (event.kind != kindProfileBadges) {
      throw InvalidKindException(event.kind, [kindProfileBadges]);
    }

    // Collect a and e tags in order, skipping the d tag
    final aCoords = <String>[];
    final eIds = <String>[];
    for (final tag in event.tags) {
      if (tag.length > 1) {
        if (tag[0] == 'a') aCoords.add(tag[1]);
        if (tag[0] == 'e') eIds.add(tag[1]);
      }
    }

    // Pair them: take min length per spec (discard unpaired)
    final count = aCoords.length < eIds.length ? aCoords.length : eIds.length;
    final badges = <({String coordinate, String awardEventId})>[];
    for (var i = 0; i < count; i++) {
      badges.add((coordinate: aCoords[i], awardEventId: eIds[i]));
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

  /// Creates a [BadgeDefinitionData].
  const BadgeDefinitionData({
    required this.badgeId,
    required this.pubkey,
    required this.createdAt,
    this.name,
    this.description,
    this.image,
    this.thumbnails = const [],
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

  /// Creates a [BadgeAwardData].
  const BadgeAwardData({
    required this.coordinate,
    required this.awardees,
    required this.pubkey,
    required this.createdAt,
  });
}

/// Parsed profile badges (kind 30008).
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
