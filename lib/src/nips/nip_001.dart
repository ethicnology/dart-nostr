import 'package:nostr/nostr.dart';

/// Basic Event Kinds
/// 0: set_metadata: the content is set to a stringified JSON object {name: <username>, about: <string>, picture: <url, string>} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
/// 1: text_note: the content is set to the plaintext content of a note (anything the user wants to say). Do not use Markdown! Clients should not have to guess how to interpret content like [](). Use different event kinds for parsable content.
/// 2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
class Nip1 {
  static Event setMetadata(String content, String privkey) {
    return Event.from(kind: 0, tags: [], content: content, privkey: privkey);
  }

  static Event textNote(String content, String privkey) {
    return Event.from(kind: 1, tags: [], content: content, privkey: privkey);
  }

  static Event recommendServer(String content, String privkey) {
    return Event.from(kind: 2, tags: [], content: content, privkey: privkey);
  }
}
