import 'package:nostr/src/filter.dart';
import 'package:test/test.dart';

void main() {
  group('Filter', () {
    test('Default constructor', () {
      final List<String> ids = [
        "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"
      ];
      final List<String> authors = [
        "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db"
      ];
      final List<int> kinds = [0, 1, 2, 7];
      final List<String> eTags = [];
      final List<String> aTags = [];
      final List<String> pTags = [];
      const int since = 1672477960;
      const int until = 1674063680;
      const int limit = 450;
      const String search = "term";

      final Filter filter = Filter(
        ids: ids,
        authors: authors,
        kinds: kinds,
        eTags: eTags,
        aTags: aTags,
        pTags: pTags,
        since: since,
        until: until,
        limit: limit,
        search: search,
      );

      expect(filter.ids, ids);
      expect(filter.authors, authors);
      expect(filter.kinds, kinds);
      expect(filter.eTags, eTags);
      expect(filter.aTags, aTags);
      expect(filter.pTags, pTags);
      expect(filter.since, since);
      expect(filter.until, until);
      expect(filter.limit, limit);
      expect(filter.search, search);
    });

    test('Constructor.fromJson', () {
      final json = {
        "ids": [
          "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"
        ],
        "authors": [
          "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db"
        ],
        "kinds": [0, 1, 2, 7],
        "#e": [],
        "#a": [],
        "#p": [],
        "since": 1672477960,
        "until": 1674063680,
        "limit": 450,
        "search": "test",
      };

      final Filter filter = Filter.fromMap(json);
      expect(filter.ids, json['ids']);
      expect(filter.authors, json['authors']);
      expect(filter.kinds, json['kinds']);
      expect(filter.eTags, json['#e']);
      expect(filter.aTags, json['#a']);
      expect(filter.pTags, json['#p']);
      expect(filter.since, json['since']);
      expect(filter.until, json['until']);
      expect(filter.limit, json['limit']);
      expect(filter.search, json['search']);
    });

    test('toJson serializes tag filters with # prefix', () {
      const filter = Filter(
        eTags: ['abc123'],
        pTags: ['def456'],
        aTags: ['30023:pk:id'],
      );
      final map = filter.toMap();
      expect(map['#e'], ['abc123']);
      expect(map['#p'], ['def456']);
      expect(map['#a'], ['30023:pk:id']);
    });

    test('tagFilters serializes generic #X keys', () {
      const filter = Filter(
        tagFilters: {
          't': ['nostr', 'bitcoin'],
          'd': ['my-article-id'],
          'r': ['wss://relay.example.com'],
        },
      );
      final map = filter.toMap();
      expect(map['#t'], ['nostr', 'bitcoin']);
      expect(map['#d'], ['my-article-id']);
      expect(map['#r'], ['wss://relay.example.com']);
    });

    test('fromJson collects generic #X keys into tagFilters', () {
      final filter = Filter.fromMap({
        '#t': ['nostr'],
        '#d': ['article-1'],
        '#k': ['1'],
      });
      expect(filter.tagFilters!['t'], ['nostr']);
      expect(filter.tagFilters!['d'], ['article-1']);
      expect(filter.tagFilters!['k'], ['1']);
    });

    test('convenience fields win over tagFilters entry', () {
      const filter = Filter(
        eTags: ['from-eTags'],
        tagFilters: {
          'e': ['from-tagFilters'],
        },
      );
      expect(filter.toMap()['#e'], ['from-eTags']);
    });

    test('non-letter and multi-char tag-filter keys are ignored', () {
      const filter = Filter(
        tagFilters: {
          'too-long': ['x'],
          '1': ['y'],
          '#': ['z'],
        },
      );
      final map = filter.toMap();
      expect(map.keys.where((k) => k.startsWith('#')), isEmpty);
    });

    test('round-trip preserves every populated field', () {
      final original = Filter(
        ids: ['a' * 64],
        authors: ['b' * 64],
        kinds: [1, 7, 30023],
        eTags: ['c' * 64],
        aTags: ['30023:author:slug'],
        pTags: ['d' * 64],
        tagFilters: {
          't': ['nostr', 'dart'],
          'd': ['my-article'],
          'K': ['1'],
        },
        since: 1700000000,
        until: 1800000000,
        limit: 100,
        search: 'bitcoin',
      );
      final round = Filter.fromJson(original.toJson());
      expect(round.ids, original.ids);
      expect(round.authors, original.authors);
      expect(round.kinds, original.kinds);
      expect(round.eTags, original.eTags);
      expect(round.aTags, original.aTags);
      expect(round.pTags, original.pTags);
      expect(round.tagFilters!['t'], original.tagFilters!['t']);
      expect(round.tagFilters!['d'], original.tagFilters!['d']);
      expect(round.tagFilters!['K'], original.tagFilters!['K']);
      expect(round.since, original.since);
      expect(round.until, original.until);
      expect(round.limit, original.limit);
      expect(round.search, original.search);
    });

    test('accepts uppercase single-letter tag keys (e.g. #K, #A)', () {
      final filter = Filter.fromMap({
        '#K': ['1'],
        '#A': ['30023:author:slug'],
      });
      expect(filter.tagFilters!['K'], ['1']);
      expect(filter.tagFilters!['A'], ['30023:author:slug']);
    });

    test('rejects non-ASCII single-letter tag keys', () {
      // Unicode "letter" Ω is not allowed by NIP-01; ASCII-only.
      final filter = Filter.fromMap({
        '#Ω': ['x'],
        '#t': ['nostr'],
      });
      expect(filter.tagFilters!.containsKey('Ω'), isFalse);
      expect(filter.tagFilters!['t'], ['nostr']);
    });
  });
}
