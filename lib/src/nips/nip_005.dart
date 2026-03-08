import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nostr/nostr.dart';

/// Mapping Nostr keys to DNS-based internet identifiers
class Nip5 {
  /// Decode a kind-0 (set_metadata) event and extract its NIP-05 identity.
  ///
  /// Returns null if the event has no `nip05` field in its content.
  static Future<DNS?> decode(Event event) async {
    if (event.kind == 0) {
      try {
        final Map map = json.decode(event.content);
        final String? nip05 = map['nip05'];
        if (nip05 == null || nip05.isEmpty) return null;
        final List<dynamic> parts = nip05.split('@');
        final String name = parts[0];
        final String domain = parts[1];
        final List<dynamic> relays = map['relays'] ?? [];
        return DNS(name, domain, event.pubkey,
            relays.map((e) => e.toString()).toList());
      } catch (e) {
        throw Exception(e.toString());
      }
    }
    throw Exception("kind ${event.kind} is not NIP-05 compatible (expected kind 0)");
  }

  /// Encode a kind-0 set_metadata event with NIP-05 identity.
  static Event encode(
      String name, String domain, List<String> relays, String secretKey) {
    if (isValidName(name) && isValidDomain(domain)) {
      final String content = generateContent(name, domain, relays);
      return Event.from(kind: 0, tags: [], content: content, secretKey: secretKey);
    } else {
      throw Exception("Invalid NIP-05 name or domain");
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
    final parts = identifier.split('@');
    if (parts.length != 2) return false;
    final name = parts[0];
    final domain = parts[1];

    if (!isValidName(name) || !isValidDomain(domain)) return false;

    final url = Uri.https(domain, '/.well-known/nostr.json', {'name': name});

    try {
      // Per NIP-05 spec: fetchers MUST ignore any HTTP redirects.
      final client = http.Client();
      final request = http.Request('GET', url)..followRedirects = false;
      final response = await client.send(request);

      if (response.statusCode != 200) {
        client.close();
        return false;
      }

      // Read body BEFORE closing the client (stream depends on connection)
      final body = await response.stream.bytesToString();
      client.close();

      final Map<String, dynamic> data = json.decode(body);
      final Map<String, dynamic>? names = data['names'];
      if (names == null) return false;

      final String? resolvedPubkey = names[name];
      if (resolvedPubkey == null) return false;

      return resolvedPubkey.toLowerCase() == pubkey.toLowerCase();
    } on Exception {
      return false;
    }
  }

  /// Returns a NIP-05 verification URL for the given identifier.
  static Uri verificationUrl(String identifier) {
    final parts = identifier.split('@');
    if (parts.length != 2) throw Exception('Invalid NIP-05 identifier');
    return Uri.https(parts[1], '/.well-known/nostr.json', {'name': parts[0]});
  }

  /// NIP-05 local part must match [a-z0-9._-]+
  static bool isValidName(String input) {
    final RegExp regExp = RegExp(r'^[a-z0-9_\-\.]+$');
    return regExp.hasMatch(input);
  }

  static bool isValidDomain(String domain) {
    final RegExp regExp = RegExp(
      r'^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$',
      caseSensitive: false,
    );
    return regExp.hasMatch(domain);
  }

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
class DNS {
  String name;
  String domain;
  String pubkey;
  List<String> relays;

  DNS(this.name, this.domain, this.pubkey, this.relays);
}

typedef DnsIdentifier = Nip5;
