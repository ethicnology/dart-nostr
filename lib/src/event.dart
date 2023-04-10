import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:bip340/bip340.dart' as bip340;
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:kepler/kepler.dart';
import 'package:nostr/src/utils.dart';
import 'package:nostr/src/settings.dart';
import 'package:pointycastle/export.dart';

/// The only object type that exists is the event, which has the following format on the wire:
///
/// - "id": "32-bytes hex-encoded sha256 of the the serialized event data"
/// - "pubkey": "32-bytes hex-encoded public key of the event creator",
/// - "created_at": unix timestamp in seconds,
/// - "kind": integer,
/// - "tags": [
///    ["e", "32-bytes hex of the id of another event", "recommended relay URL"],
///    ["p", "32-bytes hex of the key", "recommended relay URL"]
///  ],
/// - "content": "arbitrary string",
/// - "sig": "64-bytes signature of the sha256 hash of the serialized event data, which is the same as the 'id' field"
class Event {
  /// 32-bytes hex-encoded sha256 of the the serialized event data (hex)
  late String id;

  /// 32-bytes hex-encoded public key of the event creator (hex)
  late String pubkey;

  /// unix timestamp in seconds
  late int createdAt;

  /// -  0: set_metadata: the content is set to a stringified JSON object {name: <username>, about: <string>, picture: <url, string>} describing the user who created the event. A relay may delete past set_metadata events once it gets a new one for the same pubkey.
  /// -  1: text_note: the content is set to the text content of a note (anything the user wants to say). Non-plaintext notes should instead use kind 1000-10000 as described in NIP-16.
  /// -  2: recommend_server: the content is set to the URL (e.g., wss://somerelay.com) of a relay the event creator wants to recommend to its followers.
  late int kind;

  /// The tags array can store a tag identifier as the first element of each subarray, plus arbitrary information afterward (always as strings).
  ///
  /// This NIP defines "p" — meaning "pubkey", which points to a pubkey of someone that is referred to in the event —, and "e" — meaning "event", which points to the id of an event this event is quoting, replying to or referring to somehow.
  late List<List<String>> tags;

  /// arbitrary string
  String content = "";

  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  late String sig;

  /// subscription_id is a random string that should be used to represent a subscription.
  String? subscriptionId;

  bool decrypted = false;

  /// Default constructor
  ///
  /// verify: ensure your event isValid() –> id, signature, timestamp…
  ///
  ///```dart
  /// String id =
  ///     "4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49";
  /// String pubKey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// int createdAt = 1672175320;
  /// int kind = 1;
  /// List<List<String>> tags = [];
  /// String content = "Ceci est une analyse du websocket";
  /// String sig =
  ///     "797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c4ae9cc9007e8489f5f63c66a66e101fd1515d0a846385953f5f837efb9afe885";
  ///
  /// Event event = Event(
  ///   id,
  ///   pubKey,
  ///   createdAt,
  ///   kind,
  ///   tags,
  ///   content,
  ///   sig,
  ///   verify: true,
  ///   subscriptionId: null,
  /// );
  ///```
  Event(
    this.id,
    this.pubkey,
    this.createdAt,
    this.kind,
    this.tags,
    this.content,
    this.sig, {
    this.subscriptionId,
    bool verify = true,
  }) {
    pubkey = pubkey.toLowerCase();
    if (verify) assert(isValid() == true);
  }

  /// Partial constructor, you have to fill the fields yourself
  ///
  /// verify: ensure your event isValid() –> id, signature, timestamp…
  ///
  /// ```dart
  /// var partialEvent = Event.partial();
  /// assert(partialEvent.isValid() == false);
  /// partialEvent.createdAt = currentUnixTimestampSeconds();
  /// partialEvent.pubkey =
  ///     "981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b";
  /// partialEvent.id = partialEvent.getEventId();
  /// partialEvent.sig = partialEvent.getSignature(
  ///   "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  /// );
  /// assert(partialEvent.isValid() == true);
  /// ```
  factory Event.partial({
    id = "",
    pubkey = "",
    createdAt = 0,
    kind = 1,
    tags = const <List<String>>[],
    content = "",
    sig = "",
    subscriptionId,
    bool verify = false,
  }) {
    return Event(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      verify: verify,
    );
  }

  /// Instantiate Event object from the minimum available data
  ///
  /// ```dart
  ///Event event = Event.from(
  ///  kind: 1,
  ///  tags: [],
  ///  content: "",
  ///  privkey:
  ///      "5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12",
  ///);
  ///```
  factory Event.from({
    int createdAt = 0,
    required int kind,
    required List<List<String>> tags,
    required String content,
    required String privkey,
    String? subscriptionId,
    bool verify = false,
  }) {
    if (createdAt == 0) createdAt = currentUnixTimestampSeconds();
    final pubkey = bip340.getPublicKey(privkey).toLowerCase();

    final id = _processEventId(
      pubkey,
      createdAt,
      kind,
      tags,
      content,
    );

    final sig = _processSignature(
      privkey,
      id,
    );

    return Event(
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }

  /// Deserialize an event from a JSON
  ///
  /// verify: enable/disable events checks
  ///
  /// This option adds event checks such as id, signature, non-futuristic event: default=True
  ///
  /// Performances could be a reason to disable event checks
  factory Event.fromJson(Map<String, dynamic> json, {bool verify = true}) {
    var tags = (json['tags'] as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();
    return Event(
      json['id'],
      json['pubkey'],
      json['created_at'],
      json['kind'],
      tags,
      json['content'],
      json['sig'],
      verify: verify,
    );
  }

  /// Serialize an event in JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig
      };

  /// Serialize to nostr event message
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  String serialize() {
    if (subscriptionId != null) {
      return jsonEncode(["EVENT", subscriptionId, toJson()]);
    } else {
      return jsonEncode(["EVENT", toJson()]);
    }
  }

  /// Deserialize a nostr event message
  /// - ["EVENT", event JSON as defined above]
  /// - ["EVENT", subscription_id, event JSON as defined above]
  /// ```dart
  /// Event event = Event.deserialize([
  ///   "EVENT",
  ///   {
  ///     "id": "67bd60e47d7fdddadebff890143167bcd7b5d28b2c3008eae40e0ac5ba0e6b34",
  ///     "kind": 1,
  ///     "pubkey":
  ///         "36685fa5106b1bc03ae7bea82eded855d8f56c41db4c8bdef8099e1e0f2b2afa",
  ///     "created_at": 1674403511,
  ///     "content":
  ///         "Block 773103 was just confirmed. The total value of all the non-coinbase outputs was 61,549,183,849 sats, or \$14,025,828",
  ///     "tags": [],
  ///     "sig":
  ///         "4912a6850a711a876fd2443771f69e094041f7e832df65646a75c2c77989480cce9b41aa5ea3d055c16fe5beb7d11d3d5fa29b4c4046c150b09393c4d3d16eb4"
  ///   }
  /// ]);
  /// ```
  factory Event.deserialize(input, {bool verify = true}) {
    Map<String, dynamic> json = {};
    String? subscriptionId;
    if (input.length == 2) {
      json = input[1] as Map<String, dynamic>;
    } else if (input.length == 3) {
      json = input[2] as Map<String, dynamic>;
      subscriptionId = input[1] as String;
    } else {
      throw Exception('invalid input');
    }

    if (json['tags'] is String) {
      json['tags'] = jsonDecode(json['tags']);
    }
    List<List<String>> tags = (json['tags'] as List<dynamic>)
        .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
        .toList();

    Event event = Event(
      json['id'],
      json['pubkey'],
      json['created_at'],
      json['kind'],
      tags,
      json['content'],
      json['sig'],
      subscriptionId: subscriptionId,
      verify: verify,
    );
    if (event.kind == 4) {
      event.decryptContent();
    }
    return event;
  }

  factory Event.newEvent(
    String content,
    String privkey,
  ) {
    Event event = Event.partial();
    event.kind = 1;
    event.content = content;
    event.createdAt = currentUnixTimestampSeconds();
    event.pubkey = bip340.getPublicKey(privkey).toLowerCase();
    event.id = event.getEventId();
    event.sig = event.getSignature(privkey);
    return event;
  }

  /// To obtain the event.id, we sha256 the serialized event.
  /// The serialization is done over the UTF-8 JSON-serialized string (with no white space or line breaks) of the following structure:
  ///
  ///[
  ///  0,
  ///  <pubkey, as a (lowercase) hex string>,
  ///  <created_at, as a number>,
  ///  <kind, as a number>,
  ///  <tags, as an array of arrays of non-null strings>,
  ///  <content, as a string>
  ///]
  String getEventId() {
    // Included for minimum breaking changes
    return _processEventId(
      pubkey,
      createdAt,
      kind,
      tags,
      content,
    );
  }

  // Support for [getEventId]
  static String _processEventId(
    String pubkey,
    int createdAt,
    int kind,
    List<List<String>> tags,
    String content,
  ) {
    List data = [0, pubkey.toLowerCase(), createdAt, kind, tags, content];
    String serializedEvent = jsonEncode(data);
    List<int> hash = sha256.convert(utf8.encode(serializedEvent)).bytes;
    return hex.encode(hash);
  }

  /// Each user has a keypair. Signatures, public key, and encodings are done according to the Schnorr signatures standard for the curve secp256k1
  /// 64-bytes signature of the sha256 hash of the serialized event data, which is the same as the "id" field
  String getSignature(String privateKey) {
    return _processSignature(privateKey, id);
  }

  // Support for [getSignature]
  static String _processSignature(
    String privateKey,
    String id,
  ) {
    /// aux must be 32-bytes random bytes, generated at signature time.
    /// https://github.com/nbd-wtf/dart-bip340/blob/master/lib/src/bip340.dart#L10
    String aux = generate64RandomHexChars();
    return bip340.sign(privateKey, id, aux);
  }

  /// Verify if event checks such as id, signature, non-futuristic are valid
  /// Performances could be a reason to disable event checks
  bool isValid() {
    String verifyId = getEventId();
    if (createdAt.toString().length == 10 &&
        id == verifyId &&
        bip340.verify(pubkey, id, sig)) {
      return true;
    } else {
      return false;
    }
  }

  bool decryptContent() {
    int ivIndex = content.indexOf("?iv=");
    if( ivIndex <= 0) {
      print("Invalid content for dm, could not get ivIndex: $content");
      return false;
    }
    String iv = content.substring(ivIndex + "?iv=".length, content.length);
    String encString = content.substring(0, ivIndex);
    final String decString;
    try {
      content = decrypt(userPrivateKey, "02" + pubkey, encString, iv);
      decrypted = true;
    } catch(e) {
      //print("Fail to decrypt: ${e}");
    }
    return decrypted;
  }

  // pointy castle source https://github.com/PointyCastle/pointycastle/blob/master/tutorials/aes-cbc.md
  // https://github.com/bcgit/pc-dart/blob/master/tutorials/aes-cbc.md
  // 3 https://github.com/Dhuliang/flutter-bsv/blob/42a2d92ec6bb9ee3231878ffe684e1b7940c7d49/lib/src/aescbc.dart

  /// Decrypt data using self private key
  String decrypt(String privateString,
                           String publicString,
                           String b64encoded,
                          [String b64IV = ""]) {

    Uint8List encdData = base64.decode(b64encoded);
    final rawData = decryptRaw(privateString, publicString, encdData, b64IV);
    return Utf8Decoder().convert(rawData.toList());
  }

  static Map<String, List<List<int>>> gMapByteSecret = {};

  Uint8List decryptRaw(String privateString,
                       String publicString,
                       Uint8List cipherText,
                       [String b64IV = ""]) {
    List<List<int>> byteSecret = gMapByteSecret[publicString]??[];
    if (byteSecret.isEmpty) {
      byteSecret = Kepler.byteSecret(privateString, publicString);
      gMapByteSecret[publicString] = byteSecret;
    }
    final secretIV = byteSecret;
    final key = Uint8List.fromList(secretIV[0]);
    final iv = b64IV.length > 6
              ? base64.decode(b64IV)
              : Uint8List.fromList(secretIV[1]);

    CipherParameters params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv), null);

    PaddedBlockCipherImpl cipherImpl = PaddedBlockCipherImpl(
        PKCS7Padding(), CBCBlockCipher(AESEngine()));

    cipherImpl.init(false,
                    params as PaddedBlockCipherParameters<CipherParameters?,
                                                          CipherParameters?>);
    final Uint8List  finalPlainText = Uint8List(cipherText.length); // allocate space

    var offset = 0;
    while (offset < cipherText.length - 16) {
      offset += cipherImpl.processBlock(cipherText, offset, finalPlainText, offset);
    }
    //remove padding
    offset += cipherImpl.doFinal(cipherText, offset, finalPlainText, offset);
    return finalPlainText.sublist(0, offset);
  }
}

class EncryptedDirectMessage extends Event {
  late String peerPubkey; 
  late String? plaintext;
  late String? referenceEventId;

  EncryptedDirectMessage(
    this.peerPubkey,
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig, {
    subscriptionId,
    bool verify = false,
    this.plaintext,
    this.referenceEventId,
  }) : super(
    id,
    pubkey,
    createdAt,
    kind,
    tags,
    content,
    sig,
    subscriptionId: subscriptionId,
    verify: verify,
  ) {
    kind = 4;
    plaintext = content;
  }

  factory EncryptedDirectMessage.partial({
    peerPubkey = "",
    id = "",
    pubkey = "",
    createdAt = 0,
    kind = 4,
    tags = const <List<String>>[],
    content = "",
    sig = "",
    plaintext,
    referenceEventId,
    subscriptionId,
    bool verify = false,
  }) {
    return EncryptedDirectMessage(
      peerPubkey,
      id,
      pubkey,
      createdAt,
      kind,
      tags,
      content,
      sig,
      plaintext: plaintext,
      referenceEventId: referenceEventId,
      subscriptionId: subscriptionId,
      verify: verify,
    );
  }

  factory EncryptedDirectMessage.newEvent(
    String peerPubkey,
    String plaintext,
    String privkey, {
    String? referenceEventId,
  }) {
    EncryptedDirectMessage event = EncryptedDirectMessage.partial();
    event.content = encryptMessage(privkey, '02' + peerPubkey, plaintext);
    event.kind = 4;
    event.createdAt = currentUnixTimestampSeconds();
    event.pubkey = bip340.getPublicKey(privkey).toLowerCase();
    event.tags = [['p', peerPubkey],];
    event.plaintext = plaintext;
    if (referenceEventId != null) {
      event.tags.add(['e', referenceEventId]);
    }
    event.id = event.getEventId();
    event.sig = event.getSignature(privkey);
    return event;
  }

  String getEventId() {
    assert(content != plaintext);
    // Included for minimum breaking changes
    return Event._processEventId(
      pubkey,
      createdAt,
      kind,
      tags,
      content,
    );
  }

  // Encrypt data using self private key in nostr format ( with trailing ?iv=)
  static String encryptMessage( String privateString,
                           String publicString,
                           String plainText) {
    print('privateString ' + privateString);
    print('publicString ' + publicString);

    Uint8List uintInputText = Utf8Encoder().convert(plainText);
    final encryptedString = encryptMessageRaw(privateString, publicString, uintInputText);
    return encryptedString;
  }

  static String encryptMessageRaw( String privateString,
                       String publicString,
                       Uint8List uintInputText) {
    final secretIV = Kepler.byteSecret(privateString, publicString);
    final key = Uint8List.fromList(secretIV[0]);

    // generate iv  https://stackoverflow.com/questions/63630661/aes-engine-not-initialised-with-pointycastle-securerandom
    FortunaRandom fr = FortunaRandom();
    final _sGen = Random.secure();
    fr.seed(KeyParameter(
                        Uint8List.fromList(List.generate(32, (_) => _sGen.nextInt(255)))));
    final iv = fr.nextBytes(16);

    CipherParameters params = PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(key), iv), null);

    PaddedBlockCipherImpl cipherImpl = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));

    cipherImpl.init(true,  // means to encrypt
                    params as PaddedBlockCipherParameters<CipherParameters?,
                                                          CipherParameters?>);

    // allocate space
    final Uint8List outputEncodedText = Uint8List(uintInputText.length + 16);

    var offset = 0;
    while (offset < uintInputText.length - 16) {
      offset += cipherImpl.processBlock(uintInputText, offset, outputEncodedText, offset);
    }

    //add padding 
    offset += cipherImpl.doFinal(uintInputText, offset, outputEncodedText, offset);
    final Uint8List finalEncodedText = outputEncodedText.sublist(0, offset);

    String stringIv = base64.encode(iv);
    String outputPlainText = base64.encode(finalEncodedText);
    outputPlainText = outputPlainText + "?iv=" + stringIv;
    return  outputPlainText;
  }
}
