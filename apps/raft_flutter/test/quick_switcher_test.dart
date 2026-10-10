import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/recent_conversations.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/quick_switcher_model.dart';
import 'package:raft_flutter/features/resource_search.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> channel(
  String id,
  String name, {
  Map<String, dynamic>? extra,
}) => {'id': id, 'name': name, 'type': 'channel', ...?extra};

QuickSwitcherCatalog catalog({
  Set<String> hidden = const {},
}) => QuickSwitcherCatalog(
  channels: [
    channel(
      'c-design',
      'design',
      extra: {'lastMessageAt': '2026-10-01T00:00:00Z'},
    ),
    channel(
      'c-general',
      'general',
      extra: {'lastMessageAt': '2026-10-09T00:00:00Z'},
    ),
    channel('c-ops', 'ops', extra: {'lastMessageAt': '2026-10-05T00:00:00Z'}),
    channel(
      'c-old',
      'old-project',
      extra: {'archivedAt': '2026-01-01T00:00:00Z'},
    ),
  ],
  dms: [
    {
      'id': 'dm-cindy',
      'type': 'dm',
      'peerId': 'a-cindy',
      'peerType': 'agent',
      'lastMessageAt': '2026-10-08T00:00:00Z',
    },
    {'id': 'dm-bob', 'type': 'dm', 'peerId': 'u-bob', 'peerType': 'user'},
  ],
  computers: [
    {'id': 'm1', 'name': 'design-box', 'isComputer': true, 'hostname': 'box'},
  ],
  agents: [
    {'id': 'a-cindy', 'name': 'cindy', 'displayName': 'Cindy'},
    {'id': 'a-new', 'name': 'newbie', 'displayName': ''},
  ],
  people: [
    {'userId': 'u-bob', 'name': 'bob', 'displayName': 'Bob'},
    {'userId': 'u-me', 'name': 'me', 'displayName': 'Me'},
  ],
  principal: 'u-me',
  hiddenDmIds: hidden,
);

QuickSwitcherData data({
  List<String> visited = const [],
  String? exclude,
  Set<String> hidden = const {},
  QuickSwitcherCatalog? catalogOverride,
}) => QuickSwitcherData(
  catalog: catalogOverride ?? catalog(hidden: hidden),
  visited: visited,
  agents: const [],
  members: const [],
  origin: 'https://public-fixture.invalid',
  excludeChannelId: exclude,
);

class _Opened {
  final entities = <String>[];
  final queries = <String>[];
  final messages = <String>[];
  var closed = 0;
}

Widget host(
  QuickSwitcherData Function() read,
  _Opened log, {
  Future<List<Map<String, dynamic>>> Function(String)? messages,
  ValueNotifier<int>? changes,
  RaftFamily family = RaftFamily.elegant,
  bool dark = false,
}) => MaterialApp(
  theme: raftTheme(family, dark: dark),
  home: Scaffold(
    body: Material(
      type: MaterialType.transparency,
      child: QuickSwitcher(
        listenable: changes ?? ValueNotifier(0),
        data: read,
        onClose: () => log.closed++,
        onOpenEntity: (e, q) {
          log.entities.add(e.key);
          log.queries.add(q);
        },
        onOpenMessage: (row, q) => log.messages.add('${row['id']}'),
        onSearchAll: (q) => log.queries.add('all:$q'),
        searchMessages: messages,
      ),
    ),
  ),
);

Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}

void main() {
  void size(WidgetTester t) {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  for (final theme in [
    (name: 'Brutal', family: RaftFamily.brutal, dark: false),
    (name: 'Elegant', family: RaftFamily.elegant, dark: false),
    (name: 'Elegant dark', family: RaftFamily.elegant, dark: true),
  ]) {
    testWidgets(
      '[N26] ${theme.name} recent conversations are in the first frame, newest visit first, current excluded',
      (t) async {
        size(t);
        final log = _Opened();
        await t.pumpWidget(
          host(
            () => data(
              visited: [
                'c-ops',
                'dm-cindy',
                'c-general',
                'c-design',
                'missing',
              ],
              exclude: 'c-general',
            ),
            log,
            family: theme.family,
            dark: theme.dark,
          ),
        );
        // No pump after the first frame: the rows are already final.
        expect(find.text('Recent conversations'), findsOneWidget);
        final titles = [
          for (final w in t.widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('quick-switcher-recent')),
              matching: find.byType(Text),
            ),
          ))
            w.data,
        ];
        expect(titles.indexOf('ops') < titles.indexOf('Cindy'), isTrue);
        expect(titles.indexOf('Cindy') < titles.indexOf('design'), isTrue);
        expect(titles, isNot(contains('general')));
        expect(find.byKey(const Key('quick-switcher-footer')), findsOneWidget);
        expect(find.text('ESC'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '[N26] a short history is padded with recently active conversations; hidden, archived and computers never appear',
    (t) async {
      size(t);
      final log = _Opened();
      await t.pumpWidget(
        host(() => data(visited: ['dm-bob'], hidden: {'dm-bob'}), log),
      );
      final shown = [
        for (final w in t.widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('quick-switcher-recent')),
            matching: find.byType(Text),
          ),
        ))
          w.data,
      ];
      // Activity order: general (10-09), Cindy (10-08), ops (10-05), design (10-01).
      expect(
        shown.where(['general', 'Cindy', 'ops', 'design'].contains).toList(),
        ['general', 'Cindy', 'ops', 'design'],
      );
      expect(shown, isNot(contains('Bob')));
      expect(shown, isNot(contains('old-project')));
      expect(shown, isNot(contains('design-box')));
    },
  );

  testWidgets('empty workspace shows the empty state', (t) async {
    size(t);
    final log = _Opened();
    await t.pumpWidget(
      host(
        () => data(
          catalogOverride: QuickSwitcherCatalog(
            channels: const [],
            dms: const [],
            computers: const [],
            agents: const [],
            people: const [],
          ),
        ),
        log,
      ),
    );
    expect(find.byKey(const Key('quick-switcher-empty')), findsOneWidget);
  });

  testWidgets(
    '[N26] keyboard: arrows move the cursor without wrapping, Return opens, Escape closes',
    (t) async {
      size(t);
      final log = _Opened();
      await t.pumpWidget(
        host(() => data(visited: ['c-ops', 'dm-cindy', 'c-design']), log),
      );
      await t.pump();
      await key(t, LogicalKeyboardKey.arrowUp); // clamped at the first row
      await key(t, LogicalKeyboardKey.enter);
      expect(log.entities, ['channel:c-ops']);
      await key(t, LogicalKeyboardKey.arrowDown);
      await key(t, LogicalKeyboardKey.arrowDown);
      await key(
        t,
        LogicalKeyboardKey.arrowDown,
      ); // clamped at the last of the visited rows
      await key(t, LogicalKeyboardKey.numpadEnter);
      expect(log.entities.last, isNot('channel:c-ops'));
      await key(t, LogicalKeyboardKey.escape);
      expect(log.closed, 1);
    },
  );

  testWidgets(
    '[N26] typing: exact destination first, then Search for, then fuzzy and pinyin-free ranking',
    (t) async {
      size(t);
      final log = _Opened();
      await t.pumpWidget(host(() => data(visited: ['c-ops']), log));
      await t.pump();
      await t.enterText(find.byType(TextField), 'design');
      await t.pump();
      expect(find.text('Recent conversations'), findsNothing);
      final order = t
          .widgetList<Widget>(
            find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey &&
                  '${(w.key as ValueKey).value}'.startsWith(
                    'quick-switcher-',
                  ) &&
                  ('${(w.key as ValueKey).value}'.contains(':')),
            ),
          )
          .map((w) => '${(w.key as ValueKey).value}')
          .toList();
      expect(order.first, 'quick-switcher-channel:c-design');
      expect(
        find.byKey(const Key('quick-switcher-all-results')),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(find.byKey(const Key('quick-switcher-all-results'))).dy >
            t
                .getTopLeft(
                  find.byKey(const ValueKey('quick-switcher-channel:c-design')),
                )
                .dy,
        isTrue,
      );
      // The cursor starts on the exact destination: Return enters it.
      await key(t, LogicalKeyboardKey.enter);
      expect(log.entities, ['channel:c-design']);
      expect(log.queries, ['design']);
    },
  );

  testWidgets(
    '[N26] without an exact destination Return opens the full results page with the query',
    (t) async {
      size(t);
      final log = _Opened();
      await t.pumpWidget(host(() => data(), log));
      await t.pump();
      await t.enterText(find.byType(TextField), 'dsgn');
      await t.pump();
      // Fuzzy subsequence still finds design.
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-design')),
        findsOneWidget,
      );
      await key(t, LogicalKeyboardKey.enter);
      expect(log.queries, ['all:dsgn']);
      expect(log.entities, isEmpty);
    },
  );

  testWidgets(
    '# and @ prefixes narrow the destinations and a handle is an exact match',
    (t) async {
      size(t);
      final log = _Opened();
      await t.pumpWidget(host(() => data(), log));
      await t.pump();
      await t.enterText(find.byType(TextField), '#design');
      await t.pump();
      expect(
        find.byKey(const ValueKey('quick-switcher-computer:m1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-design')),
        findsOneWidget,
      );
      await t.enterText(find.byType(TextField), '@cindy');
      await t.pump();
      await key(t, LogicalKeyboardKey.enter);
      expect(log.entities, ['agent:a-cindy']);
    },
  );

  testWidgets('clicking a row opens it exactly like Return', (t) async {
    size(t);
    final log = _Opened();
    await t.pumpWidget(host(() => data(visited: ['c-ops', 'c-design']), log));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('quick-switcher-channel:c-design')));
    await t.pump();
    expect(log.entities, ['channel:c-design']);
  });

  testWidgets('no match shows the empty message but keeps Search for', (
    t,
  ) async {
    size(t);
    final log = _Opened();
    await t.pumpWidget(host(() => data(), log));
    await t.pump();
    await t.enterText(find.byType(TextField), 'zzzzqq');
    await t.pump();
    expect(find.byKey(const Key('quick-switcher-no-results')), findsOneWidget);
    expect(find.byKey(const Key('quick-switcher-all-results')), findsOneWidget);
  });

  testWidgets(
    'message preview is debounced, capped, fenced against stale answers and opens on Return',
    (t) async {
      size(t);
      final log = _Opened();
      final calls = <String>[];
      final pending = <String, Completer<List<Map<String, dynamic>>>>{};
      await t.pumpWidget(
        host(
          () => data(),
          log,
          messages: (q) {
            calls.add(q);
            return (pending[q] = Completer()).future;
          },
        ),
      );
      await t.pump();
      await t.enterText(find.byType(TextField), 'qu');
      await t.pump(const Duration(milliseconds: 50));
      await t.enterText(find.byType(TextField), 'quarter');
      await t.pump(const Duration(milliseconds: 250));
      expect(calls, ['quarter']); // the first keystroke never queried
      expect(find.byKey(const Key('quick-switcher-searching')), findsOneWidget);
      pending['quarter']!.complete([
        for (var i = 0; i < 8; i++)
          {
            'id': 'm$i',
            'channelId': 'c-ops',
            'channelName': 'ops',
            'channelType': 'channel',
            'senderName': 'Bob',
            'snippet': 'quarter plan $i',
            'createdAt': '2026-10-09T00:00:00Z',
          },
      ]);
      await t.pump();
      await t.pump();
      expect(
        find.textContaining('quarter plan', findRichText: true),
        findsNWidgets(5),
      );
      await key(t, LogicalKeyboardKey.arrowDown); // past "Search for"
      await key(t, LogicalKeyboardKey.enter);
      expect(log.messages, ['m0']);
    },
  );

  testWidgets('a late answer for an earlier query is dropped', (t) async {
    size(t);
    final log = _Opened();
    final pending = <String, Completer<List<Map<String, dynamic>>>>{};
    await t.pumpWidget(
      host(
        () => data(),
        log,
        messages: (q) => (pending[q] = Completer()).future,
      ),
    );
    await t.pump();
    await t.enterText(find.byType(TextField), 'alpha');
    await t.pump(const Duration(milliseconds: 250));
    await t.enterText(find.byType(TextField), 'beta');
    await t.pump(const Duration(milliseconds: 250));
    pending['alpha']!.complete([
      {
        'id': 'stale',
        'channelId': 'c-ops',
        'channelName': 'ops',
        'channelType': 'channel',
        'snippet': 'stale alpha',
      },
    ]);
    await t.pump();
    expect(
      find.textContaining('stale alpha', findRichText: true),
      findsNothing,
    );
  });

  testWidgets(
    'workspace updates refresh rows in place without losing the typed query',
    (t) async {
      size(t);
      final log = _Opened();
      final changes = ValueNotifier(0);
      var channels = ['design'];
      await t.pumpWidget(
        host(
          () => data(
            catalogOverride: QuickSwitcherCatalog(
              channels: [for (final n in channels) channel('c-$n', n)],
              dms: const [],
              computers: const [],
              agents: const [],
              people: const [],
            ),
            visited: const [],
          ),
          log,
          changes: changes,
        ),
      );
      await t.enterText(find.byType(TextField), 'des');
      await t.pump();
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-design')),
        findsOneWidget,
      );
      channels = ['design', 'desk'];
      changes.value++;
      await t.pump();
      expect(
        find.byKey(const ValueKey('quick-switcher-channel:c-desk')),
        findsOneWidget,
      );
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'des',
      );
    },
  );

  testWidgets('Ctrl/Cmd+K inside the switcher keeps it open', (t) async {
    size(t);
    final log = _Opened();
    await t.pumpWidget(host(() => data(), log));
    await t.pump();
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(log.closed, 0);
  });

  test('card geometry follows the Web fallback placement', () {
    final r = QuickSwitcher.cardRect(const Size(1280, 1000));
    expect(r.width, 720);
    expect(r.height, 680);
    expect(r.top, 160);
    final small = QuickSwitcher.cardRect(const Size(500, 700));
    expect(small.width, closeTo(460, .01));
    expect(small.top, closeTo(72, .01));
  });

  test(
    'recent store: most recent first, deduped, capped, per scope, synchronous',
    () {
      expect(pushRecentConversation(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
      expect(
        pushRecentConversation(List.generate(20, (i) => 'x$i'), 'n').length,
        20,
      );
      expect(normalizeRecentConversationIds(['a', 'a', 3, '', 'b']), [
        'a',
        'b',
      ]);
    },
  );
}
