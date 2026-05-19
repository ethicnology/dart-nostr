// Picks one well-formed real-world event per kind from the captured
// corpus and merges new kinds into `test/fixtures/samples_by_kind.json`
// (a curated single-event-per-kind fixture used by the test suite).
//
// Run with:  dart run tool/curate_samples.dart
//
// Strategy per kind:
//   1. Take events from captured_events.jsonl for that kind.
//   2. Verify each event's signature.
//   3. Run the lib's parser for the kind; skip events that hit
//      SPEC_REJECT or BUG (we want a sample that exercises the happy
//      path, since the negative paths are already tested elsewhere).
//   4. Among the survivors, prefer the event with the MOST tags
//      (proxy for "most complete"), then by id for determinism.
//
// Kinds already present in samples_by_kind.json are NOT overwritten —
// the existing curation is hand-picked and tests reference it by id.

import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';

const _corpusPath = 'test/fixtures/captured_events.jsonl';
const _samplesPath = 'test/fixtures/samples_by_kind.json';

Future<void> main() async {
  final corpus = File(_corpusPath);
  final samples = File(_samplesPath);
  if (!corpus.existsSync()) {
    stderr.writeln('No corpus at $_corpusPath. Run tool/capture_events.dart first.');
    exit(1);
  }

  // Load existing samples (kind → event map). Keys are stringified kinds.
  final existing = json.decode(samples.readAsStringSync()) as Map<String, dynamic>;
  final existingKinds = existing.keys.map(int.parse).toSet();

  // Bucket the corpus by kind.
  final byKind = <int, List<Map<String, dynamic>>>{};
  for (final line in corpus.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    final ev = json.decode(line) as Map<String, dynamic>;
    final kind = ev['kind'] as int;
    byKind.putIfAbsent(kind, () => []).add(ev);
  }

  final added = <int>[];
  final skipped = <int, String>{};

  for (final entry in byKind.entries) {
    final kind = entry.key;
    if (existingKinds.contains(kind)) continue; // never overwrite

    // Try each candidate; keep the best one that passes both sig verify
    // and the kind-specific parser.
    Map<String, dynamic>? best;
    var bestTagCount = -1;
    for (final ev in entry.value) {
      Event? event;
      try {
        event = Event.fromMap(ev);
      } on Object {
        continue; // bad sig — skip
      }
      try {
        await _exerciseParser(event);
      } on Object {
        continue; // parser threw — skip
      }
      final tagCount = (ev['tags'] as List).length;
      if (tagCount > bestTagCount) {
        best = ev;
        bestTagCount = tagCount;
      }
    }

    if (best != null) {
      existing[kind.toString()] = best;
      added.add(kind);
    } else {
      skipped[kind] = 'no event passed both sig + parser';
    }
  }

  // Pretty-print and write back. Sort keys numerically.
  final sortedKinds = existing.keys.toList()
    ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  final ordered = <String, dynamic>{};
  for (final k in sortedKinds) {
    ordered[k] = existing[k];
  }
  const encoder = JsonEncoder.withIndent('  ');
  await samples.writeAsString('${encoder.convert(ordered)}\n');

  print('Added ${added.length} new kinds to $_samplesPath:');
  added.sort();
  for (final k in added) {
    print('  kind ${k.toString().padLeft(5)}');
  }
  if (skipped.isNotEmpty) {
    print('\nSkipped:');
    skipped.forEach((k, why) {
      print('  kind ${k.toString().padLeft(5)} — $why');
    });
  }
  print('\nTotal kinds now covered: ${ordered.length}');
}

/// Mirrors `tool/validate_captured.dart`'s dispatch but throws (rather
/// than catching) so we can use exception success as the selection
/// criterion.
Future<void> _exerciseParser(Event event) async {
  switch (event.kind) {
    case 0:
      try {
        await DnsIdentifier.parse(event);
      } on Object {
        // kind-0 without nip05 is fine; treat as happy-path
      }
      return;
    case 1:
    case 11:
    case 12:
      Note.parse(event);
      return;
    case 3:
      FollowList.parse(event);
      return;
    case 5:
      Deletion.parse(event);
      return;
    case 6:
    case 16:
      Repost.parse(event);
      return;
    case 7:
      Reaction.parse(event);
      return;
    case 8:
      Badge.parseAward(event);
      return;
    case 1059:
      return;
    case 1063:
      FileMetadata.parse(event);
      return;
    case 1111:
      Comment.parse(event);
      return;
    case 1985:
      Label.parse(event);
      return;
    case 4550:
      ModeratedCommunity.parseApproval(event);
      return;
    case 9734:
      Zap.parseRequest(event);
      return;
    case 9735:
      Zap.parseReceipt(event);
      return;
    case 10000:
    case 10001:
    case 30000:
    case 30001:
      await UserList.parse(
        event,
        secretKey:
            '0000000000000000000000000000000000000000000000000000000000000001',
      );
      return;
    case 10002:
      RelayList.parse(event);
      return;
    case 10008:
    case 30008:
      Badge.parseProfileBadges(event);
      return;
    case 24133:
      NostrConnect.parse(event);
      return;
    case 27235:
      HttpAuth.parse(event);
      return;
    case 30009:
      Badge.parseDefinition(event);
      return;
    case 30023:
    case 30024:
      Article.parse(event);
      return;
    case 30311:
      LiveActivity.parse(event);
      return;
    case 30315:
      UserStatus.parse(event);
      return;
    case 31989:
      AppHandler.parseRecommendation(event);
      return;
    case 31990:
      AppHandler.parseHandlerInfo(event);
      return;
    case 34550:
      ModeratedCommunity.parseCommunity(event);
      return;
    case 39000:
      Group.parseMetadata(event);
      return;
    case 39001:
      Group.parseAdmins(event);
      return;
    case 39002:
      Group.parseMembers(event);
      return;
    default:
      return;
  }
}
