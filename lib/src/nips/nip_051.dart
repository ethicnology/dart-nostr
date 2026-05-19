import 'dart:convert';
import 'package:nostr/nostr.dart';

/// Lists — [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md)
///
/// Mute, pin, categorized people, and categorized bookmarks, using NIP-44
/// encryption for private content.
class UserList {
  /// Event kind for the mute list.
  static const int kindMuteList = 10000;

  /// Event kind for the pin list.
  static const int kindPinList = 10001;

  /// Event kind for categorized people lists.
  static const int kindCategorizedPeople = 30000;

  /// Event kind for categorized bookmark lists.
  static const int kindCategorizedBookmarks = 30001;

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
      recipientPubkey: pubkey,
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
      recipientPubkey: pubkey,
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
      senderPubkey: pubkey,
    );
    for (final List tag in json.decode(decrypted)) {
      if (tag.length < 2) continue;
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
  static Future<Event> mutePeople(
    List<Contact> items,
    List<Contact> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    return Event.from(
      kind: kindMuteList,
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
  static Future<Event> pinEvent(
    List<String> items,
    List<String> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    return Event.from(
      kind: kindPinList,
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
  static Future<Event> categorizedPeople(
    String identifier,
    List<Contact> items,
    List<Contact> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    final List<List<String>> tags = contactsToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
      kind: kindCategorizedPeople,
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
  static Future<Event> categorizedBookmarks(
    String identifier,
    List<String> items,
    List<String> encryptedItems,
    String secretKey,
    String pubkey,
  ) async {
    final List<List<String>> tags = bookmarksToTags(items);
    tags.add(["d", identifier]);
    return Event.from(
      kind: kindCategorizedBookmarks,
      tags: tags,
      content: await bookmarksToContent(encryptedItems, secretKey, pubkey),
      secretKey: secretKey,
    );
  }

  /// Parses a NIP-51 list event into a [UserListData].
  ///
  /// Accepts any list kind defined in the spec (10000-10102, 30000-39092, etc.).
  /// The method extracts public tags and decrypts private content using NIP-44.
  static Future<UserListData> parse(
    Event event, {
    required String secretKey,
  }) async {
    String identifier = "";
    final List<Contact> contacts = [];
    final List<String> bookmarks = [];
    for (final List tag in event.tags) {
      if (tag.length < 2) continue;
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
    // Extract additional tag types per spec
    final List<String> hashtags = findAllTagValues(event.tags, 't');
    final List<String> words = findAllTagValues(event.tags, 'word');
    final List<String> coordinates = findAllTagValues(event.tags, 'a');

    final pubkey = Keys(secretKey).public;
    if (event.content.isNotEmpty) {
      // Try plaintext JSON first, then NIP-44 decryption.
      final plaintext = _tryParsePlaintext(event.content);
      if (plaintext != null) {
        _extractFromTags(plaintext, contacts, bookmarks);
      } else {
        try {
          final content =
              await UserList.fromContent(event.content, secretKey, pubkey);
          contacts.addAll(content.contacts);
          bookmarks.addAll(content.bookmarks);
        } on Exception {
          // Content is neither valid JSON nor valid NIP-44 ciphertext.
        }
      }
    }
    if (event.kind == kindMuteList) identifier = "Mute";
    if (event.kind == kindPinList) identifier = "Pin";

    return UserListData(
      owner: event.pubkey,
      identifier: identifier,
      contacts: contacts,
      bookmarks: bookmarks,
      hashtags: hashtags,
      words: words,
      coordinates: coordinates,
    );
  }

  /// Tries to parse [content] as a plaintext JSON array of tags.
  /// Returns the parsed list on success, or null if it's not valid JSON.
  static List<List>? _tryParsePlaintext(String content) {
    try {
      final decoded = json.decode(content);
      if (decoded is List) {
        return decoded.cast<List>();
      }
    } on FormatException {
      // Not valid JSON — likely NIP-44 ciphertext.
    }
    return null;
  }

  /// Extracts contacts and bookmarks from a list of decoded tags.
  static void _extractFromTags(
    List<List> tags,
    List<Contact> contacts,
    List<String> bookmarks,
  ) {
    for (final tag in tags) {
      if (tag.length < 2) continue;
      if (tag[0] == 'p') {
        contacts.add(Contact(
          tag[1],
          tag.length > 2 ? tag[2] : '',
          tag.length > 3 ? tag[3] : '',
        ));
      } else if (tag[0] == 'e') {
        bookmarks.add(tag[1]);
      }
    }
  }
}

/// A contact entry in a NIP-51 list.
///
/// Tag format: ["p", pubkey, relay?, petname?]
class Contact {
  /// The hex-encoded public key of the contact.
  final String pubkey;

  /// The preferred relay URL for this contact (optional).
  final String? mainRelay;

  /// A local petname for this contact (optional).
  final String? petName;

  /// Creates a [Contact] with the given [pubkey], [mainRelay], and [petName].
  const Contact(this.pubkey, this.mainRelay, this.petName);
}

/// The parsed contents of a NIP-51 list event.
class UserListData {
  /// The public key of the list owner.
  final String owner;

  /// The list identifier (category name, or "Mute"/"Pin" for non-categorized).
  final String identifier;

  /// The contacts in this list (from `p` tags).
  final List<Contact> contacts;

  /// The bookmarked event IDs (from `e` tags).
  final List<String> bookmarks;

  /// Hashtags in the list (from `t` tags, used in mute lists).
  final List<String> hashtags;

  /// Muted words (from `word` tags, used in mute lists).
  final List<String> words;

  /// Addressable event coordinates (from `a` tags, used in bookmark lists).
  final List<String> coordinates;

  /// Creates a [UserListData] with the given fields.
  const UserListData({
    required this.owner,
    required this.identifier,
    this.contacts = const [],
    this.bookmarks = const [],
    this.hashtags = const [],
    this.words = const [],
    this.coordinates = const [],
  });
}

typedef Nip51 = UserList;
