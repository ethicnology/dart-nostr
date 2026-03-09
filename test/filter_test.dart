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

      final Filter filter = Filter.fromJson(json);
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
      final json = filter.toJson();
      expect(json['#e'], ['abc123']);
      expect(json['#p'], ['def456']);
      expect(json['#a'], ['30023:pk:id']);
    });
  });
}
