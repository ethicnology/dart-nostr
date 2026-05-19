// Replays `test/fixtures/captured_events.jsonl` through the library and
// reports any decoding failure. Real-world relay output is the harshest
// fuzzer for a Nostr lib — if a real event makes any parse method throw an
// UNEXPECTED exception, that's a bug we want to surface.
//
// Run with:  dart run tool/validate_captured.dart
//
// Classification:
//   PASS         — Event constructed (sig verified) and the kind-specific
//                  parse method (if any) returned successfully.
//   SPEC_REJECT  — Event constructed but parse threw a NostrException
//                  (MissingTagException, InvalidKindException, …). This is
//                  ACCEPTABLE — it means the parser correctly refused
//                  malformed real-world input.
//   SIG_FAIL     — Event.fromMap(verify: true) rejected the event because
//                  id or signature didn't validate. Usually a relay-side
//                  issue, not ours.
//   BUG          — Anything else (RangeError, TypeError, FormatException,
//                  etc). This is our problem.

import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';

const _fixturePath = 'test/fixtures/captured_events.jsonl';

// A throwaway key the NIP-51 parser uses to attempt NIP-44 decryption. We
// don't own the captured-event authors' keys, so private list content will
// fail to decrypt — the parser is supposed to handle that gracefully.
const _throwawaySecretKey =
    '0000000000000000000000000000000000000000000000000000000000000001';

void main() async {
  final file = File(_fixturePath);
  if (!file.existsSync()) {
    stderr.writeln('No fixture at $_fixturePath. Run tool/capture_events.dart first.');
    exit(1);
  }

  final lines = file
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  var pass = 0;
  var sigFail = 0;
  var specReject = 0;
  var bug = 0;
  final bugs = <Map<String, dynamic>>[];
  final specRejects = <Map<String, dynamic>>[];
  final sigFails = <Map<String, dynamic>>[];
  // Track per-kind so we know which NIPs were exercised.
  final perKind = <int, _KindStats>{};

  for (final line in lines) {
    final Map<String, dynamic> map;
    try {
      map = json.decode(line) as Map<String, dynamic>;
    } on Object catch (e) {
      bug++;
      bugs.add({'phase': 'json-decode', 'error': '$e', 'line': line});
      continue;
    }

    final kind = map['kind'] as int? ?? -1;
    perKind.putIfAbsent(kind, _KindStats.new);

    // Step 1: construct + sig verify.
    final Event event;
    try {
      event = Event.fromMap(map);
    } on EventValidationException catch (e) {
      sigFail++;
      perKind[kind]!.sigFail++;
      sigFails.add({'kind': kind, 'id': map['id'], 'error': '$e'});
      continue;
    } on Object catch (e) {
      bug++;
      perKind[kind]!.bug++;
      bugs.add({
        'phase': 'Event.fromMap',
        'kind': kind,
        'id': map['id'],
        'error': '$e',
      });
      continue;
    }

    // Step 2: dispatch to the appropriate parser. No parser → still counts as
    // a pass for the construct-and-verify step.
    try {
      await _dispatch(event);
      pass++;
      perKind[kind]!.pass++;
    } on NostrException catch (e) {
      specReject++;
      perKind[kind]!.specReject++;
      specRejects.add({'kind': kind, 'id': event.id, 'error': '$e'});
    } on Object catch (e, st) {
      bug++;
      perKind[kind]!.bug++;
      bugs.add({
        'phase': 'parse',
        'kind': kind,
        'id': event.id,
        'error': '$e',
        'stack': st.toString().split('\n').take(3).join(' | '),
      });
    }
  }

  // Report.
  final total = lines.length;
  print('Validated $total captured events from $_fixturePath\n');
  print('  PASS         : $pass');
  print('  SPEC_REJECT  : $specReject  (parser correctly refused malformed input)');
  print('  SIG_FAIL     : $sigFail  (relay sent broken event)');
  print('  BUG          : $bug  (our code threw an unexpected exception)');
  print('');

  // Per-kind summary.
  print('Per-kind breakdown:');
  print('  kind   PASS  SPEC  SIG  BUG');
  final kinds = perKind.keys.toList()..sort();
  for (final k in kinds) {
    final s = perKind[k]!;
    print('  ${k.toString().padLeft(5)}  '
        '${s.pass.toString().padLeft(4)}  '
        '${s.specReject.toString().padLeft(4)}  '
        '${s.sigFail.toString().padLeft(3)}  '
        '${s.bug.toString().padLeft(3)}');
  }

  if (specRejects.isNotEmpty) {
    print('\nFirst 5 SPEC_REJECTs (expected — malformed real-world data):');
    for (final r in specRejects.take(5)) {
      print('  kind=${r['kind']}  ${r['error']}  (${r['id']})');
    }
  }

  if (sigFails.isNotEmpty) {
    print('\nFirst 5 SIG_FAILs:');
    for (final r in sigFails.take(5)) {
      print('  kind=${r['kind']}  (${r['id']})');
    }
  }

  if (bugs.isNotEmpty) {
    print('\nALL BUGs (these are real problems in dart-nostr):');
    for (final b in bugs) {
      print('  phase=${b['phase']}  kind=${b['kind']}  id=${b['id']}');
      print('    error: ${b['error']}');
      if (b['stack'] != null) print('    stack: ${b['stack']}');
    }
    exit(1);
  }

  print('\nNo bugs surfaced — all real-world events decoded cleanly.');
}

/// Routes [event] to the parser the library exposes for its kind. Kinds
/// with no parser are left alone — they pass on signature-verification
/// alone (Step 1 above).
Future<void> _dispatch(Event event) async {
  switch (event.kind) {
    case 0:
      // Kind 0 is JSON metadata; the lib doesn't ship a generic profile
      // parser. We do exercise the NIP-05 extractor when the field exists.
      try {
        await DnsIdentifier.parse(event);
      } on InvalidKindException {
        rethrow;
      } on Object {
        // The field is optional; missing nip05 yields a DeserializationException
        // wrapping any error. That's fine for validation.
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
      // Gift wrap content is encrypted to a specific recipient; we can't
      // unwrap without their key. Just verifying the envelope is enough.
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
      // NIP-51 parse is async and tries to decrypt with the given secret.
      // We don't have the owner's key, so private content will fail to
      // decrypt — the parser must handle that without throwing.
      await UserList.parse(event, secretKey: _throwawaySecretKey);
      return;
    case 10002:
      RelayList.parse(event);
      return;
    case 10008:
    case 30008:
      Badge.parseProfileBadges(event);
      return;
    case 22242:
      // NIP-42 has no plain parser; the validate() call requires the
      // expected relay+challenge so we can't exercise it here.
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
      // No parser for this kind — Step 1 (signature verify) is the entire
      // check.
      return;
  }
}

class _KindStats {
  int pass = 0;
  int specReject = 0;
  int sigFail = 0;
  int bug = 0;
}
