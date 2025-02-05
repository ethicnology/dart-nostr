import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

const privkey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const pubkey =
    '0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db';

/// Unit Tests for Nip9
void main() {
  test('toTags should convert event IDs to tags', () {
    final List<String> eventIds = ["event1", "event2"];
    final List<List<String>> expectedTags = [
      ["e", "event1"],
      ["e", "event2"]
    ];
    expect(Nip9.toTags(eventIds), equals(expectedTags));
  });

  test('tagsToList should extract event IDs from tags', () {
    final List<List<String>> tags = [
      ["e", "event1"],
      ["e", "event2"]
    ];
    final List<String> expectedEventIds = ["event1", "event2"];
    expect(Nip9.tagsToList(tags), equals(expectedEventIds));
  });

  test('encode should create a valid Event object', () {
    final List<String> eventIds = ["event1", "event2"];
    const String content = "Reason";

    final Event event = Nip9.encode(eventIds, content, pubkey, privkey);
    expect(event.kind, equals(5));
    expect(
        event.tags,
        equals([
          ["e", "event1"],
          ["e", "event2"]
        ]));
    expect(event.content, equals(content));
    expect(event.pubkey, equals(pubkey));
  });

  test('decode should convert a valid Event to a DeleteEvent', () {
    final Event event = Event.from(
      kind: 5,
      tags: [
        ["e", "event1"],
        ["e", "event2"]
      ],
      content: "Reason",
      pubkey: pubkey,
      privkey: privkey,
    );
    final Nip9DeletionRequest deleteEvent = Nip9.decode(event);
    expect(deleteEvent.pubkey, equals(pubkey));
    expect(deleteEvent.deleteEvents, equals(["event1", "event2"]));
    expect(deleteEvent.reason, equals("Reason"));
  });
}
