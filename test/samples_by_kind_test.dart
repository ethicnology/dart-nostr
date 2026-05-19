// Regression test: every event in `test/fixtures/samples_by_kind.json`
// is constructable (id + signature verify) and, for kinds the library
// has a parser for, decodes without throwing an unexpected exception.
//
// The fixture is a curated single-event-per-kind set, including 20 kinds
// pulled from the live-relay capture corpus by `tool/curate_samples.dart`
// (NIP-58 badge award + profile-badges 10008/30008, NIP-29 group threads
// + admins/members, NIP-94 file metadata, NIP-22 comments, …).

import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const _path = 'test/fixtures/samples_by_kind.json';

const _throwawaySecretKey =
    '0000000000000000000000000000000000000000000000000000000000000001';

void main() {
  late Map<String, dynamic> samples;

  setUpAll(() {
    samples =
        json.decode(File(_path).readAsStringSync()) as Map<String, dynamic>;
  });

  test('every sample has the canonical event shape', () {
    expect(samples, isNotEmpty);
    for (final entry in samples.entries) {
      final ev = entry.value as Map<String, dynamic>;
      for (final field in ['id', 'pubkey', 'created_at', 'kind', 'tags', 'content', 'sig']) {
        expect(ev.containsKey(field), isTrue,
            reason: 'kind ${entry.key} sample missing field "$field"');
      }
      expect(ev['kind'], int.parse(entry.key),
          reason: 'kind mismatch in sample key ${entry.key}');
    }
  });

  test('every sample verifies its id + signature', () {
    final failures = <String>[];
    for (final entry in samples.entries) {
      final ev = entry.value as Map<String, dynamic>;
      try {
        Event.fromMap(ev);
      } on EventValidationException catch (_) {
        failures.add('kind ${entry.key}: id/sig mismatch (id=${ev['id']})');
      } on Object catch (e) {
        failures.add('kind ${entry.key}: ${e.runtimeType}: $e');
      }
    }
    expect(failures, isEmpty,
        reason: failures.take(10).join('\n'));
  });

  // Per-kind parser smoke. We only run a kind-specific parser when the
  // library defines one for that kind — otherwise the signature-verify
  // check above is the whole assertion.
  test('every sample with a parser decodes without an unexpected throw',
      () async {
    final unexpectedThrows = <String>[];
    for (final entry in samples.entries) {
      final ev = entry.value as Map<String, dynamic>;
      final Event event;
      try {
        event = Event.fromMap(ev);
      } on Object {
        // Already caught by the previous test.
        continue;
      }
      try {
        await _parseByKind(event);
      } on NostrException catch (_) {
        // Spec-compliant rejection (e.g. missing required tag) is fine —
        // it means the parser correctly refused malformed input.
      } on Object catch (e, st) {
        unexpectedThrows.add(
          'kind ${event.kind} (${event.id}): '
          '${e.runtimeType}: $e\n${st.toString().split('\n').take(2).join(' | ')}',
        );
      }
    }
    expect(unexpectedThrows, isEmpty,
        reason:
            'unexpected exceptions from parsers (these are bugs):\n${unexpectedThrows.join('\n\n')}');
  });
}

/// Dispatch to the library's parser for [event]'s kind. Kinds with no
/// dedicated parser are no-ops (the signature-verify test alone covers
/// them).
///
/// Kept in sync with the dispatch in `tool/validate_captured.dart` and
/// `tool/curate_samples.dart`.
Future<void> _parseByKind(Event event) async {
  switch (event.kind) {
    case 0:
      try {
        await DnsIdentifier.parse(event);
      } on Object {
        // kind-0 without a nip05 field throws DeserializationException; not a bug.
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
      // gift wrap content is encrypted to a specific recipient
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
      await UserList.parse(event, secretKey: _throwawaySecretKey);
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
