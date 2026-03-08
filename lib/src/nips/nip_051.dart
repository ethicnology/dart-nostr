import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Lists
///
/// Mute, pin, categorized people, and categorized bookmarks, using NIP-44
/// encryption for private content.
class Nip51 {
  static List<List<String>> contactsToTags(List<Contact> items) {
    final List<List<String>> result = [];
    for (final Contact item in items) {
      result.add([
        "p",
        item.pubkey,
        item.mainRelay ?? "",
        item.petName ?? "",
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

  static Future<String> contactsToContent(
    List<Contact> items,
    String secretKey,
    String pubkey,
  ) async {
    final list = [];
    for (final item in items) {
      list.add([
        'p',
        item.pubkey,
        item.mainRelay ?? "",
        item.petName ?? "",
      ]);
    }
    final String content = json.encode(list);
    return Nip44.encrypt(
      plaintext: content,
      senderSecretKey: secretKey,
      recipientPublicKey: pubkey,
    );
  }

  static Future<String> bookmarksToContent(
    List<String> items,
    String secretKey,
    String pubkey,
  ) async {
    final list = [];
    for (final item in items) {
      list.add(['e', item]);
    }
    final String content = json.encode(list);
    return Nip44.encrypt(
      plaintext: content,
      senderSecretKey: secretKey,
      recipientPublicKey: pubkey,
    );
  }

  static Future<Map<String, List>> fromContent(
    String content,
    String secretKey,
    String pubkey,
  ) async {
    final List<Contact> contacts = [];
    final List<String> bookmarks = [];
    final String decrypted = await Nip44.decrypt(
      payload: content,
      recipientSecretKey: secretKey,
      senderPublicKey: pubkey,
    );
    for (final List tag in json.decode(decrypted)) {
      if (tag[0] == "p") {
        contacts.add(Contact(
          tag[1],
          tag.length > 2 ? tag[2] : "",
          tag.length > 3 ? tag[3] : "",
        ));
      } else if (tag[0] == "e") {
        bookmarks.add(tag[1]);
      }
    }
    return {"contacts": contacts, "bookmarks": bookmarks};
  }

  static Future<Event> createMutePeople(
    List<Contact> items,
    List<Contact> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    return Event.from(
      kind: 10000,
      tags: contactsToTags(items),
      content: await contactsToContent(encryptedItems, secretKey, pubkey),
      secretKey: secretKey,
    );
  }

  static Future<Event> createPinEvent(
    List<String> items,
    List<String> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    return Event.from(
      kind: 10001,
      tags: bookmarksToTags(items),
      content: await bookmarksToContent(encryptedItems, secretKey, pubkey),
      secretKey: secretKey,
    );
  }

  static Future<Event> createCategorizedPeople(
    String identifier,
    List<Contact> items,
    List<Contact> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    final List<List<String>> tags = contactsToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
      kind: 30000,
      tags: tags,
      content: await contactsToContent(encryptedItems, secretKey, pubkey),
      secretKey: secretKey,
    );
  }

  static Future<Event> createCategorizedBookmarks(
    String identifier,
    List<String> items,
    List<String> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    final List<List<String>> tags = bookmarksToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
      kind: 30001,
      tags: tags,
      content: await bookmarksToContent(encryptedItems, secretKey, pubkey),
      secretKey: secretKey,
    );
  }

  static Future<UserList> getLists(Event event, String secretKey) async {
    if (event.kind != 10000 &&
        event.kind != 10001 &&
        event.kind != 30000 &&
        event.kind != 30001) {
      throw Exception("${event.kind} is not nip51 compatible");
    }
    String identifier = "";
    final List<Contact> contacts = [];
    final List<String> bookmarks = [];
    for (final List tag in event.tags) {
      if (tag[0] == "p") {
        contacts.add(Contact(
          tag[1],
          tag.length > 2 ? tag[2] : "",
          tag.length > 3 ? tag[3] : "",
        ));
      }
      if (tag[0] == "e") {
        bookmarks.add(tag[1]);
      }
      if (tag[0] == "d") identifier = tag[1];
    }
    final pubkey = Keys(secretKey).public;
    final Map content =
        await Nip51.fromContent(event.content, secretKey, pubkey);
    contacts.addAll(content["contacts"] as List<Contact>);
    bookmarks.addAll(content["bookmarks"] as List<String>);
    if (event.kind == 10000) identifier = "Mute";
    if (event.kind == 10001) identifier = "Pin";

    return UserList(event.pubkey, identifier, contacts, bookmarks);
  }
}

/// A contact entry in a NIP-51 list.
///
/// Tag format: ["p", pubkey, relay?, petname?]
class Contact {
  String pubkey;
  String? mainRelay;
  String? petName;

  Contact(this.pubkey, this.mainRelay, this.petName);
}

/// The decoded contents of a NIP-51 list event.
class UserList {
  String owner;
  String identifier;
  List<Contact> contacts;
  List<String> bookmarks;

  UserList(this.owner, this.identifier, this.contacts, this.bookmarks);
}

typedef Lists = Nip51;
