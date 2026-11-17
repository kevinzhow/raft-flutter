import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_permalink.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/quoted_message_preview.dart';
import 'package:raft_flutter/platform/web_billing.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'parity/parity_harness.dart' show loadParityFonts;
import 'support/history_paywall_fixture.dart';

const _link = RaftPermalink(
  routeKind: 'channel',
  serverSlug: 'free-one',
  channelId: 'c1',
  messageId: 'old-1',
);

/// Where the Flutter renders of the quote's "older" state are kept.
const _captures = '/mnt/data/tmp/cindy/w24-bill/paywall';

Map<String, dynamic> _limited() => {
  'error': 'History limited',
  'code': 'history_limited',
  'channelId': 'c1',
  'targetMessageId': 'old-1',
  'hiddenTarget': {
    'target': {
      ...hiddenMessage('old-1', sender: 'Mina', text: 'secret old words'),
      'seq': 5,
    },
    'before': <Object>[],
    'after': <Object>[],
    'thread': null,
    'replies': null,
  },
};

void main() {
  late Future<bool> Function(Uri) savedLauncher;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedLauncher = webBillingLauncher;
  });
  tearDown(() => webBillingLauncher = savedLauncher);

  Future<void> mount(
    WidgetTester t,
    WorkspaceController w, {
    required bool dark,
    required GlobalKey shot,
    List<String>? opened,
    List<String>? unavailable,
  }) async {
    await t.runAsync(loadParityFonts);
    t.view.physicalSize = const Size(640, 180);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: RepaintBoundary(
            key: shot,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: QuotedMessagePermalinkPreview(
                  controller: w,
                  permalink: _link,
                  avatar: (m) => RaftAvatar(
                    name: m.string('senderName'),
                    size: 28,
                    mountedContext: RaftMountedAvatarContext.compactList,
                  ),
                  subtitle: (_) => null,
                  formatTimestamp: (d) => 'Sep 20, 7:00 PM',
                  onOpen: (l) => opened?.add(l.messageId),
                  onUnavailable: () => unavailable?.add('x'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      image.dispose();
      await Directory(_captures).create(recursive: true);
      await File('$_captures/$name.png')
          .writeAsBytes(bytes.buffer.asUint8List());
    });
  }

  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';

    testWidgets(
      '$mode a quote older than the window keeps its header and says so',
      (t) async {
        final (w, api) = (await t.runAsync(historyFixture))!;
        addTearDown(w.dispose);
        api.routes['GET /messages/context/old-1'] = (_) => (404, _limited());
        final shot = GlobalKey();
        final opened = <String>[], unavailable = <String>[];
        final launched = <Uri>[];
        webBillingLauncher = (uri) async {
          launched.add(uri);
          return true;
        };
        await mount(
          t,
          w,
          dark: dark,
          shot: shot,
          opened: opened,
          unavailable: unavailable,
        );
        // Who sent it, when and where, never what.
        expect(find.text('Mina'), findsOneWidget);
        expect(find.textContaining('Sep 20'), findsOneWidget);
        expect(
          find.text('This message is older than 30 days.'),
          findsOneWidget,
        );
        expect(find.textContaining('secret old words'), findsNothing);
        expect(unavailable, isEmpty);
        await capture(t, shot, 'quote-older-flutter-$mode');
        // The card is not a link; the notice's Upgrade is the one action.
        await t.tap(find.text('Mina'));
        expect(opened, isEmpty);
        await t.tap(
          find.byKey(const ValueKey('history-older-message-upgrade')),
        );
        await t.pump();
        expect(launched.single.path, '/s/free-one/settings/billing');
        expect(launched.single.queryParameters['upgrade'], 'history_30d');
      },
    );

    testWidgets('$mode a browser that cannot open says so instead of nothing', (
      t,
    ) async {
      final (w, api) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/context/old-1'] = (_) => (404, _limited());
      webBillingLauncher = (_) async => false;
      await mount(t, w, dark: dark, shot: GlobalKey());
      await t.tap(find.byKey(const ValueKey('history-older-message-upgrade')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Could not open this address.'), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
    });

    testWidgets('$mode any other failure still drops the quote', (t) async {
      final (w, api) = (await t.runAsync(historyFixture))!;
      addTearDown(w.dispose);
      api.routes['GET /messages/context/old-1'] = (_) =>
          (404, {'error': 'Message not found'});
      final unavailable = <String>[];
      await mount(
        t,
        w,
        dark: dark,
        shot: GlobalKey(),
        unavailable: unavailable,
      );
      expect(unavailable, ['x']);
      expect(find.textContaining('older than'), findsNothing);
      expect(find.byType(RaftQuotedMessageCard), findsNothing);
    });
  }
}
