// Connects to popular Nostr relays, captures recent events of every kind
// the library knows about, and writes them as JSONL to
// `test/fixtures/captured_events.jsonl`. Each line is one raw event map.
//
// Run with:  dart run tool/capture_events.dart
//
// Used by `tool/validate_captured.dart` and by the `relay_capture_test.dart`
// suite to regression-test the lib against real-world relay output.
//
// NOTE: this script lives outside `lib/` so it can `import 'dart:io'` for the
// WebSocket client. The library itself stays transport-agnostic.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Relays to capture from. Chosen for breadth of kinds + uptime.
///
/// General-purpose relays first (high traffic, mix of kinds); then
/// specialty relays (NIP-29 groups, communities) so we surface kinds
/// the general relays don't store.
const _relays = <String>[
  // General-purpose
  'wss://relay.damus.io',
  'wss://nos.lol',
  'wss://relay.nostr.band',
  'wss://relay.primal.net',
  'wss://nostr.wine',
  'wss://nostr.mom',
  'wss://relay.snort.social',
  'wss://offchain.pub',
  'wss://nostr-pub.wellorder.net',
  // NIP-29 relay-based groups
  'wss://groups.0xchat.com',
  'wss://relay.0xchat.com',
  'wss://relay29.notoshi.win',
];

/// All event kinds the library has explicit parse/create helpers for, plus a
/// few wildcard buckets so we exercise unknown-kind handling too.
const _kinds = <int>[
  0, // metadata (NIP-01)
  1, // text note (NIP-01)
  3, // follow list (NIP-02)
  5, // deletion (NIP-09)
  6, // repost kind-1 (NIP-18)
  7, // reaction (NIP-25)
  8, // badge award (NIP-58)
  11, // group thread root (NIP-29)
  12, // group thread reply (NIP-29)
  13, // seal (NIP-59)
  16, // generic repost (NIP-18)
  20, // picture-first feed (NIP-68 — not yet implemented; capture for inventory)
  1059, // gift wrap (NIP-59)
  1063, // file metadata (NIP-94)
  1111, // comment (NIP-22)
  1311, // live chat (NIP-53)
  1985, // label (NIP-32)
  4550, // community approval (NIP-72)
  9734, // zap request (NIP-57)
  9735, // zap receipt (NIP-57)
  9802, // highlight (NIP-84 — not yet implemented)
  10000, // mute list (NIP-51)
  10001, // pin list (NIP-51)
  10002, // relay list (NIP-65)
  10008, // profile badges new (NIP-58)
  22242, // auth (NIP-42)
  24133, // nostr connect (NIP-46)
  27235, // HTTP auth (NIP-98)
  30000, // categorized people (NIP-51)
  30001, // categorized bookmarks (NIP-51)
  30008, // profile badges legacy (NIP-58)
  30009, // badge definition (NIP-58)
  30023, // long-form (NIP-23)
  30024, // long-form draft (NIP-23)
  30311, // live activity (NIP-53)
  30315, // user status (NIP-38)
  31989, // app handler recommendation (NIP-89)
  31990, // app handler info (NIP-89)
  34550, // community definition (NIP-72)
  39000, // group metadata (NIP-29)
  39001, // group admins (NIP-29)
  39002, // group members (NIP-29)
];

/// Kinds we specifically want to exercise but that broad subscriptions
/// rarely surface. We run a second pass with a tight filter per kind to
/// improve coverage of the code paths I changed in v2.1.
const _targetedKinds = <int>[
  8, // NIP-58 badge award
  11, // NIP-29 group thread root
  12, // NIP-29 group thread reply
  16, // NIP-18 generic repost (non-kind-1)
  1059, // NIP-59 gift wrap
  1063, // NIP-94 file metadata
  1111, // NIP-22 comments
  4550, // NIP-72 community approval
  9734, // NIP-57 zap requests
  9802, // NIP-84 highlights
  10001, // NIP-51 pinned
  10008, // NIP-58 profile badges (current spec)
  30001, // NIP-51 categorized bookmarks
  30008, // NIP-58 profile badges (legacy — backward-compat path)
  30009, // NIP-58 badge definitions
  30023, // NIP-23 long-form
  30024, // NIP-23 long-form draft
  31989, // NIP-89 app handler recommendation
  34550, // NIP-72 communities
  39000, // NIP-29 group metadata
  39001, // NIP-29 group admins
  39002, // NIP-29 group members
];

const _limitPerRelay = 200;
const _targetedLimitPerRelayPerKind = 5;
const _connectTimeout = Duration(seconds: 8);
const _readTimeout = Duration(seconds: 12);

/// Per-kind ceiling on the final fixture. NIP-29 group relays return
/// thousands of 39000/39001/39002 events; we don't need all of them to
/// validate parsing — 30 per kind is plenty and keeps the JSONL file
/// commitable.
const _maxEventsPerKind = 30;

Future<void> main() async {
  print('Capturing events from ${_relays.length} relays, '
      '${_kinds.length} kinds, $_limitPerRelay events per relay\n');

  // Dedup by event id across all relays.
  final byId = <String, Map<String, dynamic>>{};

  // Pass 1: broad capture across all kinds.
  await Future.wait(_relays.map(_captureFromRelay).map((f) async {
    try {
      final events = await f;
      for (final ev in events) {
        final id = ev['id'] as String?;
        if (id == null) continue;
        byId.putIfAbsent(id, () => ev);
      }
    } on Object catch (e) {
      stderr.writeln('relay capture failed: $e');
    }
  }));

  // Pass 2: targeted capture for kinds that broad subs rarely surface.
  print('\nTargeted pass for rare kinds: $_targetedKinds');
  await Future.wait(_relays.map((relay) async {
    try {
      final events = await _captureTargetedFromRelay(relay, _targetedKinds);
      for (final ev in events) {
        final id = ev['id'] as String?;
        if (id == null) continue;
        byId.putIfAbsent(id, () => ev);
      }
    } on Object catch (e) {
      stderr.writeln('targeted capture from $relay failed: $e');
    }
  }));

  // Bucket per kind, then cap each bucket — NIP-29 group relays return
  // thousands of 39000/39001/39002 events; we only need a representative
  // sample to validate parsing.
  final byKind = <int, List<Map<String, dynamic>>>{};
  for (final ev in byId.values) {
    final kind = ev['kind'] as int;
    byKind.putIfAbsent(kind, () => []).add(ev);
  }
  for (final list in byKind.values) {
    // Sort deterministically before truncation so the same input always
    // produces the same fixture.
    list.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    if (list.length > _maxEventsPerKind) {
      list.removeRange(_maxEventsPerKind, list.length);
    }
  }

  // Write JSONL — stable order by kind then by id so diffs are readable.
  const outPath = 'test/fixtures/captured_events.jsonl';
  final file = File(outPath);
  await file.parent.create(recursive: true);
  final sink = file.openWrite();
  final entries = byKind.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  var written = 0;
  for (final entry in entries) {
    for (final ev in entry.value) {
      sink.writeln(json.encode(ev));
      written++;
    }
  }
  await sink.close();

  print('\nWrote $written events across ${byKind.length} kinds → $outPath'
      ' (capped at $_maxEventsPerKind per kind)');
  print('\nKind breakdown:');
  for (final entry in entries) {
    print('  kind ${entry.key.toString().padLeft(5)}: '
        '${entry.value.length} events');
  }

  // Coverage check: which requested kinds had ZERO events from any relay?
  final missing = _kinds.where((k) => !byKind.containsKey(k)).toList();
  if (missing.isNotEmpty) {
    print('\nNo events captured for kinds: $missing');
    print('(rare or relay-specific kinds — expected for some)');
  }
}

/// Subscribes to [relay] and pulls up to [_limitPerRelay] events covering
/// our kinds-of-interest, then closes.
Future<List<Map<String, dynamic>>> _captureFromRelay(String relay) async {
  print('→ $relay');
  WebSocket? ws;
  final events = <Map<String, dynamic>>[];

  try {
    ws = await WebSocket.connect(relay).timeout(_connectTimeout);
  } on Object catch (e) {
    print('  connect failed: $e');
    return events;
  }

  final eose = Completer<void>();
  // Random-ish sub id; doesn't need to be cryptographic.
  final subId = 'cap-${DateTime.now().millisecondsSinceEpoch}';

  final filter = <String, dynamic>{
    'kinds': _kinds,
    'limit': _limitPerRelay,
  };
  final req = json.encode(['REQ', subId, filter]);

  ws.listen(
    (raw) {
      if (raw is! String) return;
      List<dynamic> msg;
      try {
        msg = json.decode(raw) as List<dynamic>;
      } on Object {
        return;
      }
      if (msg.isEmpty) return;
      final type = msg[0];
      if (type == 'EVENT' && msg.length >= 3) {
        final event = msg[2];
        if (event is Map<String, dynamic>) {
          events.add(event);
          if (events.length >= _limitPerRelay && !eose.isCompleted) {
            eose.complete();
          }
        }
      } else if (type == 'EOSE') {
        if (!eose.isCompleted) eose.complete();
      } else if (type == 'NOTICE') {
        // Non-fatal — relays sometimes complain about overly broad filters.
        print('  NOTICE from $relay: ${msg.length > 1 ? msg[1] : ''}');
      }
    },
    onError: (e) {
      if (!eose.isCompleted) eose.completeError(e);
    },
    onDone: () {
      if (!eose.isCompleted) eose.complete();
    },
    cancelOnError: true,
  );

  ws.add(req);

  try {
    await eose.future.timeout(_readTimeout);
  } on TimeoutException {
    // Some relays never send EOSE for broad subs; that's fine — we keep
    // whatever arrived inside the read window.
  } on Object catch (e) {
    print('  stream error: $e');
  }

  try {
    ws.add(json.encode(['CLOSE', subId]));
    await ws.close().timeout(const Duration(seconds: 2));
  } on Object {
    // ignore
  }

  print('  captured ${events.length} events from $relay');
  return events;
}

/// Like [_captureFromRelay] but opens a separate REQ per kind, asking for a
/// few events of that kind specifically. Surfaces rare kinds that get
/// drowned out by kind-1 traffic in the broad pass.
Future<List<Map<String, dynamic>>> _captureTargetedFromRelay(
  String relay,
  List<int> kinds,
) async {
  WebSocket? ws;
  final events = <Map<String, dynamic>>[];
  try {
    ws = await WebSocket.connect(relay).timeout(_connectTimeout);
  } on Object {
    return events;
  }

  // Pending subs we still expect EOSE from.
  final pending = <String>{};
  final allDone = Completer<void>();

  ws.listen(
    (raw) {
      if (raw is! String) return;
      List<dynamic> msg;
      try {
        msg = json.decode(raw) as List<dynamic>;
      } on Object {
        return;
      }
      if (msg.isEmpty) return;
      final type = msg[0];
      if (type == 'EVENT' && msg.length >= 3) {
        final event = msg[2];
        if (event is Map<String, dynamic>) events.add(event);
      } else if (type == 'EOSE' && msg.length >= 2) {
        pending.remove(msg[1]);
        if (pending.isEmpty && !allDone.isCompleted) allDone.complete();
      }
    },
    onDone: () {
      if (!allDone.isCompleted) allDone.complete();
    },
    cancelOnError: true,
  );

  for (var i = 0; i < kinds.length; i++) {
    final subId = 'tgt-$i-${DateTime.now().millisecondsSinceEpoch}';
    pending.add(subId);
    final filter = <String, dynamic>{
      'kinds': [kinds[i]],
      'limit': _targetedLimitPerRelayPerKind,
    };
    ws.add(json.encode(['REQ', subId, filter]));
  }

  try {
    await allDone.future.timeout(_readTimeout);
  } on TimeoutException {
    // Keep whatever arrived.
  }

  for (final id in pending) {
    try {
      ws.add(json.encode(['CLOSE', id]));
    } on Object {
      // ignore
    }
  }
  try {
    await ws.close().timeout(const Duration(seconds: 2));
  } on Object {
    // ignore
  }

  return events;
}
