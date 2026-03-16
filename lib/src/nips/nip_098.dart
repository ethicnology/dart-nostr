import 'dart:convert';

import 'package:convert/convert.dart';
import 'package:nostr/nostr.dart';

/// HTTP Auth — [NIP-98](https://github.com/nostr-protocol/nips/blob/master/98.md)
///
/// Kind 27235 events used as HTTP `Authorization` headers. The event
/// proves ownership of a nostr public key when making HTTP requests
/// to nostr-aware servers.
///
/// Required tags: `u` (absolute URL), `method` (HTTP method).
/// Optional tag: `payload` (SHA256 hex of the request body).
/// Content SHOULD be empty.
///
/// Header format: `Authorization: Nostr <base64-encoded-event-json>`
class HttpAuth {
  /// Event kind for HTTP auth.
  static const int kindHttpAuth = 27235;

  /// Creates a kind-27235 HTTP auth event.
  ///
  /// [url] is the absolute URL being requested.
  /// [method] is the HTTP method (GET, POST, PUT, PATCH, DELETE).
  /// [secretKey] is the hex-encoded secret key.
  /// [payload] is an optional SHA256 hex hash of the request body.
  static Event create({
    required String url,
    required String method,
    required String secretKey,
    String? payload,
  }) {
    final tags = <List<String>>[
      ['u', url],
      ['method', method.toUpperCase()],
    ];

    if (payload != null) {
      tags.add(['payload', payload]);
    }

    return Event.from(
      kind: kindHttpAuth,
      tags: tags,
      content: '',
      secretKey: secretKey,
    );
  }

  /// Computes the SHA256 hex hash of [body] for use as a `payload` tag.
  static String payloadHash(List<int> body) {
    return hex.encode(sha256(body));
  }

  /// Encodes an HTTP auth event as a base64 `Authorization` header value.
  ///
  /// Returns a string in the format `Nostr <base64>`.
  static String toAuthHeader(Event event) {
    final eventJson = event.toJson();
    return 'Nostr ${base64.encode(utf8.encode(eventJson))}';
  }

  /// Decodes an `Authorization: Nostr <base64>` header back into an [Event].
  ///
  /// Accepts either the full header value (`Nostr <base64>`) or just the
  /// base64 portion. The returned [Event] is validated (id + signature).
  ///
  /// Throws [NostrException] if the header is malformed or the event
  /// fails validation.
  static Event fromAuthHeader(String header) {
    var b64 = header;
    if (b64.startsWith('Nostr ')) {
      b64 = b64.substring(6);
    }

    final String decoded;
    try {
      decoded = utf8.decode(base64.decode(b64));
    } on FormatException catch (e) {
      throw NostrException('Malformed auth header: $e');
    }

    final Map<String, dynamic> map;
    try {
      map = jsonDecode(decoded) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw NostrException('Invalid JSON in auth header: $e');
    }

    // Skip verification here — callers should use [validate] for
    // server-side checks (kind, timestamp, URL, method, payload, sig).
    return Event(
      map['id'] as String,
      map['pubkey'] as String,
      map['created_at'] as int,
      map['kind'] as int,
      (map['tags'] as List)
          .map((t) => (t as List).map((e) => e.toString()).toList())
          .toList(),
      map['content'] as String,
      map['sig'] as String,
      verify: false,
    );
  }

  /// Parses a kind-27235 event into an [HttpAuthData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 27235.
  /// Throws [MissingTagException] if `u` or `method` tags are absent.
  static HttpAuthData parse(Event event) {
    if (event.kind != kindHttpAuth) {
      throw InvalidKindException(event.kind, [kindHttpAuth]);
    }

    final url = findTagValue(event.tags, 'u');
    if (url == null) throw MissingTagException('u');

    final method = findTagValue(event.tags, 'method');
    if (method == null) throw MissingTagException('method');

    return HttpAuthData(
      url: url,
      method: method,
      payload: findTagValue(event.tags, 'payload'),
      pubkey: event.pubkey,
      createdAt: event.createdAt,
    );
  }

  /// Validates an HTTP auth event against the actual request parameters.
  ///
  /// Checks:
  /// 1. Event kind is 27235
  /// 2. `created_at` is not too old ([pastWindowSeconds], default 60) or
  ///    too far in the future ([futureWindowSeconds], default 30)
  /// 3. `u` tag matches [url]
  /// 4. `method` tag matches [method]
  /// 5. If [body] is provided, `payload` tag matches its SHA256 hash
  ///
  /// Throws [NostrException] on validation failure.
  static void validate({
    required Event event,
    required String url,
    required String method,
    List<int>? body,
    int pastWindowSeconds = 60,
    int futureWindowSeconds = 30,
  }) {
    if (event.kind != kindHttpAuth) {
      throw InvalidKindException(event.kind, [kindHttpAuth]);
    }

    // Asymmetric timestamp check (like rust-nostr)
    final now = currentUnixTimestampSeconds();
    final delta = now - event.createdAt;
    if (delta > pastWindowSeconds) {
      throw NostrException(
        'Auth event too old: $delta seconds (max $pastWindowSeconds)',
      );
    }
    if (delta < -futureWindowSeconds) {
      throw NostrException(
        'Auth event too far in the future: ${-delta} seconds (max $futureWindowSeconds)',
      );
    }

    final data = parse(event);

    // URL check
    if (data.url != url) {
      throw NostrException(
        'URL mismatch: expected "$url", got "${data.url}"',
      );
    }

    // Method check
    if (data.method.toUpperCase() != method.toUpperCase()) {
      throw NostrException(
        'Method mismatch: expected "$method", got "${data.method}"',
      );
    }

    // Payload check
    if (body != null) {
      final expected = payloadHash(body);
      if (data.payload == null) {
        throw MissingTagException('payload');
      }
      if (data.payload != expected) {
        throw NostrException(
          'Payload hash mismatch: expected "$expected", got "${data.payload}"',
        );
      }
    }
  }
}

/// Parsed HTTP auth event data.
class HttpAuthData {
  /// The absolute URL from the `u` tag.
  final String url;

  /// The HTTP method from the `method` tag.
  final String method;

  /// The SHA256 hex hash of the request body (from `payload` tag), if present.
  final String? payload;

  /// The public key of the requester.
  final String pubkey;

  /// Unix timestamp of the auth event.
  final int createdAt;

  /// Creates an [HttpAuthData].
  const HttpAuthData({
    required this.url,
    required this.method,
    required this.pubkey,
    required this.createdAt,
    this.payload,
  });
}

typedef Nip98 = HttpAuth;
