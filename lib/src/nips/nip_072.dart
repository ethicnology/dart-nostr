import 'dart:convert';

import 'package:nostr/nostr.dart';

/// Moderated Communities — [NIP-72](https://github.com/nostr-protocol/nips/blob/master/72.md)
///
/// Kind 34550: community definition — a parameterized replaceable event
/// with a `d` tag identifier, moderator `p` tags, and metadata tags.
///
/// Kind 4550: moderation approval — references a community via `a` tag
/// and the approved post via `e` or `a` tag. Content may contain the
/// JSON-stringified approved event.
class ModeratedCommunity {
  /// Kind for community definition events.
  static const int kindCommunity = 34550;

  /// Kind for community approval events.
  static const int kindApproval = 4550;

  /// Creates a kind-34550 community definition event.
  ///
  /// [id] is the community identifier (`d` tag).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [name] is the display name (optional).
  /// [description] is the community description (optional).
  /// [image] is the community image URL (optional).
  /// [imageDimensions] is the image dimensions string, e.g. "1024x768" (optional).
  /// [rules] is the community rules text (optional).
  /// [moderators] is a list of moderator pubkeys (optional).
  /// [relays] is a list of preferred relays with optional markers (optional).
  static Event community({
    required String id,
    required String secretKey,
    String? name,
    String? description,
    String? image,
    String? imageDimensions,
    String? rules,
    List<String> moderators = const [],
    List<CommunityRelay> relays = const [],
  }) {
    final List<List<String>> tags = [
      ['d', id],
    ];

    if (name != null) {
      tags.add(['name', name]);
    }

    if (description != null) {
      tags.add(['description', description]);
    }

    if (image != null) {
      final imageTag = ['image', image];
      if (imageDimensions != null) {
        imageTag.add(imageDimensions);
      }
      tags.add(imageTag);
    }

    if (rules != null) {
      tags.add(['rules', rules]);
    }

    for (final moderator in moderators) {
      tags.add(['p', moderator, '', 'moderator']);
    }

    for (final relay in relays) {
      if (relay.marker != null) {
        tags.add(['relay', relay.url, relay.marker!]);
      } else {
        tags.add(['relay', relay.url]);
      }
    }

    return Event.from(
      kind: kindCommunity,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Parses a kind-34550 event into a [CommunityData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 34550.
  /// Throws [MissingTagException] if the `d` tag is absent and
  /// [permissive] is false. In permissive mode missing `d` is recorded
  /// on [CommunityData.missingTags].
  static CommunityData parseCommunity(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindCommunity) {
      throw InvalidKindException(event.kind, [kindCommunity]);
    }

    final missing = <String>{};
    final id = findTagValue(event.tags, 'd');
    if (id == null) {
      if (!permissive) throw MissingTagException('d');
      missing.add('d');
    }

    final name = findTagValue(event.tags, 'name');
    final description = findTagValue(event.tags, 'description');
    final rules = findTagValue(event.tags, 'rules');

    // Parse image tag (may include dimensions as third element)
    String? image;
    String? imageDimensions;
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'image' && tag.length > 1) {
        image = tag[1];
        if (tag.length > 2) {
          imageDimensions = tag[2];
        }
        break;
      }
    }

    // Parse moderators from p tags with "moderator" role
    final moderators = <Moderator>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        final relay = tag.length > 2 ? tag[2] : null;
        final role = tag.length > 3 ? tag[3] : null;
        moderators.add(Moderator(
          pubkey: tag[1],
          relay: (relay != null && relay.isNotEmpty) ? relay : null,
          role: role,
        ));
      }
    }

    final relays = <CommunityRelay>[];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'relay' && tag.length > 1) {
        final marker = tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null;
        relays.add(CommunityRelay(url: tag[1], marker: marker));
      }
    }

    return CommunityData(
      id: id ?? '',
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      name: name,
      description: description,
      image: image,
      imageDimensions: imageDimensions,
      rules: rules,
      moderators: moderators,
      relays: relays,
      missingTags: missing,
    );
  }

  /// Creates a kind-4550 community approval event.
  ///
  /// [communityCoord] is the community `a` tag coordinate
  /// (e.g. "34550:pubkey:community-id").
  /// [approvedEventId] is the event ID of the approved post (regular
  /// events). For addressable posts use [approvedEventCoord] instead.
  /// [approvedEventCoord] is the `a`-tag coordinate of the approved post
  /// (addressable posts).
  /// [approvedEventPubkey] is the public key of the approved post author.
  /// [approvedEventKind] is the kind of the approved post.
  /// [approvedEventJson] is the JSON-stringified approved event to include
  /// in the content. Spec MUST when referencing the post via an `e` tag
  /// ("content of an approval using an `e` tag MUST have the specific
  /// version of the post"). Optional when referencing via [approvedEventCoord].
  ///
  /// Throws [NostrException] if neither (or both) of [approvedEventId] /
  /// [approvedEventCoord] is provided, or if [approvedEventId] is set
  /// without [approvedEventJson].
  static Event approval({
    required String communityCoord,
    required String approvedEventPubkey,
    required int approvedEventKind,
    required String secretKey,
    String? approvedEventId,
    String? approvedEventCoord,
    String? approvedEventJson,
  }) {
    final hasE = approvedEventId != null;
    final hasA = approvedEventCoord != null;
    if (!hasE && !hasA) {
      throw ApprovalScopeException(ApprovalScopeReason.noTarget);
    }
    if (hasE && hasA) {
      throw ApprovalScopeException(ApprovalScopeReason.bothTargets);
    }
    if (hasE && (approvedEventJson == null || approvedEventJson.isEmpty)) {
      throw ApprovalScopeException(ApprovalScopeReason.missingEventJson);
    }

    return Event.from(
      kind: kindApproval,
      tags: [
        ['a', communityCoord],
        if (hasE) ['e', approvedEventId],
        if (hasA) ['a', approvedEventCoord],
        ['p', approvedEventPubkey],
        ['k', approvedEventKind.toString()],
      ],
      content: approvedEventJson ?? '',
      secretKey: secretKey,
    );
  }

  /// Parses a kind-4550 event into a [CommunityApprovalData].
  ///
  /// The community is identified by the first `a` tag (coordinate of the
  /// kind-34550 definition). The approved post is referenced by either:
  /// - an `e` tag (regular events), or
  /// - a second `a` tag (addressable events).
  ///
  /// Throws [InvalidKindException] if the event kind is not 4550.
  /// Throws [MissingTagException] if the community `a` tag is absent
  /// and [permissive] is false.
  static CommunityApprovalData parseApproval(
    Event event, {
    bool permissive = false,
  }) {
    if (event.kind != kindApproval) {
      throw InvalidKindException(event.kind, [kindApproval]);
    }

    final missing = <String>{};
    final aTags = findAllTagValues(event.tags, 'a');
    if (aTags.isEmpty) {
      if (!permissive) throw MissingTagException('a');
      missing.add('a');
    }

    // Disambiguate by prefix, not position: community `a` tags always
    // start with "34550:" per spec. Anything else with an `a` tag is the
    // approved-event coord. This is robust against out-of-order tags.
    String? communityCoord;
    String? approvedEventCoord;
    for (final coord in aTags) {
      if (coord.startsWith('$kindCommunity:')) {
        communityCoord ??= coord;
      } else {
        approvedEventCoord ??= coord;
      }
    }
    // Fallback for malformed inputs: if no `34550:` prefix was found, fall
    // back to the historical "first a is community" behaviour so we still
    // surface *something* rather than swallow the tag.
    if (communityCoord == null && aTags.isNotEmpty) {
      communityCoord = aTags.first;
      approvedEventCoord ??= aTags.length > 1 ? aTags[1] : null;
    }
    final resolvedCommunityCoord = communityCoord ?? '';

    final approvedEventId = findTagValue(event.tags, 'e');
    final approvedEventPubkey = findTagValue(event.tags, 'p');
    final approvedEventKindStr = findTagValue(event.tags, 'k');
    final approvedEventKind = approvedEventKindStr != null
        ? int.tryParse(approvedEventKindStr)
        : null;

    // Try to parse the approved event from content. Verification is off
    // because this is a third-party event copy; callers that need integrity
    // should re-verify out of band.
    Event? approvedEvent;
    if (event.content.isNotEmpty) {
      try {
        final map = json.decode(event.content) as Map<String, dynamic>;
        approvedEvent = Event.fromMap(map, verify: false);
      } on Exception catch (_) {
        // Leave approvedEvent null when content isn't a parseable event.
      }
    }

    return CommunityApprovalData(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      communityCoord: resolvedCommunityCoord,
      approvedEventId: approvedEventId,
      approvedEventCoord: approvedEventCoord,
      approvedEventPubkey: approvedEventPubkey,
      approvedEventKind: approvedEventKind,
      approvedEvent: approvedEvent,
      missingTags: missing,
    );
  }
}

/// A decoded community definition (kind 34550).
class CommunityData {
  /// The community identifier from the `d` tag.
  final String id;

  /// The community creator's public key.
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// Display name from the `name` tag.
  final String? name;

  /// Community description from the `description` tag.
  final String? description;

  /// Community image URL from the `image` tag.
  final String? image;

  /// Image dimensions string from the `image` tag's third element.
  final String? imageDimensions;

  /// Community rules from the `rules` tag.
  final String? rules;

  /// Moderators parsed from `p` tags.
  final List<Moderator> moderators;

  /// Preferred relays from `relay` tags, with optional markers.
  final List<CommunityRelay> relays;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-72: `d`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [CommunityData] with the given fields.
  const CommunityData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    this.name,
    this.description,
    this.image,
    this.imageDimensions,
    this.rules,
    this.moderators = const [],
    this.relays = const [],
    this.missingTags = const {},
  });
}

/// A moderator entry parsed from a `p` tag in a community definition.
class Moderator {
  /// The moderator's public key.
  final String pubkey;

  /// Optional relay URL hint.
  final String? relay;

  /// Optional role label (e.g. "moderator").
  final String? role;

  /// Creates a [Moderator] with the given fields.
  const Moderator({
    required this.pubkey,
    this.relay,
    this.role,
  });
}

/// A relay entry in a community definition.
///
/// The optional [marker] can be "author", "requests", or "approvals"
/// to indicate the relay's role per NIP-72.
class CommunityRelay {
  /// The relay WebSocket URL.
  final String url;

  /// Optional marker: "author", "requests", or "approvals".
  final String? marker;

  /// Creates a [CommunityRelay].
  const CommunityRelay({required this.url, this.marker});
}

/// A decoded community approval event (kind 4550).
class CommunityApprovalData {
  /// The event ID.
  final String id;

  /// The moderator's public key (event author).
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The community coordinate from the `a` tag (e.g. "34550:pubkey:id").
  final String communityCoord;

  /// The approved event's ID from the `e` tag, if the post is a regular
  /// event.
  final String? approvedEventId;

  /// The approved event's `a`-tag coordinate, if the post is addressable.
  /// Distinct from [communityCoord] (which is always the first `a` tag).
  final String? approvedEventCoord;

  /// The approved event author's pubkey from the `p` tag, if present.
  final String? approvedEventPubkey;

  /// The approved event's kind from the `k` tag, if present.
  final int? approvedEventKind;

  /// The parsed approved event from content, if valid JSON was provided.
  final Event? approvedEvent;

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-72: `a`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates a [CommunityApprovalData] with the given fields.
  const CommunityApprovalData({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.communityCoord,
    this.approvedEventId,
    this.approvedEventCoord,
    this.approvedEventPubkey,
    this.approvedEventKind,
    this.approvedEvent,
    this.missingTags = const {},
  });
}

typedef Nip72 = ModeratedCommunity;
typedef Community = CommunityData;
typedef CommunityApproval = CommunityApprovalData;
