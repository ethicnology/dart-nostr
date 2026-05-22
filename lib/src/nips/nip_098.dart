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
  /// base64 portion. The returned [Event] is cryptographically verified
  /// (id matches canonical serialization, signature is valid for the
  /// claimed pubkey).
  ///
  /// Throws [NostrException] if the header is malformed or the event
  /// fails validation. Use [validate] after this to also check the
  /// request-specific fields (kind, timestamp, URL, method, payload).
  static Event fromAuthHeader(String header) {
    var b64 = header;
    if (b64.startsWith('Nostr ')) {
      b64 = b64.substring(6);
    }

    final String decoded;
    try {
      decoded = utf8.decode(base64.decode(b64));
    } on FormatException catch (e) {
      throw MalformedAuthHeaderException(AuthHeaderError.badBase64, e);
    }

    final Object? decodedJson;
    try {
      decodedJson = jsonDecode(decoded);
    } on FormatException catch (e) {
      throw MalformedAuthHeaderException(AuthHeaderError.invalidJson, e);
    }
    if (decodedJson is! Map<String, dynamic>) {
      throw MalformedAuthHeaderException(
        AuthHeaderError.invalidJson,
        FormatException(
          'auth header must decode to a JSON object, got '
          '${decodedJson.runtimeType}',
        ),
      );
    }

    // Route through Event.fromMap so that missing/wrong-typed fields are
    // surfaced as DeserializationException (NostrException) instead of
    // raw _TypeError. Event.fromMap also verifies id + sig and throws
    // EventValidationException, which carries the specific
    // EventValidationReason — let it propagate.
    return Event.fromMap(decodedJson);
  }

  /// Parses a kind-27235 event into an [HttpAuthData].
  ///
  /// Throws [InvalidKindException] if the event kind is not 27235.
  /// Throws [MissingTagException] if `u` or `method` tags are absent
  /// and [permissive] is false. In permissive mode missing tags are
  /// recorded on [HttpAuthData.missingTags].
  static HttpAuthData parse(Event event, {bool permissive = false}) {
    if (event.kind != kindHttpAuth) {
      throw InvalidKindException(event.kind, [kindHttpAuth]);
    }

    final missing = <String>{};
    final url = findTagValue(event.tags, 'u');
    if (url == null) {
      if (!permissive) throw MissingTagException('u');
      missing.add('u');
    }

    final method = findTagValue(event.tags, 'method');
    if (method == null) {
      if (!permissive) throw MissingTagException('method');
      missing.add('method');
    }

    return HttpAuthData(
      url: url ?? '',
      method: method ?? '',
      payload: findTagValue(event.tags, 'payload'),
      pubkey: event.pubkey,
      createdAt: event.createdAt,
      missingTags: missing,
    );
  }

  /// Validates an HTTP auth event against the actual request parameters.
  ///
  /// Checks:
  /// 1. Event id + Schnorr signature are valid for the claimed pubkey
  /// 2. Event kind is 27235
  /// 3. `created_at` is not too old ([pastWindowSeconds], default 60) or
  ///    too far in the future ([futureWindowSeconds], default 30)
  /// 4. `u` tag matches [url]
  /// 5. `method` tag matches [method]
  /// 6. If [body] is provided, `payload` tag matches its SHA256 hash
  ///
  /// The signature check is critical: without it, anyone can claim any
  /// pubkey for an auth event. The check is performed even when [event]
  /// was obtained via [fromAuthHeader] (which also verifies) — defense
  /// in depth covers callers that build the [Event] another way.
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
    // Force the same validation EVENT's constructor does, but reraise
    // explicitly so callers building Event another way still get caught.
    // event.isValid() returns false instead of throwing, so we re-derive
    // the reason here by calling the typed validator via a temporary
    // reconstruction.
    if (!event.isValid()) {
      throw const EventValidationException(
        'Invalid auth event id or signature',
        EventValidationReason.invalidSignature,
      );
    }

    if (event.kind != kindHttpAuth) {
      throw InvalidKindException(event.kind, [kindHttpAuth]);
    }

    // Asymmetric timestamp check (like rust-nostr)
    final now = currentUnixTimestampSeconds();
    final delta = now - event.createdAt;
    if (delta > pastWindowSeconds || delta < -futureWindowSeconds) {
      throw TimestampOutOfWindowException(
        deltaSeconds: delta,
        maxPastSeconds: pastWindowSeconds,
        maxFutureSeconds: futureWindowSeconds,
      );
    }

    final data = parse(event);

    // URL check
    if (data.url != url) {
      throw FieldMismatchException('url', url, data.url);
    }

    // Method check
    if (data.method.toUpperCase() != method.toUpperCase()) {
      throw FieldMismatchException('method', method, data.method);
    }

    // Payload check
    if (body != null) {
      final expected = payloadHash(body);
      if (data.payload == null) {
        throw MissingTagException('payload');
      }
      if (data.payload != expected) {
        throw FieldMismatchException('payload', expected, data.payload ?? '');
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

  /// Names of spec-required tags that were absent when parsed in
  /// permissive mode (NIP-98: `u`, `method`). Empty in strict mode.
  final Set<String> missingTags;

  /// True when every spec-required tag was present at parse time.
  bool get isComplete => missingTags.isEmpty;

  /// Creates an [HttpAuthData].
  const HttpAuthData({
    required this.url,
    required this.method,
    required this.pubkey,
    required this.createdAt,
    this.payload,
    this.missingTags = const {},
  });
}

typedef Nip98 = HttpAuth;
