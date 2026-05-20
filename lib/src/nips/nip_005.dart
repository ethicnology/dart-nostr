import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nostr/nostr.dart';

/// DNS-based internet identifiers — [NIP-05](https://github.com/nostr-protocol/nips/blob/master/05.md)
class DnsIdentifier {
  /// Parses a kind-0 (set_metadata) event and extracts its NIP-05 identity.
  ///
  /// Returns null if the event has no `nip05` field in its content.
  /// Throws [InvalidKindException] if the event kind is not 0.
  /// Throws [DeserializationException] if the content cannot be parsed.
  static Future<DnsData?> parse(Event event) async {
    if (event.kind == Note.kindMetadata) {
      try {
        final Map map = json.decode(event.content);
        final String? nip05 = map['nip05'];
        if (nip05 == null || nip05.isEmpty) return null;
        final List<dynamic> parts = nip05.split('@');
        final String name = parts[0];
        final String domain = parts[1];
        final List<dynamic> relays = map['relays'] ?? [];
        return DnsData(
            name: name,
            domain: domain,
            pubkey: event.pubkey,
            relays: relays.map((e) => e.toString()).toList());
      } catch (e) {
        throw DeserializationException(e.toString());
      }
    }
    throw InvalidKindException(event.kind, [Note.kindMetadata]);
  }

  /// Creates a kind-0 set_metadata event with NIP-05 identity.
  ///
  /// [name] is the local part of the identifier (before the @).
  /// [domain] is the domain part of the identifier (after the @).
  /// [relays] is a list of relay URLs to include in the content.
  /// [secretKey] is the hex-encoded secret key used to sign the event.
  ///
  /// Throws [NostrException] if the name or domain is invalid.
  static Event create({
    required String name,
    required String domain,
    required List<String> relays,
    required String secretKey,
  }) {
    if (isValidName(name) && isValidDomain(domain)) {
      final String content = generateContent(name, domain, relays);
      return Event.from(kind: Note.kindMetadata, tags: [], content: content, secretKey: secretKey);
    } else {
      throw InvalidIdentifierException(
        '$name@$domain',
        'name must match [a-z0-9_.-]+ and domain must be a valid DNS name',
      );
    }
  }

  /// Fetches the NIP-05 identity for the given identifier.
  ///
  /// Makes an HTTP GET to `https://<domain>/.well-known/nostr.json?name=<local>`
  /// and returns the resolved pubkey and relays.
  ///
  /// Per the spec, HTTP redirects are NOT followed.
  ///
  /// Returns `null` if the identifier cannot be resolved.
  static Future<DnsData?> fetch(String identifier) async {
    final parts = identifier.split('@');
    if (parts.length != 2) return null;
    final name = parts[0];
    final domain = parts[1];

    if (!isValidName(name) || !isValidDomain(domain)) return null;

    final url = Uri.https(domain, '/.well-known/nostr.json', {'name': name});

    final client = http.Client();
    try {
      // Per NIP-05 spec: fetchers MUST ignore any HTTP redirects.
      final request = http.Request('GET', url)..followRedirects = false;
      final response = await client.send(request);

      if (response.statusCode != 200) return null;

      // Read body BEFORE closing the client (stream depends on connection)
      final body = await response.stream.bytesToString();

      final Map<String, dynamic> data = json.decode(body);
      final Map<String, dynamic>? names = data['names'];
      if (names == null) return null;

      final String? pubkey = names[name];
      if (pubkey == null) return null;

      // Extract relays for this pubkey (optional per spec)
      final Map<String, dynamic>? relaysMap = data['relays'];
      final List<String> relays = relaysMap != null && relaysMap[pubkey] != null
          ? (relaysMap[pubkey] as List).map((e) => e.toString()).toList()
          : [];

      return DnsData(
        name: name,
        domain: domain,
        pubkey: pubkey,
        relays: relays,
      );
    } on Object {
      // Includes _TypeError from the implicit casts above (e.g. when a
      // misbehaving .well-known endpoint returns the wrong JSON shape).
      // Spec says "return null on any resolution failure".
      return null;
    } finally {
      client.close();
    }
  }

  /// Verify a NIP-05 identifier against the claimed public key.
  ///
  /// Makes an HTTP GET to `https://<domain>/.well-known/nostr.json?name=<local>`
  /// and checks that the returned pubkey matches.
  ///
  /// Per the spec, HTTP redirects are NOT followed.
  ///
  /// Returns `true` if the identifier is valid and matches the pubkey.
  static Future<bool> verify({
    required String identifier,
    required String pubkey,
  }) async {
    final result = await fetch(identifier);
    return result != null && result.pubkey.toLowerCase() == pubkey.toLowerCase();
  }

  /// Returns a NIP-05 verification URL for the given identifier.
  ///
  /// Throws [NostrException] if the identifier does not contain exactly one `@`.
  static Uri verificationUrl(String identifier) {
    final parts = identifier.split('@');
    if (parts.length != 2) {
      throw InvalidIdentifierException(
        identifier,
        'NIP-05 identifier must be in the form "local@domain"',
      );
    }
    return Uri.https(parts[1], '/.well-known/nostr.json', {'name': parts[0]});
  }

  /// NIP-05 local part must match [a-z0-9._-]+
  static bool isValidName(String input) {
    final RegExp regExp = RegExp(r'^[a-z0-9_\-\.]+$');
    return regExp.hasMatch(input);
  }

  /// Returns `true` if [domain] is a valid DNS domain name.
  static bool isValidDomain(String domain) {
    final RegExp regExp = RegExp(
      r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$',
      caseSensitive: false,
    );
    return regExp.hasMatch(domain);
  }

  /// Generates JSON content for a kind-0 event with NIP-05 fields.
  static String generateContent(
    String name,
    String domain,
    List<String> relays,
  ) {
    return json.encode({
      'name': name,
      'nip05': '$name@$domain',
      'relays': relays,
    });
  }
}

/// A resolved NIP-05 DNS identity.
class DnsData {
  /// The local part of the identifier (before the @).
  final String name;

  /// The domain part of the identifier (after the @).
  final String domain;

  /// The public key associated with this identifier.
  final String pubkey;

  /// Relay URLs where events from this identity can be found.
  final List<String> relays;

  /// Creates a [DnsData] with the given fields.
  const DnsData({
    required this.name,
    required this.domain,
    required this.pubkey,
    this.relays = const [],
  });
}

typedef Nip5 = DnsIdentifier;
typedef DNS = DnsData;
