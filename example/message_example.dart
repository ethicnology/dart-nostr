import 'package:nostr/nostr.dart';

void main() async {
  var eventPayload =
      '["EVENT","5ce1758166673a70e391303fb7cfeb0f5d47ec38a9342a27858950d13424d59b",{"content":"No quotes from the Bible? My global feed is full of religious nutcases","created_at":1685026912,"id":"e695c81fa5099b9f3ef0d868d8143eae481954114681bbe4432b50e44e199927","kind":1,"pubkey":"ab4103fc8cd4e1d8d31a99d079ed8293bdc26b11ec1ec61d95c13e43d7e048ff","sig":"0d17d6197ad12ab5ad77eb51231ae12c2ce1e639218bb6e3a01cce78aa092f3e77fb1f914b690675a425dcfd5b4dfa7be72c2cb608568798361781d75e354b32","tags":[["e","7804acd35bb9727d0374545a99bb4f30f901289aebaf3cf330dda28c235cd7ad"],["p","1bc70a0148b3f316da33fe3c89f23e3e71ac4ff998027ec712b905cd24f6a411"]]}]';
  var event = Message.deserialize(eventPayload);
  assert(event.type == "EVENT");
  assert(event.message.id ==
      "a60679692533b308f1d862c2a5ca5c08a304e5157b1df5cde0ff0454b9920605");

  String requestPayload =
      '["REQ","22055752544101437",{"kinds":[0,1,2,7],"since":1674320733,"limit":450}]';
  var req = Message.deserialize(requestPayload);
  assert(req.type == "REQ");
  assert(req.message.filters[0].limit == 450);

  String closePayload = '["CLOSE","anyrandomstring"]';
  var close = Message.deserialize(closePayload);
  assert(close.type == "CLOSE");
  assert(close.message.subscriptionId == "anyrandomstring");

  String noticePayload =
      '["NOTICE", "restricted: we can\'t serve DMs to unauthenticated users, does your client implement NIP-42?"]';
  var notice = Message.deserialize(noticePayload);
  assert(notice.type == "NOTICE");

  String eosePayload = '["EOSE", "random"]';
  var eose = Message.deserialize(eosePayload);
  assert(eose.type == "EOSE");

  String okPayload =
      '["OK", "b1a649ebe8b435ec71d3784793f3bbf4b93e64e17568a741aecd4c7ddeafce30", true, ""]';
  var ok = Message.deserialize(okPayload);
  assert(ok.type == "OK");
}
