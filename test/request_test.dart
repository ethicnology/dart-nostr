import 'dart:convert';

import 'package:nostr/src/filter.dart';
import 'package:nostr/src/request.dart';
import 'package:test/test.dart';

void main() {
  group('Request', () {
    test('Constructor.toJson', () {
      const Filter myFilter = Filter(
        ids: [
          "047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"
        ],
        authors: [
          "0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db"
        ],
        kinds: [0, 1, 2, 7],
        eTags: [],
        aTags: [],
        pTags: [],
        since: 1672477960,
        until: 1674063680,
        limit: 450,
        search: "term",
      );

      const req =
          Request(subscriptionId: "733209259899167", filters: [myFilter]);

      expect(req.subscriptionId, "733209259899167");
      expect(req.filters[0].ids, myFilter.ids);
      expect(req.filters[0].authors, myFilter.authors);
      expect(req.filters[0].kinds, myFilter.kinds);
      expect(req.filters[0].eTags, myFilter.eTags);
      expect(req.filters[0].aTags, myFilter.aTags);
      expect(req.filters[0].pTags, myFilter.pTags);
      expect(req.filters[0].kinds, myFilter.kinds);
      expect(req.filters[0].since, myFilter.since);
      expect(req.filters[0].until, myFilter.until);
      expect(req.filters[0].limit, myFilter.limit);
      expect(req.filters[0].search, myFilter.search);
    });

    test('Request.serialize', () {
      const String serialized =
          '["REQ","733209259899167",{"ids":["047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"],"authors":["0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db"],"kinds":[0,1,2,7],"#e":[],"#a":[],"#p":[],"since":1672477960,"until":1674063680,"limit":450,"search":"term"},{"kinds":[0,1,2,7],"since":1673980547,"limit":450}]';
      final payload = json.encode([
        "REQ",
        "733209259899167",
        {
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
          "search": "term",
        },
        {
          "kinds": [0, 1, 2, 7],
          "since": 1673980547,
          "limit": 450
        }
      ]);
      final Request req = Request.deserialize(payload);
      expect(req.serialize(), serialized);
    });

    test('Request.serialize with empty filters', () {
      const req = Request(subscriptionId: 'id');
      expect(
        req.serialize(),
        '["REQ","id",{}]',
      );
    });

    test('Request.deserialize with empty filters', () {
      const payload = '["REQ","id",{}]';
      final req = Request.deserialize(payload);
      expect(req.subscriptionId, 'id');
      expect(req.filters.length, 1);
    });

    test('Request.deserialize', () {
      final payload = json.encode([
        "REQ",
        "733209259899167",
        {
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
          "search": "term",
        },
        {
          "kinds": [0, 1, 2, 7],
          "since": 1673980547,
          "limit": 450
        }
      ]);
      final Request req = Request.deserialize(payload);
      expect(req.subscriptionId, "733209259899167");
      expect(req.filters[0].ids,
          ["047663d895d56aefa3f528935c7ce7dc8939eb721a0ec76ef2e558a8257955d2"]);
      expect(req.filters[0].authors,
          ["0ba0206887bd61579bf65ec09d7806bea32c64be1cf2c978cf031a811cd238db"]);
      expect(req.filters[0].eTags, []);
      expect(req.filters[0].aTags, []);
      expect(req.filters[0].pTags, []);
      expect(req.filters[0].kinds, [0, 1, 2, 7]);
      expect(req.filters[0].since, 1672477960);
      expect(req.filters[0].until, 1674063680);
      expect(req.filters[0].limit, 450);
      expect(req.filters[0].search, "term");
      expect(req.filters[1].kinds, [0, 1, 2, 7]);
      expect(req.filters[1].since, 1673980547);
      expect(req.filters[1].limit, 450);
    });
  });
}
