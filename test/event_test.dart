import 'dart:convert';

import 'package:bip340/bip340.dart';
import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('Event', () {
    test('Default constructor', () {
      String id =
          "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
      String pubKey =
          "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
      int createdAt = 1672175320;
      int kind = 1;
      List<List<String>> tags = [];
      String content = "Ceci est une analyse du websocket";
      String sig =
          "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";

      Event event = Event(
        id,
        pubKey,
        createdAt,
        kind,
        tags,
        content,
        sig,
      );

      expect(event.id, id);
      expect(event.pubkey, pubKey);
      expect(event.createdAt, createdAt);
      expect(event.kind, kind);
      expect(event.tags, tags);
      expect(event.content, content);
      expect(event.sig, sig);
      expect(event.subscriptionId, null);
    });

    test('Constructor.from', () {
      int createdAt = 1672175320;
      int kind = 1;
      List<List<String>> tags = [];
      String content = "Ceci est une analyse du websocket";
      String privkey =
          "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12";

      Event event = Event.from(
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
        privkey: privkey,
      );

      expect(
        event.id,
        "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49",
      );
      expect(
        event.pubkey,
        "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b",
      );
      expect(event.createdAt, createdAt);
      expect(event.kind, kind);
      expect(event.tags, tags);
      expect(event.content, content);
      expect(verify(event.pubkey, event.id, event.sig), true);
    });

    test('Constructor.from generated createdAt', () {
      Event event = Event.from(
        kind: 1,
        tags: [],
        content: "",
        privkey:
            "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
      );
      expect(event.createdAt != 0, isTrue);
    });

    test('Constructor.fromJson', () {
      var json = {
        "kind": 1,
        "pubkey":
            "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db",
        "content": "dart-nostr",
        "tags": [],
        "created_at": 1672477962,
        "sig":
            "246970954e7b74e7fe381a4c818fed739ee59444cb536dadf45fbbce33bd7455ae7cd678c347c4a0c6e0a4483d18c7e26b7abe76f4cc73234f774e0e0d65204b",
        "id": "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"
      };
      Event event = Event.fromJson(json);
      expect(event.id, json['id']);
      expect(event.pubkey, json['pubkey']);
      expect(event.createdAt, json['created_at']);
      expect(event.kind, json['kind']);
      expect(event.tags, json['tags']);
      expect(event.content, json['content']);
      expect(event.sig, json['sig']);
    });

    test('Constructor.toJson', () {
      Map<String, dynamic> json = {
        "pubkey":
            "9be7376ef6c0d493235ddf9018ff675a04bfcaf34dc1f97a1d270470f28c0ae0",
        "content": "How does this work? ð",
        "id":
            "883334badc17315fc61f0a13eec84c8c87df9d504ce0788f5eeab4a3527ddc97",
        "created_at": 1672477967,
        "sig":
            "3ce34915e90505f9760a463eb8f9e8b1748fd4c10c4cfddc09a2930ecce249ce8dd499eeffd6e24a215bb2f8265b68085f7104eb7d506f8d9b76a7c5312b09fd",
        "kind": 1,
        "tags": [
          [
            "e",
            "68ae015bf4833a6ff0ed86564c5afaa65c31791d35e8432755535d02eafc4375"
          ],
          [
            "e",
            "de2d85a00a52ceb25f3cfc41e22d927f6166250f210f928e2552b97c0bd66dcf"
          ],
          [
            "p",
            "052acd328f1c1d48e86fff3e34ada4bfc60578116f4f68f296602530529656a2"
          ]
        ]
      };

      Event event = Event.fromJson(json);
      Map<String, dynamic> toJson = event.toJson();
      expect(toJson, json);
    });
  });

  test('Constructor.serialize', () {
    var serialized = [
      "EVENT",
      {
        "id":
            "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2",
        "pubkey":
            "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db",
        "created_at": 1672477962,
        "kind": 1,
        "tags": [],
        "content": "dart-nostr",
        "sig":
            "246970954e7b74e7fe381a4c818fed739ee59444cb536dadf45fbbce33bd7455ae7cd678c347c4a0c6e0a4483d18c7e26b7abe76f4cc73234f774e0e0d65204b",
      }
    ];

    var serializedWithSubscriptionId = [
      "EVENT",
      "subscription_id",
      {
        "id":
            "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2",
        "pubkey":
            "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db",
        "created_at": 1672477962,
        "kind": 1,
        "tags": [],
        "content": "dart-nostr",
        "sig":
            "246970954e7b74e7fe381a4c818fed739ee59444cb536dadf45fbbce33bd7455ae7cd678c347c4a0c6e0a4483d18c7e26b7abe76f4cc73234f774e0e0d65204b",
      }
    ];

    Event event = Event.fromJson(serialized[1] as Map<String, dynamic>);
    expect(event.serialize(), jsonEncode(serialized));
    Event eventWithSubscriptionId =
        Event.deserialize(serializedWithSubscriptionId);
    expect(
      eventWithSubscriptionId.serialize(),
      jsonEncode(serializedWithSubscriptionId),
    );
  });

  test('Constructor.deserialize', () {
    var serialized = [
      "EVENT",
      "global",
      {
        "id":
            "654fd512517648d1d1f122bc56c55e626a22c4dd2087457116e9852c6baf6be9",
        "kind": 1,
        "pubkey":
            "8f474abb70c3987ff7e93fdd9e01cbade2dad5a8b3469fa1aba299823a1cee89",
        "created_at": 1674925169,
        "content": "\n\nhttps://i.imgur.com/bX7arPB.jpg",
        "tags": [
          [
            "e",
            "2da09b1cf751eaeb56027b7896215145737d6e88a2797b3fef6e8b974f504cac"
          ],
          [
            "p",
            "fe7f6bc6f7338b76bbf80db402ade65953e20b2f23e66e898204b63cc42539a3"
          ]
        ],
        "sig":
            "de65472a58520ea7d5d4f37e329a6468d12bf9aa8e6b6148b8bd7f87484d38578e8d28a50512699df1f88641ce27084d12c2f9a7ba1b3b6daf49e2d0372c5278"
      }
    ];
    Event event = Event.deserialize(serialized);
    expect(event.subscriptionId, serialized[1]);
    var json = serialized[2] as Map<String, dynamic>;
    expect(event.id, json['id']);
    expect(event.pubkey, json['pubkey']);
    expect(event.createdAt, json['created_at']);
    expect(event.kind, json['kind']);
    expect(event.tags, json['tags']);
    expect(event.content, json['content']);
    expect(event.sig, json['sig']);

    var serializeWithoutSubscriptionId = [
      "EVENT",
      {
        "id":
            "67bd60e47d7fdddadebff890143167bcd7b5d28b2c3008eae40e0ac5ba0e6b34",
        "kind": 1,
        "pubkey":
            "36685fa5106b1bc03ae7bea82eded855d8f56c41db4c8bdef8099e1e0f2b2afa",
        "created_at": 1674403511,
        "content":
            "Block 773103 was just confirmed. The total value of all the non-coinbase outputs was 61,549,183,849 sats, or \$14,025,828",
        "tags": [],
        "sig":
            "4912a6850a711a876fd2443771f69e094041f7e832df65646a75c2c77989480cce9b41aa5ea3d055c16fe5beb7d11d3d5fa29b4c4046c150b09393c4d3d16eb4"
      }
    ];
    Event eventWithoutSubscriptionId =
        Event.deserialize(serializeWithoutSubscriptionId);
    expect(eventWithoutSubscriptionId.subscriptionId, null);
  });
}
