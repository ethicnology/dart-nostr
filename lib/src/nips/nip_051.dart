import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Lists — [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md)
///
/// Mute, pin, categorized people, and categorized bookmarks, using NIP-44
/// encryption for private content.
class Nip51 {
  /// Converts a list of [Contact]s to `["p", pubkey, relay, petname]` tags.
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

  /// Converts a list of event IDs to `["e", id]` tags.
  static List<List<String>> bookmarksToTags(List<String> items) {
    final List<List<String>> result = [];
    for (final String item in items) {
      result.add(["e", item]);
    }
    return result;
  }

  /// Encrypts a list of [Contact]s into NIP-44 ciphertext for event content.
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

  /// Encrypts a list of bookmark event IDs into NIP-44 ciphertext for event content.
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

  /// Decrypts encrypted NIP-51 list content into contacts and bookmarks.
  ///
  /// [content] is the NIP-44-encrypted event content.
  /// [secretKey] is the hex-encoded secret key for decryption.
  /// [pubkey] is the hex-encoded public key of the list owner.
  ///
  /// Returns a record with `contacts` and `bookmarks`.
  static Future<({List<Contact> contacts, List<String> bookmarks})> fromContent(
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
    return (contacts: contacts, bookmarks: bookmarks);
  }

  /// Creates a kind-10000 mute list event.
  ///
  /// [items] are the public contacts in the mute list (stored in tags).
  /// [encryptedItems] are the private contacts (encrypted in content).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [pubkey] is the hex-encoded public key of the list owner.
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

  /// Creates a kind-10001 pin list event.
  ///
  /// [items] are the public bookmarks (stored in tags).
  /// [encryptedItems] are the private bookmarks (encrypted in content).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [pubkey] is the hex-encoded public key of the list owner.
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

  /// Creates a kind-30000 categorized people list event.
  ///
  /// [identifier] is the `d` tag value naming the category.
  /// [items] are the public contacts (stored in tags).
  /// [encryptedItems] are the private contacts (encrypted in content).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [pubkey] is the hex-encoded public key of the list owner.
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

  /// Creates a kind-30001 categorized bookmarks list event.
  ///
  /// [identifier] is the `d` tag value naming the category.
  /// [items] are the public bookmarks (stored in tags).
  /// [encryptedItems] are the private bookmarks (encrypted in content).
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  /// [pubkey] is the hex-encoded public key of the list owner.
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

  /// Decodes a NIP-51 list event into a [UserList].
  ///
  /// Supports kinds 10000 (mute), 10001 (pin), 30000 (categorized people),
  /// and 30001 (categorized bookmarks).
  ///
  /// Throws [InvalidKindException] if the event kind is not one of the above.
  static Future<UserList> getLists(Event event, String secretKey) async {
    if (event.kind != 10000 &&
        event.kind != 10001 &&
        event.kind != 30000 &&
        event.kind != 30001) {
      throw InvalidKindException(event.kind, [10000, 10001, 30000, 30001]);
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
    final content =
        await Nip51.fromContent(event.content, secretKey, pubkey);
    contacts.addAll(content.contacts);
    bookmarks.addAll(content.bookmarks);
    if (event.kind == 10000) identifier = "Mute";
    if (event.kind == 10001) identifier = "Pin";

    return UserList(event.pubkey, identifier, contacts, bookmarks);
  }
}

/// A contact entry in a NIP-51 list.
///
/// Tag format: ["p", pubkey, relay?, petname?]
class Contact {
  /// The hex-encoded public key of the contact.
  String pubkey;

  /// The preferred relay URL for this contact (optional).
  String? mainRelay;

  /// A local petname for this contact (optional).
  String? petName;

  /// Creates a [Contact] with the given [pubkey], [mainRelay], and [petName].
  Contact(this.pubkey, this.mainRelay, this.petName);
}

/// The decoded contents of a NIP-51 list event.
class UserList {
  /// The public key of the list owner.
  String owner;

  /// The list identifier (category name, or "Mute"/"Pin" for non-categorized).
  String identifier;

  /// The contacts in this list.
  List<Contact> contacts;

  /// The bookmarked event IDs in this list.
  List<String> bookmarks;

  /// Creates a [UserList] with the given fields.
  UserList(this.owner, this.identifier, this.contacts, this.bookmarks);
}

typedef Lists = Nip51;
