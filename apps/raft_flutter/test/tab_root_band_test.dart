import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

/// Web v1.24 TabRootBar on the phone tab roots: the frame band (56 tall, the
/// seam below, 20px sides) with Home's WorkspaceButton and Search's field as
/// its `content`, and the one-line Search filter strip.
class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') return {'results': [], 'hasMore': false};
    if (path.endsWith('/members') || path == '/agents') return [];
    if (path.endsWith('/machines')) return [];
    return {};
  }
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets(
      'Home band $mode: workspace button, avatar and name, menu',
      (t) async {
        final (w, _) = await pageFixture(t);
        w.server = RaftRecord({'id': 's1', 'role': 'owner', 'name': 'Alpha'});
        w.setSection('home');
        await mountPage(t, w, dark, width: 390, height: 844, browserHost: true);
        final tokens = RaftTokens.of(
          t.element(find.byKey(const Key('mobile-server-selector'))),
        );
        final button = find.byType(RaftWorkspaceButton);
        expect(button, findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('mobile-server-selector')),
            matching: find.byType(RaftWorkspaceButton),
          ),
          findsOneWidget,
        );
        final avatar = find.descendant(
          of: button,
          matching: find.byType(RaftAvatarSlot),
        );
        expect(avatar, findsOneWidget);
        expect(t.getRect(avatar).left, 20, reason: '-ml-[11px] on the 20 edge');
        expect(
          find.descendant(of: button, matching: find.text('Alpha')),
          findsOneWidget,
        );
        final band = t.getRect(find.byType(RaftMobileRootHeader));
        expect(band.height, 56);
        final bell = find.byType(RaftMobileNotificationButton);
        expect(t.getRect(bell).right, 381, reason: 'Web: 9px from the edge');
        expect(
          tokens.colors['layer-section-header-mobile'],
          tokens.colors['layer-frame'],
        );
        await t.tap(button);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  group('Search tab root', () {
    late RaftClient client;
    late _Workspace w;
    setUp(() {
      client = RaftClient(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      )..user = RaftRecord({'id': 'owner', 'name': 'Owner'});
      client.selectServer('s');
      w = _Workspace(client)..server = RaftRecord({'id': 's', 'role': 'owner'});
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<void> mount(
      WidgetTester t, {
      required bool dark,
      bool root = true,
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: raftTheme(
            dark: dark,
          ).copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'search',
              mobileRoot: root,
              restoreSearchState: false,
              onBack: () {},
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('band $mode: frame fill, seam, field inset 20, no Back', (
        t,
      ) async {
        await mount(t, dark: dark);
        final head = find.byKey(const Key('search-tab-head'));
        expect(head, findsOneWidget);
        final tokens = RaftTokens.of(t.element(head));
        expect(t.getRect(head), const Rect.fromLTWH(0, 0, 390, 56));
        final box = t
            .widgetList<Container>(
              find.descendant(of: head, matching: find.byType(Container)),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.border != null);
        expect(box.color, tokens.colors['layer-frame']);
        expect(
          (box.border! as Border).bottom.color,
          tokens.colors['line-muted'],
        );
        final field = t.getRect(
          find.descendant(of: head, matching: find.byType(RaftSearchInput)),
        );
        expect(field.left, 20);
        expect(390 - field.right, 20);
        expect(find.byType(RaftMobileBackButton), findsNothing);
        expect(find.byTooltip('Back'), findsNothing);
      });
    }

    testWidgets('a pushed Search (not a tab root) keeps its Back', (t) async {
      await mount(t, dark: false, root: false);
      expect(find.byKey(const Key('search-tab-head')), findsNothing);
      expect(find.byTooltip('Back'), findsOneWidget);
    });

    testWidgets('filter strip is one line and the chips scroll sideways', (
      t,
    ) async {
      await mount(t, dark: false);
      double top(String text) => t.getRect(find.text(text)).center.dy;
      final line = top('From');
      for (final text in ['Scope', 'Channel', 'Any time', 'Relevant']) {
        expect(top(text), moreOrNear(line), reason: text);
      }
      final scroller = find.descendant(
        of: find.byType(RaftFitToolbar),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);
      final position = t
          .state<ScrollableState>(
            find.descendant(of: scroller, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.axis, Axis.horizontal);
      expect(position.maxScrollExtent, greaterThan(0));
      await t.drag(scroller, const Offset(-120, 0));
      await t.pump();
      expect(position.pixels, greaterThan(0));
      // The strip: 8 air, 32 controls, 8 air, the seam (49 by touch).
      final strip = t.getRect(find.byType(RaftFitToolbar));
      expect(strip.height, 32 + 0);
    });
  });
}

Matcher moreOrNear(double v) => closeTo(v, 1);
