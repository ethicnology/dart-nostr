import 'package:nostr/nostr.dart';

/// Labels — [NIP-32](https://github.com/nostr-protocol/nips/blob/master/32.md)
///
/// A kind 1985 event for attaching labels to events, pubkeys, relays, URLs,
/// or topics. Labels are organized into namespaces via `L` tags and individual
/// label values via `l` tags (which reference a namespace).
///
/// Example:
/// ```json
/// {
///   "kind": 1985,
///   "tags": [
///     ["L", "social.ontolo.categories"],
///     ["l", "Technology", "social.ontolo.categories"],
///     ["e", "<event-id>", "<relay-url>"]
///   ],
///   "content": ""
/// }
/// ```
class Label {
  /// Event kind for label events.
  static const int kindLabel = 1985;

  /// Creates a kind-1985 label event.
  ///
  /// [labels] is the list of label entries to attach.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// At least one target must be provided (per spec).
  /// [content] is an optional explanation for why the labels were applied.
  static Event create({
    required List<LabelEntry> labels,
    required String secretKey,
    List<String> targetEvents = const [],
    List<String> targetPubkeys = const [],
    List<String> targetCoordinates = const [],
    List<String> targetUrls = const [],
    List<String> targetTopics = const [],
    String content = '',
  }) {
    final List<List<String>> tags = [];

    // Add L tags (unique namespaces from labels)
    final namespaces = <String>{};
    for (final label in labels) {
      if (label.namespace != null) {
        namespaces.add(label.namespace!);
      }
    }
    for (final ns in namespaces) {
      tags.add(['L', ns]);
    }

    // Add l tags
    for (final label in labels) {
      if (label.namespace != null) {
        tags.add(['l', label.value, label.namespace!]);
      } else {
        tags.add(['l', label.value]);
      }
    }

    // Add targets
    for (final id in targetEvents) {
      tags.add(['e', id]);
    }
    for (final pk in targetPubkeys) {
      tags.add(['p', pk]);
    }
    for (final coord in targetCoordinates) {
      tags.add(['a', coord]);
    }
    for (final url in targetUrls) {
      tags.add(['r', url]);
    }
    for (final topic in targetTopics) {
      tags.add(['t', topic]);
    }

    return Event.from(
      kind: kindLabel,
      tags: tags,
      content: content,
      secretKey: secretKey,
    );
  }

  /// Parses a kind-1985 event into a [LabelData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 1985.
  static LabelData parse(Event event) {
    if (event.kind != kindLabel) {
      throw InvalidKindException(event.kind, [kindLabel]);
    }

    // L tags = namespaces
    final namespaces = findAllTagValues(event.tags, 'L');

    // l tags = label entries (value + namespace mark)
    final List<LabelEntry> labels = [];
    for (final tag in event.tags) {
      if (tag.isNotEmpty && tag[0] == 'l' && tag.length > 1) {
        final value = tag[1];
        final namespace = tag.length > 2 ? tag[2] : null;
        labels.add(LabelEntry(value: value, namespace: namespace));
      }
    }

    // Target references
    final targetEvents = findAllTagValues(event.tags, 'e');
    final targetPubkeys = findAllTagValues(event.tags, 'p');
    final targetCoordinates = findAllTagValues(event.tags, 'a');
    final targetUrls = findAllTagValues(event.tags, 'r');
    final targetTopics = findAllTagValues(event.tags, 't');

    return LabelData(
      namespaces: namespaces,
      labels: labels,
      targetEvents: targetEvents,
      targetPubkeys: targetPubkeys,
      targetCoordinates: targetCoordinates,
      targetUrls: targetUrls,
      targetTopics: targetTopics,
      content: event.content,
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }
}

/// A single label entry extracted from an `l` tag.
class LabelEntry {
  /// The label value.
  final String value;

  /// The namespace this label belongs to (from the tag's third element).
  /// If absent, `ugc` (user-generated content) is implied.
  final String? namespace;

  /// Creates a [LabelEntry].
  const LabelEntry({required this.value, this.namespace});

  @override
  String toString() => 'LabelEntry(value: $value, namespace: $namespace)';
}

/// Represents a NIP-32 label event.
class LabelData {
  /// Label namespaces (from `L` tags).
  final List<String> namespaces;

  /// Individual label entries (from `l` tags).
  final List<LabelEntry> labels;

  /// Target event IDs (from `e` tags).
  final List<String> targetEvents;

  /// Target public keys (from `p` tags).
  final List<String> targetPubkeys;

  /// Target addressable event coordinates (from `a` tags).
  final List<String> targetCoordinates;

  /// Target URLs (from `r` tags).
  final List<String> targetUrls;

  /// Target topics (from `t` tags).
  final List<String> targetTopics;

  /// The event content (often empty for label events).
  final String content;

  /// The public key of the label author.
  final String pubkey;

  /// Unix timestamp of the label event.
  final int createdAt;

  /// Creates a [LabelData] with the given fields.
  const LabelData({
    required this.pubkey,
    required this.createdAt,
    this.namespaces = const [],
    this.labels = const [],
    this.targetEvents = const [],
    this.targetPubkeys = const [],
    this.targetCoordinates = const [],
    this.targetUrls = const [],
    this.targetTopics = const [],
    this.content = '',
  });
}

typedef Nip32 = Label;
