import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/history_paywall_view.dart';
import 'package:raft_flutter/platform/web_billing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/history_paywall_fixture.dart';

/// Flutter renders for the Web | Flutter comparison (desktop width).
final _shot = GlobalKey();
const _captures = '/mnt/data/tmp/cindy/w24-bill/paywall';

Future<void> _capture(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final boundary =
        _shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    await Directory(_captures).create(recursive: true);
    await File('$_captures/$name.png').writeAsBytes(bytes.buffer.asUint8List());
  });
}

List<Map<String, dynamic>> _rows(String prefix, {int count = 3}) => [
  for (var i = 0; i < count; i++)
    {
      'id': '$prefix-$i',
      'channelId': 'c1',
      'seq': '${100 + i}',
      'senderId': 'alice',
      'senderType': 'user',
      'createdAt': '2026-11-10T10:0$i:00.000Z',
      'content': 'visible message $i',
    },
];

Map<String, dynamic> _limitedPage({
  List<Map<String, dynamic>>? messages,
  Object? hidden,
  bool withHidden = true,
}) => {
  'messages': messages ?? _rows('new'),
  'historyLimited': true,
  if (withHidden)
    'hiddenHistory':
        hidden ??
        {
          'hiddenCount': 12,
          'hiddenCountCapped': false,
          'parentHidden': false,
          'latest': [
            hiddenMessage('h1'),
            hiddenMessage('h2', sender: 'Dev', text: 'second'),
          ],
        },
};

Future<void> _mount(
  WidgetTester t,
  WorkspaceController w, {
  bool dark = false,
}) async {
  await t.runAsync(loadParityFonts);
  t.view.physicalSize = const Size(1000, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      supportedLocales: const [Locale('en'), Locale('zh')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: RepaintBoundary(
          key: _shot,
          child: RaftChatView(controller: w),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _select(WidgetTester t, WorkspaceController w) async {
  await t.runAsync(() async {
    await w.selectChannel(w.channel!, autoRead: false);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  await t.pumpAndSettle();
}

void main() {
  late Future<bool> Function(Uri) savedLauncher;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedLauncher = webBillingLauncher;
  });
  tearDown(() => webBillingLauncher = savedLauncher);

  group('title variants (Web titleFor)', () {
    HiddenHistory h(int count, {bool capped = false, bool parent = false}) =>
        HiddenHistory(
          hiddenCount: count,
          hiddenCountCapped: capped,
          parentHidden: parent,
          latest: const [],
        );
    final cases = <(String, HistoryPaywallScope, HiddenHistory?, bool, String)>[
      (
        'channel counted',
        HistoryPaywallScope.channel,
        h(12),
        false,
        '12 earlier messages are older than 30 days',
      ),
      (
        'channel one',
        HistoryPaywallScope.channel,
        h(1),
        false,
        '1 earlier message is older than 30 days',
      ),
      (
        'channel capped',
        HistoryPaywallScope.channel,
        h(500, capped: true),
        false,
        'Over 500 earlier messages are older than 30 days',
      ),
      (
        'channel uncounted',
        HistoryPaywallScope.channel,
        null,
        false,
        'Messages older than 30 days are hidden',
      ),
      (
        'channel zero',
        HistoryPaywallScope.channel,
        h(0),
        false,
        'Messages older than 30 days are hidden',
      ),
      (
        'channel all',
        HistoryPaywallScope.channel,
        h(3),
        true,
        'All 3 messages in this channel are older than 30 days',
      ),
      (
        'channel all one',
        HistoryPaywallScope.channel,
        h(1),
        true,
        "This channel's 1 message is older than 30 days",
      ),
      (
        'channel all capped',
        HistoryPaywallScope.channel,
        h(500, capped: true),
        true,
        "All of this channel's over 500 messages are older than 30 days",
      ),
      (
        'dm all',
        HistoryPaywallScope.dm,
        h(3),
        true,
        'All 3 messages here are older than 30 days',
      ),
      (
        'dm all one',
        HistoryPaywallScope.dm,
        h(1),
        true,
        'The 1 message here is older than 30 days',
      ),
      (
        'dm all capped',
        HistoryPaywallScope.dm,
        h(500, capped: true),
        true,
        'All of the over 500 messages here are older than 30 days',
      ),
      (
        'dm counted',
        HistoryPaywallScope.dm,
        h(4),
        false,
        '4 earlier messages are older than 30 days',
      ),
      (
        'task all',
        HistoryPaywallScope.task,
        h(3),
        true,
        'All 3 messages in this task are older than 30 days',
      ),
      (
        'task all one',
        HistoryPaywallScope.task,
        h(1),
        true,
        "This task's 1 message is older than 30 days",
      ),
      (
        'task all capped',
        HistoryPaywallScope.task,
        h(500, capped: true),
        true,
        "All of this task's over 500 messages are older than 30 days",
      ),
      (
        'thread replies',
        HistoryPaywallScope.thread,
        h(7),
        false,
        '7 replies are older than 30 days',
      ),
      (
        'thread reply one',
        HistoryPaywallScope.thread,
        h(1),
        false,
        '1 reply is older than 30 days',
      ),
      (
        'thread replies capped',
        HistoryPaywallScope.thread,
        h(500, capped: true),
        false,
        'Over 500 replies are older than 30 days',
      ),
      (
        'thread uncounted',
        HistoryPaywallScope.thread,
        null,
        false,
        'Replies older than 30 days are hidden',
      ),
      (
        'thread parent only',
        HistoryPaywallScope.thread,
        h(0, parent: true),
        false,
        'The first message is older than 30 days',
      ),
      (
        'thread parent + replies',
        HistoryPaywallScope.thread,
        h(7, parent: true),
        false,
        'The first message and 7 replies are older than 30 days',
      ),
      (
        'thread parent + one reply',
        HistoryPaywallScope.thread,
        h(1, parent: true),
        false,
        'The first message and 1 reply are older than 30 days',
      ),
      (
        'thread parent capped',
        HistoryPaywallScope.thread,
        h(500, parent: true, capped: true),
        false,
        'The first message and over 500 replies are older than 30 days',
      ),
      (
        'thread parent all',
        HistoryPaywallScope.thread,
        h(7, parent: true),
        true,
        'The first message and all 7 replies are older than 30 days',
      ),
      (
        'thread parent all one',
        HistoryPaywallScope.thread,
        h(1, parent: true),
        true,
        'The first message and its 1 reply are older than 30 days',
      ),
      (
        'thread parent all capped',
        HistoryPaywallScope.thread,
        h(500, parent: true, capped: true),
        true,
        'The first message and all of its over 500 replies are older than 30 days',
      ),
    ];
    for (final (name, scope, hidden, all, expected) in cases) {
      testWidgets(name, (t) async {
        late String title;
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                title = historyPaywallTitle(
                  context,
                  scope: scope,
                  hidden: hidden,
                  allHidden: all,
                  days: 30,
                );
                return const SizedBox();
              },
            ),
          ),
        );
        expect(title, expected);
      });
    }
  });

  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('$mode channel: counted card, glimpse, Upgrade opens the Web', (
      t,
    ) async {
      final opened = <Uri>[];
      webBillingLauncher = (uri) async {
        opened.add(uri);
        return true;
      };
      final (w, api) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/channel/c1'] = (_) => _limitedPage();
      await _mount(t, w, dark: dark);
      await _select(t, w);
      expect(
        find.text('12 earlier messages are older than 30 days'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free shows only the last 30 days. On Pro, all history can be read and searched.',
        ),
        findsOneWidget,
      );
      // The old one-line notice and the billing link are gone.
      expect(find.textContaining('Message history is limited'), findsNothing);
      expect(find.text('View billing'), findsNothing);
      // Glimpse: the two newest hidden messages, inert and out of semantics.
      final preview = find.byKey(const ValueKey('history-paywall-preview'));
      expect(preview, findsOneWidget);
      expect(find.text('older note'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );
      expect(find.bySemanticsLabel('older note'), findsNothing);
      // The first day divider under the card carries the window too.
      expect(find.text('Last 30 days · Tuesday, November 10'), findsOneWidget);
      // The visible window is still there.
      expect(find.textContaining('visible message 2'), findsOneWidget);

      await _capture(t, 'channel-start-flutter-$mode');
      await t.tap(find.byKey(const ValueKey('history-paywall-upgrade')));
      await t.pump();
      expect(opened.single.path, '/s/free-one/settings/billing');
      expect(opened.single.queryParameters['upgrade'], 'history_30d');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    testWidgets('$mode DM and task conversations use their own words', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(() => historyFixture(type: 'dm')))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/channel/c1'] = (_) => _limitedPage(
        messages: const [],
        hidden: {
          'hiddenCount': 3,
          'hiddenCountCapped': false,
          'parentHidden': false,
          'latest': [hiddenMessage('h1')],
        },
      );
      await _mount(t, w, dark: dark);
      await _select(t, w);
      // Every message is hidden: the DM wording and the notice under the card,
      // not "No messages yet".
      expect(
        find.text('All 3 messages here are older than 30 days'),
        findsOneWidget,
      );
      expect(find.text('No new messages in the last 30 days'), findsOneWidget);
      expect(find.text('No messages yet'), findsNothing);
      await _capture(t, 'channel-allhidden-flutter-$mode');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    testWidgets('$mode a page without hiddenHistory keeps the uncounted card', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/channel/c1'] = (_) =>
          _limitedPage(withHidden: false);
      await _mount(t, w, dark: dark);
      await _select(t, w);
      expect(
        find.text('Messages older than 30 days are hidden'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-paywall-preview')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    testWidgets('$mode a jump behind the window shows target mode', (t) async {
      final (w, api) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/channel/c1'] = (_) => _limitedPage();
      api.routes['GET /messages/context/old-1'] = (_) => (
        404,
        {
          'error': 'History limited',
          'code': 'history_limited',
          'channelId': 'c1',
          'targetMessageId': 'old-1',
          'hiddenTarget': {
            'target': {
              ...hiddenMessage('old-1', text: 'the target text'),
              'seq': 5,
            },
            'before': [hiddenMessage('b0', text: 'just before')],
            'after': [hiddenMessage('a0', text: 'just after')],
            'thread': null,
            'replies': {
              'count': 4,
              'latest': hiddenMessage(
                'rep-9',
                sender: 'Dev',
                text: 'latest reply',
              ),
            },
          },
        },
      );
      await _mount(t, w, dark: dark);
      await _select(t, w);
      await t.runAsync(() async {
        unawaited(w.jumpToMessage('c1', 'old-1'));
      });
      // The jump's context 404 and fallback page settle on real async work:
      // wait for the target card instead of a fixed delay (flaky under load).
      final title = find.text(
        "This thread's first message is older than 30 days",
      );
      for (var i = 0; i < 100 && title.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      await t.pumpAndSettle();
      expect(
        find.text("This thread's first message is older than 30 days"),
        findsOneWidget,
      );
      expect(find.text('the target text'), findsOneWidget);
      expect(find.text('just before'), findsOneWidget);
      expect(find.text('just after'), findsOneWidget);
      expect(find.text('4 replies'), findsOneWidget);
      // Not the plain "message not found" banner, not the start card.
      expect(find.text('Message not found'), findsNothing);
      await _capture(t, 'target-flutter-$mode');
      expect(
        find.byKey(const ValueKey('history-paywall-target')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-paywall-preview')),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
  }

  testWidgets('rows already shown do not move when the paywall arrives', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(historyFixture))!;
    addTearDown(w.dispose);
    final rows = _rows('old');
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': rows};
    await _mount(t, w);
    await _select(t, w);
    expect(find.byKey(const ValueKey('history-paywall-card')), findsNothing);
    final before = t.getBottomLeft(find.textContaining('visible message 2'));
    // The server now reports the cutoff on the same rows (revalidation).
    api.routes['GET /messages/channel/c1'] = (_) =>
        _limitedPage(messages: rows);
    await _select(t, w);
    expect(
      find.text('12 earlier messages are older than 30 days'),
      findsOneWidget,
    );
    // The newest row sits where it did: the paywall only adds above.
    expect(t.getBottomLeft(find.textContaining('visible message 2')), before);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });

  group('thread panel', () {
    Future<void> pumpThread(
      WidgetTester t,
      WorkspaceController w, {
      required bool allHidden,
      bool recentDivider = false,
      bool dark = false,
    }) async {
      await t.runAsync(loadParityFonts);
      t.view.physicalSize = const Size(440, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: RepaintBoundary(
              key: _shot,
              child: Builder(
                builder: (context) => ColoredBox(
                  color: RaftTokens.of(context).colors['layer-canvas']!,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: RaftHistoryPaywallView(
                        controller: w,
                        thread: true,
                        allHidden: allHidden,
                        recentDivider: recentDivider,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final dark in raftThemeMatrix([false, true])) {
      testWidgets(
        '${dark ? 'dark' : 'light'} parent hidden, replies in window: recent divider',
        (t) async {
          final (w, _) = (await t.runAsync(historyFixture))!;
          addTearDown(w.dispose);
          w.threadChannelId = 't1';
          w.client.hiddenHistory.recordPage('t1', {
            'historyLimited': true,
            'hiddenHistory': {
              'hiddenCount': 2,
              'hiddenCountCapped': false,
              'parentHidden': true,
              'latest': [hiddenMessage('p1', text: 'the first message')],
            },
          });
          await pumpThread(
            t,
            w,
            allHidden: false,
            recentDivider: true,
            dark: dark,
          );
          expect(
            find.text('The first message and 2 replies are older than 30 days'),
            findsOneWidget,
          );
          expect(find.text('the first message'), findsOneWidget);
          expect(find.text('Last 30 days'), findsOneWidget);
          expect(find.textContaining('No new replies'), findsNothing);
          await _capture(t, 'thread-flutter-${dark ? 'dark' : 'light'}');
        },
      );

      testWidgets(
        '${dark ? 'dark' : 'light'} all replies hidden: replies notice',
        (t) async {
          final (w, _) = (await t.runAsync(historyFixture))!;
          addTearDown(w.dispose);
          w.threadChannelId = 't1';
          w.client.hiddenHistory.recordPage('t1', {
            'historyLimited': true,
            'hiddenHistory': {
              'hiddenCount': 5,
              'hiddenCountCapped': false,
              'parentHidden': false,
              'latest': <Object>[],
            },
          });
          await pumpThread(t, w, allHidden: true, dark: dark);
          expect(find.text('5 replies are older than 30 days'), findsOneWidget);
          expect(
            find.text('No new replies in the last 30 days'),
            findsOneWidget,
          );
          expect(find.text('Last 30 days'), findsNothing);
        },
      );
    }

    testWidgets('a task conversation says "task", not "thread"', (t) async {
      final (w, _) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      w.threadChannelId = 't1';
      w.messageDomain.state.threadIdentity = WorkspaceThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'task:k1',
        taskId: 'k1',
      );
      w.client.hiddenHistory.recordPage('t1', {
        'historyLimited': true,
        'hiddenHistory': {
          'hiddenCount': 2,
          'hiddenCountCapped': false,
          'parentHidden': false,
          'latest': <Object>[],
        },
      });
      await pumpThread(t, w, allHidden: true);
      expect(
        find.text('All 2 messages in this task are older than 30 days'),
        findsOneWidget,
      );
      expect(find.text('No new messages in the last 30 days'), findsOneWidget);
    });
  });

  testWidgets('zh renders Web zh-cn wording', (t) async {
    final (w, api) = (await t.runAsync(historyFixture))!;
    addTearDown(w.dispose);
    api.routes['GET /messages/channel/c1'] = (_) => _limitedPage();
    t.view.physicalSize = const Size(1000, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: const Locale('zh'),
        supportedLocales: const [Locale('en'), Locale('zh')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await _select(t, w);
    expect(find.text('更早的 12 条消息超过了 30 天'), findsOneWidget);
    expect(find.text('升级到 Pro'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
}
