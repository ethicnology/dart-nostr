import 'dart:convert';
import 'package:nostr/nostr.dart';
import 'package:nostr/src/crypto/nip_004.dart';

/// Lists
class Nip51 {
  static List<List<String>> peoplesToTags(List<People> items) {
    final List<List<String>> result = [];
    for (final People item in items) {
      result.add([
        "p",
        item.pubkey,
        item.mainRelay ?? "",
        item.petName ?? "",
        item.aliasPubKey ?? "",
      ]);
    }
    return result;
  }

  static List<List<String>> bookmarksToTags(List<String> items) {
    final List<List<String>> result = [];
    for (final String item in items) {
      result.add(["e", item]);
    }
    return result;
  }

  static String peoplesToContent(
      List<People> items, String privkey, String pubkey) {
    final list = [];
    for (final item in items) {
      list.add([
        'p',
        item.pubkey,
        item.mainRelay ?? "",
        item.petName ?? "",
        item.aliasPubKey ?? "",
      ]);
    }
    final String content = json.encode(list);
    return nip4cipher(privkey, '02$pubkey', content, cipher: true);
  }

  static String bookmarksToContent(
    List<String> items,
    String privkey,
    String pubkey,
  ) {
    final list = [];
    for (final item in items) {
      list.add(['e', item]);
    }
    final String content = json.encode(list);
    return nip4cipher(privkey, '02$pubkey', content, cipher: true);
  }

  static Map<String, List> fromContent(
      String content, String privkey, String pubkey) {
    final List<People> people = [];
    final List<String> bookmarks = [];
    final int ivIndex = content.indexOf("?iv=");
    if (ivIndex <= 0) {
      throw Exception("Invalid content, could not get ivIndex: $content");
    }
    final String iv =
        content.substring(ivIndex + "?iv=".length, content.length);
    final String encString = content.substring(0, ivIndex);
    final String deContent =
        nip4cipher(privkey, "02$pubkey", encString, cipher: false, nonce: iv);
    for (final List tag in json.decode(deContent)) {
      if (tag[0] == "p") {
        people.add(People(tag[1], tag.length > 2 ? tag[2] : "",
            tag.length > 3 ? tag[3] : "", tag.length > 4 ? tag[4] : ""));
      } else if (tag[0] == "e") {
        // bookmark
        bookmarks.add(tag[1]);
      }
    }
    return {"people": people, "bookmarks": bookmarks};
  }

  static Event createMutePeople(
    List<People> items,
    List<People> encryptedItems,
    String privkey,
    String pubkey,
  ) {
    return Event.from(
      kind: 10000,
      tags: peoplesToTags(items),
      content: peoplesToContent(encryptedItems, privkey, pubkey),
      privkey: privkey,
    );
  }

  static Event createPinEvent(List<String> items, List<String> encryptedItems,
      String privkey, String pubkey) {
    return Event.from(
        kind: 10001,
        tags: bookmarksToTags(items),
        content: bookmarksToContent(encryptedItems, privkey, pubkey),
        privkey: privkey);
  }

  static Event createCategorizedPeople(String identifier, List<People> items,
      List<People> encryptedItems, String privkey, String pubkey) {
    final List<List<String>> tags = peoplesToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
        kind: 30000,
        tags: tags,
        content: peoplesToContent(encryptedItems, privkey, pubkey),
        privkey: privkey);
  }

  static Event createCategorizedBookmarks(String identifier, List<String> items,
      List<String> encryptedItems, String privkey, String pubkey) {
    final List<List<String>> tags = bookmarksToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
        kind: 30001,
        tags: tags,
        content: bookmarksToContent(encryptedItems, privkey, pubkey),
        privkey: privkey);
  }

  static Lists getLists(Event event, String privkey) {
    if (event.kind != 10000 &&
        event.kind != 10001 &&
        event.kind != 30000 &&
        event.kind != 30001) {
      throw Exception("${event.kind} is not nip51 compatible");
    }
    String identifier = "";
    final List<People> people = [];
    final List<String> bookmarks = [];
    for (final List tag in event.tags) {
      if (tag[0] == "p") {
        people.add(People(tag[1], tag.length > 2 ? tag[2] : "",
            tag.length > 3 ? tag[3] : "", tag.length > 4 ? tag[4] : ""));
      }
      if (tag[0] == "e") {
        bookmarks.add(tag[1]);
      }
      if (tag[0] == "d") identifier = tag[1];
    }
    final pubkey = Keychain(privkey).public;
    final Map content = Nip51.fromContent(event.content, privkey, pubkey);
    people.addAll(content["people"]);
    bookmarks.addAll(content["bookmarks"]);
    if (event.kind == 10000) identifier = "Mute";
    if (event.kind == 10001) identifier = "Pin";

    return Lists(event.pubkey, identifier, people, bookmarks);
  }
}

///
class People {
  String pubkey;
  String? mainRelay;
  String? petName;
  String? aliasPubKey;

  /// Default constructor
  People(this.pubkey, this.mainRelay, this.petName, this.aliasPubKey);
}

class Lists {
  String owner;

  String identifier;

  List<People> people;

  List<String> bookmarks;

  /// Default constructor
  Lists(this.owner, this.identifier, this.people, this.bookmarks);
}
