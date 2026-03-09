import 'package:nostr/nostr.dart';

/// Live activities — [NIP-53](https://github.com/nostr-protocol/nips/blob/master/53.md)
///
/// A kind 30311 addressable event representing a live streaming event.
/// Tags carry metadata like `title`, `summary`, `streaming`, `status`,
/// `starts`, `ends`, and participant `p` tags with roles.
///
/// Example:
/// ```json
/// {
///   "kind": 30311,
///   "tags": [
///     ["d", "live-stream-123"],
///     ["title", "My Live Stream"],
///     ["status", "live"],
///     ["streaming", "https://stream.example.com/live.m3u8"],
///     ["p", "<host-pubkey>", "", "Host"],
///     ["p", "<speaker-pubkey>", "", "Speaker"],
///     ["starts", "1692000000"],
///     ["ends", "1692100000"]
///   ],
///   "content": ""
/// }
/// ```
class LiveActivity {
  /// Event kind for live streaming events.
  static const int kindLiveEvent = 30311;

  /// Event kind for live chat messages.
  static const int kindLiveChat = 1311;

  /// Creates a kind-30311 live activity event.
  ///
  /// [identifier] is the unique `d` tag value.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [status] should be "planned", "live", or "ended".
  static Event create({
    required String identifier,
    required String secretKey,
    String? title,
    String? summary,
    String? image,
    String? streaming,
    String? recording,
    String? status,
    int? starts,
    int? ends,
    List<String> hashtags = const [],
    List<LiveParticipant> participants = const [],
    String content = '',
  }) {
    final List<List<String>> tags = [
      ['d', identifier],
      if (title != null) ['title', title],
      if (summary != null) ['summary', summary],
      if (image != null) ['image', image],
      if (streaming != null) ['streaming', streaming],
      if (recording != null) ['recording', recording],
      if (status != null) ['status', status],
      if (starts != null) ['starts', starts.toString()],
      if (ends != null) ['ends', ends.toString()],
      for (final t in hashtags) ['t', t],
      for (final p in participants)
        ['p', p.pubkey, p.relay ?? '', p.role ?? ''],
    ];

    return Event.from(
      kind: kindLiveEvent,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Decodes a kind-30311 event into a [LiveActivityData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 30311.
  /// Throws [MissingTagException] if the `d` tag is absent.
  static LiveActivityData parse(Event event) {
    if (event.kind != kindLiveEvent) {
      throw InvalidKindException(event.kind, [kindLiveEvent]);
    }

    final identifier = findTagValue(event.tags, 'd');
    if (identifier == null) {
      throw MissingTagException('d');
    }

    final title = findTagValue(event.tags, 'title');
    final summary = findTagValue(event.tags, 'summary');
    final image = findTagValue(event.tags, 'image');
    final streaming = findTagValue(event.tags, 'streaming');
    final recording = findTagValue(event.tags, 'recording');
    final status = findTagValue(event.tags, 'status');
    final startsStr = findTagValue(event.tags, 'starts');
    final endsStr = findTagValue(event.tags, 'ends');
    final currentParticipantsStr =
        findTagValue(event.tags, 'current_participants');
    final totalParticipantsStr =
        findTagValue(event.tags, 'total_participants');
    final hashtags = findAllTagValues(event.tags, 't');

    // Extract p tags with roles
    final List<LiveParticipant> participants = [];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
        final pubkey = tag[1];
        final relay = tag.length > 2 && tag[2].isNotEmpty ? tag[2] : null;
        final role = tag.length > 3 && tag[3].isNotEmpty ? tag[3] : null;
        participants.add(LiveParticipant(
          pubkey: pubkey,
          relay: relay,
          role: role,
        ));
      }
    }

    return LiveActivityData(
      identifier: identifier,
      title: title,
      summary: summary,
      image: image,
      streaming: streaming,
      recording: recording,
      status: status,
      starts: startsStr != null ? int.tryParse(startsStr) : null,
      ends: endsStr != null ? int.tryParse(endsStr) : null,
      currentParticipants: currentParticipantsStr != null
          ? int.tryParse(currentParticipantsStr)
          : null,
      totalParticipants: totalParticipantsStr != null
          ? int.tryParse(totalParticipantsStr)
          : null,
      hashtags: hashtags,
      participants: participants,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// A participant in a live activity with an optional role.
class LiveParticipant {
  /// The participant's public key.
  final String pubkey;

  /// Optional relay hint.
  final String? relay;

  /// The participant's role (e.g. "Host", "Speaker", "Participant").
  final String? role;

  /// Creates a [LiveParticipant].
  const LiveParticipant({
    required this.pubkey,
    this.relay,
    this.role,
  });

  @override
  String toString() =>
      'LiveParticipant(pubkey: $pubkey, relay: $relay, role: $role)';
}

/// Represents a NIP-53 live activity event (kind 30311).
class LiveActivityData {
  /// The unique identifier (from `d` tag).
  final String identifier;

  /// The event title (from `title` tag).
  final String? title;

  /// The event summary (from `summary` tag).
  final String? summary;

  /// The event image URL (from `image` tag).
  final String? image;

  /// The streaming URL (from `streaming` tag).
  final String? streaming;

  /// The recording URL (from `recording` tag).
  final String? recording;

  /// The current status: "planned", "live", or "ended" (from `status` tag).
  final String? status;

  /// The start timestamp (from `starts` tag).
  final int? starts;

  /// The end timestamp (from `ends` tag).
  final int? ends;

  /// The current number of participants (from `current_participants` tag).
  final int? currentParticipants;

  /// The total number of participants (from `total_participants` tag).
  final int? totalParticipants;

  /// Hashtags (from `t` tags).
  final List<String> hashtags;

  /// Participants with their roles (from `p` tags).
  final List<LiveParticipant> participants;

  /// The public key of the event creator.
  final String pubkey;

  /// Unix timestamp of the event.
  final int createdAt;

  /// Creates a [LiveActivityData] with the given fields.
  const LiveActivityData({
    required this.identifier,
    required this.pubkey,
    required this.createdAt,
    this.title,
    this.summary,
    this.image,
    this.streaming,
    this.recording,
    this.status,
    this.starts,
    this.ends,
    this.currentParticipants,
    this.totalParticipants,
    this.hashtags = const [],
    this.participants = const [],
  });
}

typedef Nip53 = LiveActivity;
typedef LiveActivities = LiveActivity;
