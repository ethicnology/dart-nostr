import 'package:nostr/src/error.dart';
import 'package:nostr/src/namecoin/electrumx_client.dart';
import 'package:nostr/src/namecoin/identifier.dart';
import 'package:nostr/src/namecoin/value.dart';
import 'package:nostr/src/nips/nip_005.dart';

/// NIP-05 identifier resolution backed by Namecoin `.bit` names —
/// the cypherpunk twin of [DnsIdentifier].
///
/// Where [DnsIdentifier] resolves `alice@example.com` against
/// `https://example.com/.well-known/nostr.json`, [NamecoinIdentifier]
/// resolves `alice@example.bit` against the `d/example` record on the
/// Namecoin blockchain via a public ElectrumX server.
///
/// Accepted identifier shapes (case-insensitive, optional `nostr:`
/// URI prefix tolerated):
///
///   * `<anything>.bit`
///   * `alice@<anything>.bit`
///   * `d/<name>`
///   * `id/<name>`
///
/// Both name value shapes are supported:
///
///   * the simple `"nostr": "hex-pubkey"` form, and
///   * the extended `"nostr": { "names": {...}, "relays": {...} }`
///     form used by Amethyst and the `.bit` NIP-05 spec draft.
///
/// The returned [DnsData] uses the same shape as [DnsIdentifier] so
/// downstream code paths don't have to branch.
class NamecoinIdentifier {
  /// Returns `true` when [identifier] should be routed to Namecoin
  /// resolution instead of DNS-based NIP-05.
  static bool isBit(String? identifier) => isBitIdentifier(identifier);

  /// Fetches the Namecoin-backed NIP-05 identity for [identifier].
  ///
  /// [client] is optional — if `null`, a [DefaultElectrumxClient]
  /// using `defaultElectrumxServers` is created and disposed for the
  /// duration of the call.
  ///
  /// Returns `null` when:
  ///   * [identifier] is not a valid Namecoin shape, or
  ///   * the Namecoin name is unregistered / expired, or
  ///   * the name value lacks a valid `nostr` field for the requested
  ///     local-part, or
  ///   * every configured ElectrumX server failed.
  static Future<DnsData?> fetch(
    String identifier, {
    ElectrumxClient? client,
  }) async {
    final parsed = parseIdentifier(identifier);
    if (parsed == null) return null;

    final ownsClient = client == null;
    final activeClient = client ?? DefaultElectrumxClient();
    String valueJson;
    try {
      valueJson = await activeClient.nameShow(parsed.namecoinName);
    } on Exception {
      return null;
    } finally {
      if (ownsClient) {
        await activeClient.close();
      }
    }

    final entry = extractNostrFromValue(valueJson, parsed);
    if (entry == null) return null;

    final cleanedIdentifier = identifier.toLowerCase().startsWith('nostr:')
        ? identifier.substring(6)
        : identifier;
    final atIdx = cleanedIdentifier.indexOf('@');
    final name =
        atIdx >= 0 ? cleanedIdentifier.substring(0, atIdx).toLowerCase() : '_';
    final domain = atIdx >= 0
        ? cleanedIdentifier.substring(atIdx + 1).toLowerCase()
        : cleanedIdentifier.toLowerCase();

    return DnsData(
      name: name.isEmpty ? '_' : name,
      domain: domain,
      pubkey: entry.pubkey,
      relays: entry.relays,
    );
  }

  /// Verifies a Namecoin `.bit` [identifier] resolves to [pubkey].
  ///
  /// Returns `false` on any lookup failure (so the signature matches
  /// [DnsIdentifier.verify]).
  static Future<bool> verify({
    required String identifier,
    required String pubkey,
    ElectrumxClient? client,
  }) async {
    final result = await fetch(identifier, client: client);
    if (result == null) return false;
    return result.pubkey.toLowerCase() == pubkey.toLowerCase();
  }

  /// Returns a pseudo-URI describing the on-chain query that would be
  /// performed for [identifier].
  ///
  /// The form is `namecoin:d/<name>?local=<localPart>` — useful for
  /// logging and diagnostics. Throws [NostrException] if [identifier]
  /// is not a Namecoin shape.
  static Uri lookupUri(String identifier) {
    final parsed = parseIdentifier(identifier);
    if (parsed == null) {
      throw const NostrException('Invalid Namecoin identifier');
    }
    return Uri(
      scheme: 'namecoin',
      path: parsed.namecoinName,
      queryParameters: {'local': parsed.localPart},
    );
  }
}

/// Convenience alias following the `Nip<NN>` convention used elsewhere
/// in this library.
typedef Nip5Namecoin = NamecoinIdentifier;

/// Convenience dispatcher: routes `.bit` identifiers to
/// [NamecoinIdentifier] and DNS identifiers to [DnsIdentifier].
///
/// Use this when call sites accept either form and don't need to
/// branch themselves:
///
/// ```dart
/// final profile = await NostrIdentifier.fetch(input);
/// ```
class NostrIdentifier {
  /// Resolves [identifier] against Namecoin (when `.bit` / `d/` /
  /// `id/`) or DNS-based NIP-05 (otherwise). Returns `null` on any
  /// resolution failure.
  static Future<DnsData?> fetch(
    String identifier, {
    ElectrumxClient? client,
  }) async {
    if (NamecoinIdentifier.isBit(identifier)) {
      return NamecoinIdentifier.fetch(identifier, client: client);
    }
    return DnsIdentifier.fetch(identifier);
  }

  /// Verifies [identifier] resolves to [pubkey], dispatching on the
  /// identifier shape. Returns `false` on any lookup failure.
  static Future<bool> verify({
    required String identifier,
    required String pubkey,
    ElectrumxClient? client,
  }) async {
    if (NamecoinIdentifier.isBit(identifier)) {
      return NamecoinIdentifier.verify(
        identifier: identifier,
        pubkey: pubkey,
        client: client,
      );
    }
    return DnsIdentifier.verify(identifier: identifier, pubkey: pubkey);
  }
}
