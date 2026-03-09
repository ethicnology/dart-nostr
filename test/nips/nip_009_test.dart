import 'dart:convert';
import 'dart:io';

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
// pubkey derived from secretKey above
const pubkey =
    '981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b';

void main() {
  test('toTags converts event IDs to e tags', () {
    final tags = Nip9.toTags(["event1", "event2"]);
    expect(tags, equals([["e", "event1"], ["e", "event2"]]));
  });

  test('toATags converts coordinates to a tags', () {
    final tags = Nip9.toATags(["30023:$pubkey:my-article"]);
    expect(tags, equals([["a", "30023:$pubkey:my-article"]]));
  });

  test('toKTags converts kind numbers to k tags', () {
    final tags = Nip9.toKTags([1, 30023]);
    expect(tags, equals([["k", "1"], ["k", "30023"]]));
  });

  test('tagsToList extracts event IDs from e tags', () {
    final tags = [
      ["e", "event1"],
      ["a", "30023:$pubkey:d"],
      ["e", "event2"],
    ];
    expect(Nip9.tagsToList(tags), equals(["event1", "event2"]));
  });

  test('tagsToAddressableCoords extracts coords from a tags', () {
    final tags = [
      ["e", "event1"],
      ["a", "30023:$pubkey:article"],
    ];
    expect(Nip9.tagsToAddressableCoords(tags),
        equals(["30023:$pubkey:article"]));
  });

  test('encode creates a valid deletion event with e tags only', () {
    final event = Nip9.request(eventIds: ["event1", "event2"], content: "Reason", secretKey: secretKey);
    expect(event.kind, equals(5));
    expect(event.tags, equals([["e", "event1"], ["e", "event2"]]));
    expect(event.content, equals("Reason"));
  });

  test('encode supports a tags and k tags', () {
    const coord = "30023:$pubkey:my-post";
    final event = Nip9.request(
      eventIds: ["event1"],
      content: "Reason",
      secretKey: secretKey,
      addressableCoords: [coord],
      kinds: [1, 30023],
    );
    expect(event.kind, equals(5));
    expect(event.tags[0], equals(["e", "event1"]));
    expect(event.tags[1], equals(["a", coord]));
    expect(event.tags[2], equals(["k", "1"]));
    expect(event.tags[3], equals(["k", "30023"]));
  });

  test('decode converts a valid event to DeletionRequest', () {
    const coord = "30023:$pubkey:my-post";
    final event = Event.from(
      kind: 5,
      tags: [
        ["e", "event1"],
        ["e", "event2"],
        ["a", coord],
      ],
      content: "Reason",
      secretKey: secretKey,
    );
    final DeletionRequest req = Nip9.parse(event);
    expect(req.pubkey, equals(pubkey));
    expect(req.eventIds, equals(["event1", "event2"]));
    expect(req.addressableCoords, equals([coord]));
    expect(req.reason, equals("Reason"));
  });

  test('rust-nostr deletion vector', () {
    final vectors = json.decode(
        File('test/fixtures/rust_nostr_vectors.json').readAsStringSync());
    final nip09 = vectors['nip09'];
    final event = Nip9.request(
      eventIds: [nip09['event_id']],
      addressableCoords: [nip09['coordinate']],
      content: nip09['reason'],
      secretKey: secretKey,
    );
    expect(event.kind, 5);
    expect(event.tags[0], ['e', nip09['event_id']]);
    expect(event.tags[1], ['a', nip09['coordinate']]);
    expect(event.content, nip09['reason']);
  });
}
