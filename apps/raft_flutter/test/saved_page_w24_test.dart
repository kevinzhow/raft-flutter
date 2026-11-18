// Web v1.24 SavedPanel.tsx / savedStore.ts: history window banner, page size
// 50, BookmarkMinus, truncating channel label, pull to refresh, first load.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/platform/web_billing.dart';
import 'package:raft_ui/raft_ui.dart';

class _Api extends RaftClient {
  _Api()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async => {};
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final savedQueries = <Map<String, dynamic>?>[];
  FutureOr<dynamic> Function() saved = () => {'saved': [], 'total': 0};
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/channels/saved') {
      savedQueries.add(query);
      return await saved();
    }
    if (path.endsWith('/members') || path == '/agents') return [];
    return {};
  }
}

Map<String, dynamic> _row(
  String id, {
  String channel = 'design',
  String type = 'channel',
}) => {
  'messageId': id,
  'channelId': 'c-$id',
  'channelName': channel,
  'channelType': type,
  if (type == 'thread') ...{
    'parentChannelId': 'c-parent',
    'parentChannelName': channel,
    'parentChannelType': 'channel',
    'parentMessageId': 'p-$id',
  },
  'senderType': 'user',
  'senderId': 'u1',
  'senderName': 'Alice',
  'content': 'Saved body $id',
  'createdAt': '2026-10-28T01:00:00Z',
};

void main() {
  late _Api api;
  late _Workspace w;
  setUp(() {
    api = _Api()..user = RaftRecord({'id': 'u0', 'displayName': 'me'});
    api.selectServer('s');
    w = _Workspace(api)
      ..server = RaftRecord({'id': 's', 'role': 'owner', 'slug': 'acme'});
  });
  tearDown(() async {
    w.dispose();
    await api.dispose();
  });

  Future<void> mount(
    WidgetTester t, {
    Size size = const Size(1000, 800),
    TargetPlatform? platform,
    bool settle = true,
    Locale? locale,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final base = raftTheme(dark: false);
    await t.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: locale == null ? const [Locale('en')] : [locale],
        theme: platform == null ? base : base.copyWith(platform: platform),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: 'saved',
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    if (settle) await t.pumpAndSettle();
  }

  const banner = ValueKey('saved-history-hidden');

  testWidgets('hidden history with rows shows the info banner and rows', (
    t,
  ) async {
    w.saved = () => {
      'saved': [_row('a'), _row('b')],
      'total': 2,
      'historyHidden': {'count': 3},
    };
    await mount(t);
    expect(find.byKey(banner), findsOneWidget);
    expect(
      find.textContaining(
        "3 more saved messages are older than 30 days",
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Saved body a'), findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsOneWidget);
  });

  testWidgets(
    'hidden history with an empty list shows the banner, not the empty state',
    (t) async {
      w.saved = () => {
        'saved': [],
        'total': 0,
        'historyHidden': {'count': 2},
      };
      await mount(t);
      expect(
        find.textContaining(
          'All 2 of your saved messages are older than 30 days',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text('No saved messages yet'), findsNothing);
    },
  );

  testWidgets('banner copy follows the zh catalog', (t) async {
    w.saved = () => {
      'saved': [_row('a')],
      'total': 1,
      'historyHidden': {'count': 3},
    };
    await mount(t, locale: const Locale('zh'));
    expect(
      find.textContaining('另有 3 条保存的消息超过了 30 天，没有列出。', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('no banner without hidden history; empty state stays', (t) async {
    await mount(t);
    expect(find.byKey(banner), findsNothing);
    expect(find.text('No saved messages yet'), findsOneWidget);
  });

  testWidgets('Upgrade to Pro opens the Web billing settings', (t) async {
    final opened = <Uri>[];
    final previous = webBillingLauncher;
    webBillingLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => webBillingLauncher = previous);
    w.saved = () => {
      'saved': [_row('a')],
      'total': 1,
      'historyHidden': {'count': 1},
    };
    await mount(t);
    await t.tap(find.text('Upgrade to Pro'));
    await t.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.path, '/s/acme/settings/billing');
    // Web paywallUpgrade("history_30d", "saved").
    expect(opened.single.queryParameters['upgrade'], 'history_30d');
    expect(t.takeException(), isNull);
  });

  // Behaviour rule (Kevin 537b93f1): Web's Upgrade cannot fail to open; a
  // browser that refuses the link must say so, not do nothing.
  testWidgets('Upgrade to Pro says so when the browser cannot open', (t) async {
    final previous = webBillingLauncher;
    webBillingLauncher = (uri) async => false;
    addTearDown(() => webBillingLauncher = previous);
    w.saved = () => {
      'saved': [_row('a')],
      'total': 1,
      'historyHidden': {'count': 1},
    };
    await mount(t);
    expect(find.text('Could not open this address.'), findsNothing);
    await t.tap(find.text('Upgrade to Pro'));
    await t.pumpAndSettle();
    expect(find.text('Could not open this address.'), findsOneWidget);
  });

  testWidgets('first page asks for 50 rows', (t) async {
    await mount(t);
    expect(w.savedQueries.first?['limit'], 50);
  });

  testWidgets('unsave toggle, menu entry and thread mark use the 1.24 glyphs', (
    t,
  ) async {
    w.saved = () => {
      'saved': [_row('a', type: 'thread')],
      'total': 1,
    };
    await mount(t);
    bool glyph(Finder within, RaftGlyph g) => t
        .widgetList<RaftIcon>(
          find.descendant(of: within, matching: find.byType(RaftIcon)),
        )
        .any((i) => i.glyph == g);
    final row = find.byKey(const ValueKey('saved-a'));
    expect(
      glyph(find.byType(RaftSavedToggle), RaftGlyph.bookmarkMinus),
      isTrue,
    );
    expect(
      glyph(find.byType(RaftSavedToggle), RaftGlyph.bookmarkFilled),
      isFalse,
    );
    expect(glyph(row, RaftGlyph.thread), isTrue);
    expect(glyph(row, RaftGlyph.messageSquare), isFalse);
    await t.tap(row, buttons: kSecondaryButton);
    await t.pumpAndSettle();
    final entry = find.ancestor(
      of: find.text('Remove from Saved'),
      matching: find.byType(Row),
    );
    expect(glyph(entry.first, RaftGlyph.bookmarkMinus), isTrue);
  });

  testWidgets(
    'a long channel label truncates; thread mark and time stay whole',
    (t) async {
      w.saved = () => {
        'saved': [_row('a', channel: 'x' * 120, type: 'thread')],
        'total': 1,
      };
      await mount(t, size: const Size(342, 700));
      expect(t.takeException(), isNull);
      final label = find.textContaining('xxxx');
      expect(t.widget<Text>(label).overflow, TextOverflow.ellipsis);
      expect(t.getSize(find.text('Thread')).width, greaterThan(20));
      expect(t.getRect(find.text('Thread')).right, lessThan(342));
    },
  );

  testWidgets('pull to refresh failure keeps the rows and warns', (t) async {
    w.saved = () => {
      'saved': [_row('a'), _row('b')],
      'total': 2,
    };
    await mount(
      t,
      size: const Size(390, 844),
      platform: TargetPlatform.android,
    );
    expect(find.byType(RaftPullToRefresh), findsOneWidget);
    final reads = w.savedQueries.length;
    w.saved = () => throw StateError('offline');
    await t.drag(find.byType(RaftPullToRefresh), const Offset(0, 360));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(w.savedQueries.length, greaterThan(reads));
    expect(find.text("Couldn't load saved messages."), findsOneWidget);
    expect(find.text('Saved body a'), findsOneWidget);
    expect(find.text('Saved body b'), findsOneWidget);
    // Web shows the toast only: no inline error line over the kept rows.
    expect(find.byType(RaftErrorBanner), findsNothing);
  });

  testWidgets('no "0 saved items" subtitle during the first load', (t) async {
    final gate = Completer<void>();
    w.saved = () async {
      await gate.future;
      return {
        'saved': [_row('a'), _row('b')],
        'total': 2,
      };
    };
    await mount(t, settle: false);
    await t.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('0 saved item'), findsNothing);
    expect(find.textContaining('saved item'), findsNothing);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('2 saved items'), findsOneWidget);
  });
}
