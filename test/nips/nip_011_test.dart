// NIP-11 (Relay Information Document) parser tests.

import 'package:nostr/nostr.dart';
import 'package:test/test.dart';

void main() {
  group('NIP-11 RelayInfo.parse', () {
    test('parses a fully populated document', () {
      final data = RelayInfoData.fromMap({
        'name': 'example relay',
        'description': 'A relay for testing.',
        'pubkey':
            'e8b487c079b0f67c695ae6c4c2552a47f38adfa2533cc5926bd2c102942fdcb7',
        'contact': 'admin@example.com',
        'supported_nips': [1, 2, 11, 44, 50, 65],
        'software': 'https://github.com/example/relay',
        'version': '1.2.3',
        'limitation': {
          'max_message_length': 16384,
          'max_subscriptions': 20,
          'max_filters': 100,
          'max_limit': 5000,
          'max_subid_length': 100,
          'min_prefix': 4,
          'max_event_tags': 100,
          'max_content_length': 8196,
          'min_pow_difficulty': 0,
          'auth_required': false,
          'payment_required': true,
          'restricted_writes': false,
        },
        'relay_countries': ['US', 'CA'],
        'language_tags': ['en', 'fr'],
        'tags': ['art', 'music'],
        'posting_policy': 'https://example.com/policy',
        'payments_url': 'https://example.com/pay',
        'fees': {
          'admission': [
            {'amount': 1000, 'unit': 'msats'}
          ]
        },
        'icon': 'https://example.com/icon.png',
      }, url: 'wss://example.com');

      expect(data.url, 'wss://example.com');
      expect(data.name, 'example relay');
      expect(data.description, 'A relay for testing.');
      expect(data.pubkey,
          'e8b487c079b0f67c695ae6c4c2552a47f38adfa2533cc5926bd2c102942fdcb7');
      expect(data.supportedNips, [1, 2, 11, 44, 50, 65]);
      expect(data.supports(44), isTrue);
      expect(data.supports(13), isFalse);
      expect(data.software, 'https://github.com/example/relay');
      expect(data.version, '1.2.3');
      expect(data.relayCountries, ['US', 'CA']);
      expect(data.languageTags, ['en', 'fr']);
      expect(data.tags, ['art', 'music']);
      expect(data.icon, 'https://example.com/icon.png');

      final lim = data.limitation!;
      expect(lim.maxMessageLength, 16384);
      expect(lim.maxSubscriptions, 20);
      expect(lim.maxFilters, 100);
      expect(lim.paymentRequired, isTrue);
      expect(lim.authRequired, isFalse);
    });

    test('parses an empty document without throwing', () {
      final data = RelayInfoData.fromMap({}, url: 'wss://x');
      expect(data.name, isNull);
      expect(data.supportedNips, isEmpty);
      expect(data.limitation, isNull);
      expect(data.tags, isEmpty);
    });

    test('coerces string supported_nips entries to ints', () {
      final data = RelayInfoData.fromMap({
        'supported_nips': [1, '2', 'not-a-number', 11],
      }, url: 'wss://x');
      expect(data.supportedNips, [1, 2, 11]);
    });

    test('drops wrong-typed fields silently', () {
      // Real relays send name as null, supported_nips as a string, etc.
      // We never throw — we just leave that field unset.
      final data = RelayInfoData.fromMap({
        'name': 42,
        'supported_nips': 'not a list',
        'limitation': 'not a map',
        'relay_countries': 'US',
      }, url: 'wss://x');
      expect(data.name, isNull);
      expect(data.supportedNips, isEmpty);
      expect(data.limitation, isNull);
      expect(data.relayCountries, isEmpty);
    });
  });
}
