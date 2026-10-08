import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_flutter/features/search_ranking.dart';

void main() {
  test(
    'source rank preserves exact, token, pinyin and bounded fuzzy order',
    () {
      const entries = [
        SearchRankEntry('exact', [(text: '设计', priority: 0)]),
        SearchRankEntry('prefix', [(text: '设计频道', priority: 0)]),
        SearchRankEntry('description', [(text: 'A design guide', priority: 3)]),
      ];
      expect(rankSearchEntries('sheji', entries), ['exact', 'prefix']);
      expect(rankSearchEntries('sjpd', entries), ['prefix']);
      expect(rankSearchEntries('design', entries), ['description']);
      expect(
        rankSearchEntries('abc', [
          const SearchRankEntry('far', [
            (text: 'axxxxxxxxxbxxxxxxxxc', priority: 0),
          ]),
        ]),
        isEmpty,
      );
    },
  );
  test('entity rail excludes threads, deleted agents and daemon-only machines; prefixes preserve typed identity', () {
    List<SearchEntity> query(String q) => searchEntities(
      q,
      channels: [
        {'id': 'c', 'name': '设计', 'type': 'channel'},
        {'id': 't', 'name': '设计', 'type': 'thread'},
      ],
      computers: [
        {'id': 'd', 'name': '设计', 'isComputer': false},
        {'id': 'm', 'name': '设计', 'isComputer': true},
      ],
      agents: [
        {'id': 'a', 'name': '设计', 'displayName': ''},
        {'id': 'gone', 'name': '设计', 'deletedAt': '2026-10-08'},
      ],
      people: [
        {'userId': 'u', 'name': '设计', 'displayName': ''},
      ],
      principal: 'u',
    );
    expect(query('sheji').map((e) => e.key), [
      'channel:c',
      'computer:m',
      'agent:a',
      'user:u',
    ]);
    expect(query('#sheji').map((e) => e.key), ['channel:c']);
    expect(query('@sheji').map((e) => e.key), ['agent:a', 'user:u']);
    expect(query('me').single.key, 'user:u');
    expect(query('   '), isEmpty);
  });
  test(
    'free history cutoff honors exact trial boundaries and strict thirty days',
    () {
      expect(
        searchBeyondHistory(
          '2025-01-01',
          'free',
          DateTime.utc(2026, 6, 23, 11, 59),
        ),
        false,
      );
      expect(
        searchBeyondHistory(
          '2025-01-01',
          'free',
          DateTime.utc(2026, 6, 23, 12),
        ),
        true,
      );
      final now = DateTime.utc(2026, 10, 8);
      expect(
        searchBeyondHistory(
          now.subtract(const Duration(days: 30)).toIso8601String(),
          'free',
          now,
        ),
        false,
      );
      expect(
        searchBeyondHistory(
          now
              .subtract(const Duration(days: 30, milliseconds: 1))
              .toIso8601String(),
          'free',
          now,
        ),
        true,
      );
      expect(searchBeyondHistory('2025-01-01', 'pro', now), false);
    },
  );
  testWidgets(
    'highlight treats query punctuation literally and preserves text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant, dark: true),
          home: Scaffold(
            body: SearchHighlight(
              text: 'first [a.*] then [a.*]',
              query: '[a.*]',
              style: const TextStyle(),
            ),
          ),
        ),
      );
      final rich = tester.widget<Text>(find.byType(Text));
      expect(rich.textSpan!.toPlainText(), 'first [a.*] then [a.*]');
      final spans = (rich.textSpan as TextSpan).children!
          .whereType<TextSpan>()
          .where((s) => s.style != null)
          .toList();
      expect(spans.map((s) => s.text), ['[a.*]', '[a.*]']);
    },
  );
}
