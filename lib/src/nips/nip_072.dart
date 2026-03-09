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
class Nip72 {
  /// Kind for community definition events.
  static const int communityKind = 34550;

  /// Kind for community approval events.
  static const int approvalKind = 4550;

  /// Encodes a kind-34550 community definition event.
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
  static Event encodeCommunity({
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
      kind: communityKind,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-34550 event into a [Community].
  ///
  /// Throws [InvalidKindException] if the event kind is not 34550.
  /// Throws [MissingTagException] if the `d` tag is absent.
  static Community decodeCommunity(Event event) {
    if (event.kind != communityKind) {
      throw InvalidKindException(event.kind, [communityKind]);
    }

    final id = findTagValue(event.tags, 'd');
    if (id == null) {
      throw MissingTagException('d');
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

    return Community(
      id: id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      name: name,
      description: description,
      image: image,
      imageDimensions: imageDimensions,
      rules: rules,
      moderators: moderators,
      relays: relays,
    );
  }

  /// Encodes a kind-4550 community approval event.
  ///
  /// [communityCoord] is the community `a` tag coordinate
  /// (e.g. "34550:pubkey:community-id").
  /// [approvedEventId] is the event ID of the approved post.
  /// [approvedEventPubkey] is the public key of the approved post author.
  /// [approvedEventKind] is the kind of the approved post.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [approvedEventJson] is the optional JSON-stringified approved event
  /// to include in the content.
  static Event encodeApproval({
    required String communityCoord,
    required String approvedEventId,
    required String approvedEventPubkey,
    required int approvedEventKind,
    required String secretKey,
    String? approvedEventJson,
  }) {
    return Event.from(
      kind: approvalKind,
      tags: [
        ['a', communityCoord],
        ['e', approvedEventId],
        ['p', approvedEventPubkey],
        ['k', approvedEventKind.toString()],
      ],
      content: approvedEventJson ?? '',
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-4550 event into a [CommunityApproval].
  ///
  /// Throws [InvalidKindException] if the event kind is not 4550.
  /// Throws [MissingTagException] if the `a` tag is absent.
  static CommunityApproval decodeApproval(Event event) {
    if (event.kind != approvalKind) {
      throw InvalidKindException(event.kind, [approvalKind]);
    }

    final communityCoord = findTagValue(event.tags, 'a');
    if (communityCoord == null) {
      throw MissingTagException('a');
    }

    final approvedEventId = findTagValue(event.tags, 'e');
    final approvedEventPubkey = findTagValue(event.tags, 'p');
    final approvedEventKindStr = findTagValue(event.tags, 'k');
    final approvedEventKind = approvedEventKindStr != null
        ? int.tryParse(approvedEventKindStr)
        : null;

    // Try to parse the approved event from content
    Event? approvedEvent;
    if (event.content.isNotEmpty) {
      try {
        final map = json.decode(event.content) as Map<String, dynamic>;
        approvedEvent = Event.fromMap(map, verify: false);
      } on Exception catch (_) {
        // If parsing fails, leave approvedEvent as null
      }
    }

    return CommunityApproval(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      communityCoord: communityCoord,
      approvedEventId: approvedEventId,
      approvedEventPubkey: approvedEventPubkey,
      approvedEventKind: approvedEventKind,
      approvedEvent: approvedEvent,
    );
  }
}

/// A decoded community definition (kind 34550).
class Community {
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

  /// Creates a [Community] with the given fields.
  const Community({
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
class CommunityApproval {
  /// The event ID.
  final String id;

  /// The moderator's public key (event author).
  final String pubkey;

  /// Unix timestamp of the event creation.
  final int createdAt;

  /// The community coordinate from the `a` tag (e.g. "34550:pubkey:id").
  final String communityCoord;

  /// The approved event's ID from the `e` tag, if present.
  final String? approvedEventId;

  /// The approved event author's pubkey from the `p` tag, if present.
  final String? approvedEventPubkey;

  /// The approved event's kind from the `k` tag, if present.
  final int? approvedEventKind;

  /// The parsed approved event from content, if valid JSON was provided.
  final Event? approvedEvent;

  /// Creates a [CommunityApproval] with the given fields.
  const CommunityApproval({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.communityCoord,
    this.approvedEventId,
    this.approvedEventPubkey,
    this.approvedEventKind,
    this.approvedEvent,
  });
}

typedef ModeratedCommunities = Nip72;
