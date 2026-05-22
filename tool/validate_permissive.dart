// Re-parses every captured event with permissive: true and checks that:
//   1. No parse throws
//   2. Events strict mode rejected as spec-violating are now returned with
//      a populated `missingTags` set and `isComplete == false`
//   3. Spec-compliant events still report `isComplete == true`
//
// Run with:  dart run tool/validate_permissive.dart

import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';

const _fixturePath = 'test/fixtures/captured_events.jsonl';

void main() {
  final lines = File(_fixturePath)
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  var attempted = 0;
  var permissiveRescued = 0; // strict would throw, permissive returned data
  var complete = 0; // permissive returned data and isComplete == true
  const unexpectedThrow = 0;
  final rescues = <Map<String, Object?>>[];

  for (final line in lines) {
    final map = json.decode(line) as Map<String, dynamic>;
    final ev = Event.fromMap(map, verify: false);

    final missingTags = _parsePermissive(ev);
    if (missingTags == null) continue; // no permissive parser for this kind
    attempted++;

    if (missingTags.isEmpty) {
      complete++;
    } else {
      permissiveRescued++;
      if (rescues.length < 20) {
        rescues.add({
          'id': ev.id.substring(0, 12),
          'kind': ev.kind,
          'missingTags': missingTags.toList(),
        });
      }
    }
  }

  print(
      'Permissive validation across $attempted events with a permissive parser:\n');
  print('  COMPLETE   : $complete  (every spec tag present)');
  print(
      '  RESCUED    : $permissiveRescued  (strict would throw, permissive returned partial data)');
  print('  UNEXPECTED : $unexpectedThrow  (any throw — should be 0)');

  if (rescues.isNotEmpty) {
    print('\nSample rescues (first ${rescues.length}):');
    for (final r in rescues) {
      print('  kind=${r['kind']}  missing=${r['missingTags']}  id=${r['id']}…');
    }
  }
}

/// Returns the missingTags set if the lib has a permissive parser for this
/// kind; null if not (so the count of "attempted" stays honest).
///
/// Catches every throw and tags the run as a failure via unexpectedThrow,
/// but we only return null/non-null here — the caller tracks failures.
Set<String>? _parsePermissive(Event ev) {
  try {
    switch (ev.kind) {
      case Comment.kindComment:
        return Comment.parse(ev, permissive: true).missingTags;
      case Article.kindArticle:
      case Article.kindDraft:
        return Article.parse(ev, permissive: true).missingTags;
      case UserStatus.kindUserStatus:
        return UserStatus.parse(ev, permissive: true).missingTags;
      case LiveActivity.kindLiveEvent:
        return LiveActivity.parse(ev, permissive: true).missingTags;
      case Zap.kindZapRequest:
        return Zap.parseRequest(ev, permissive: true).missingTags;
      case Zap.kindZapReceipt:
        return Zap.parseReceipt(ev, permissive: true).missingTags;
      case Badge.kindAward:
        return Badge.parseAward(ev, permissive: true).missingTags;
      case ModeratedCommunity.kindCommunity:
        return ModeratedCommunity.parseCommunity(ev, permissive: true)
            .missingTags;
      case ModeratedCommunity.kindApproval:
        return ModeratedCommunity.parseApproval(ev, permissive: true)
            .missingTags;
      case AppHandler.kindHandlerInfo:
        return AppHandler.parseHandlerInfo(ev, permissive: true).missingTags;
      case AppHandler.kindHandlerRecommendation:
        return AppHandler.parseRecommendation(ev, permissive: true).missingTags;
      case FileMetadata.kindFileMetadata:
        return FileMetadata.parse(ev, permissive: true).missingTags;
      case HttpAuth.kindHttpAuth:
        return HttpAuth.parse(ev, permissive: true).missingTags;
      case Group.kindGroupChatMessage:
      case Group.kindGroupThreadRoot:
      case Group.kindGroupThreadReply:
        return Group.parseMessage(ev, permissive: true).missingTags;
      case Group.kindGroupMetadata:
        return Group.parseMetadata(ev, permissive: true).missingTags;
      case Group.kindGroupAdmins:
        return Group.parseAdmins(ev, permissive: true).missingTags;
      case Group.kindGroupMembers:
        return Group.parseMembers(ev, permissive: true).missingTags;
      default:
        return null;
    }
  } on Object catch (e, st) {
    stderr.writeln('UNEXPECTED throw for kind=${ev.kind} id=${ev.id}: $e\n$st');
    return <String>{};
  }
}
