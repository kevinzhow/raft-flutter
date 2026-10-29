import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });
  for (final dark in [false, true]) {
    for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
      testWidgets(
        '$platform/$dark top bar follows source geometry and actions',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(856, 944);
          addTearDown(t.view.reset);
          final menu = RaftMenuController();
          addTearDown(menu.dispose);
          var searches = 0, picks = 0;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: Column(
                  children: [
                    RaftWorkspaceTopBar(
                      workspace: RaftServerSwitcher(
                        controller: menu,
                        workspaceName: 'Visual Server',
                        label: 'Switch Server',
                        topBar: true,
                        rows: [
                          RaftServerMenuRow(
                            id: 'v',
                            name: 'Visual Server',
                            slug: 'v',
                            current: true,
                            onSelected: () {},
                          ),
                          RaftServerMenuRow(
                            id: 'a',
                            name: 'Archive',
                            slug: 'a',
                            onSelected: () => picks++,
                          ),
                        ],
                        actions: const [],
                      ),
                      onSearch: () => searches++,
                    ),
                  ],
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final search = find.byKey(const Key('topbar-search'));
          expect(t.getRect(search), const Rect.fromLTWH(248, 5.5, 360, 36));
          expect(t.getRect(find.byKey(const Key('topbar-workspace'))).left, 8);
          expect(
            t.getSize(find.byKey(const ValueKey('topbar-workspace-v'))),
            const Size(32, 32),
          );
          expect(
            t.getRect(find.byKey(const ValueKey('topbar-workspace-v'))).left,
            156,
          );
          expect(
            t.getRect(find.byKey(const ValueKey('topbar-workspace-a'))).left,
            192,
          );
          await t.tapAt(Offset(t.getCenter(search).dx, 1));
          expect(searches, platform == TargetPlatform.android ? 1 : 0);
          await t.tap(search);
          expect(searches, platform == TargetPlatform.android ? 2 : 1);
          final other = find.byKey(const ValueKey('topbar-workspace-a'));
          await t.tapAt(Offset(t.getCenter(other).dx, 1));
          expect(picks, platform == TargetPlatform.android ? 1 : 0);
          await t.tap(other);
          expect(picks, platform == TargetPlatform.android ? 2 : 1);
          final nameButton = find.byKey(const Key('topbar-workspace'));
          await t.tapAt(
            Offset(
              t.getCenter(nameButton).dx,
              platform == TargetPlatform.android ? 1 : 23.5,
            ),
          );
          await t.pumpAndSettle();
          expect(find.byKey(const Key('server-switcher-menu')), findsOneWidget);
          await t.tapAt(
            Offset(
              t.getCenter(nameButton).dx,
              platform == TargetPlatform.android ? 1 : 23.5,
            ),
          );
          await t.pumpAndSettle();
          expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
          await t.tap(nameButton);
          await t.pumpAndSettle();
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
          expect(find.byKey(const Key('server-switcher-menu')), findsNothing);
          t.view.physicalSize = const Size(768, 944);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('topbar-workspace-v')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('topbar-workspace-a')),
            findsNothing,
          );
          expect(t.getRect(search).center.dx, 384);
          t.view.physicalSize = const Size(856, 944);
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('topbar-workspace-a')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
  for (final dark in [false, true]) {
    testWidgets('current outside strip paints its separator/$dark', (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(856, 944);
      addTearDown(t.view.reset);
      final menu = RaftMenuController();
      addTearDown(menu.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Column(
              children: [
                RaftWorkspaceTopBar(
                  workspace: RaftServerSwitcher(
                    controller: menu,
                    workspaceName: 'G',
                    label: 'Switch Server',
                    topBar: true,
                    rows: [
                      for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g'])
                        RaftServerMenuRow(
                          id: id,
                          name: id.toUpperCase(),
                          slug: id,
                          current: id == 'g',
                          onSelected: () {},
                        ),
                    ],
                    actions: const [],
                  ),
                  onSearch: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final tail = find.byKey(const ValueKey('topbar-workspace-g'));
      expect(tail, findsOneWidget);
      expect(find.byKey(const ValueKey('topbar-workspace-f')), findsNothing);
      final seam = RaftTokens.of(t.element(tail)).colors['line-seam'];
      final dividers = find
          .byWidgetPredicate((w) => w is ColoredBox && w.color == seam)
          .evaluate()
          .where(
            (e) => t.getSize(find.byWidget(e.widget)) == const Size(1, 16),
          );
      // WorkspaceStrip.tsx: h-4 w-px bg-line-seam and gap-1 on both sides.
      expect(dividers, hasLength(1));
      final divider = t.getRect(find.byWidget(dividers.single.widget));
      expect(divider.right + 4, t.getRect(tail).left);
      expect(divider.center.dy, t.getRect(tail).center.dy);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('out-of-range current stays outside the sortable head', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(856, 944);
    addTearDown(t.view.reset);
    final menu = RaftMenuController();
    addTearDown(menu.dispose);
    final moves = <List<int>>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Column(
            children: [
              RaftWorkspaceTopBar(
                workspace: RaftServerSwitcher(
                  controller: menu,
                  workspaceName: 'G',
                  label: 'Switch Server',
                  topBar: true,
                  rows: [
                    for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g'])
                      RaftServerMenuRow(
                        id: id,
                        name: id.toUpperCase(),
                        slug: id,
                        current: id == 'g',
                        onSelected: () {},
                      ),
                  ],
                  actions: const [],
                  onReorder: (from, to) => moves.add([from, to]),
                ),
                onSearch: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final lastHead = find.byKey(const ValueKey('topbar-workspace-c'));
    final current = find.byKey(const ValueKey('topbar-workspace-g'));
    expect(lastHead, findsOneWidget);
    expect(current, findsOneWidget);
    await t.tap(lastHead);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    expect(moves, isEmpty, reason: 'current tail is not a sortable target');
    await t.pump();
    final pointer = await t.startGesture(
      t.getCenter(lastHead),
      kind: PointerDeviceKind.mouse,
    );
    await pointer.moveTo(t.getCenter(current));
    await t.pump();
    await pointer.up();
    await t.pump();
    expect(moves, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  testWidgets(
    'strip activation uses pointer distance before horizontal restriction',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 800);
      addTearDown(t.view.reset);
      final menu = RaftMenuController();
      addTearDown(menu.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                RaftWorkspaceTopBar(
                  workspace: RaftServerSwitcher(
                    controller: menu,
                    workspaceName: 'A',
                    label: 'Switch Server',
                    topBar: true,
                    rows: [
                      for (final id in ['a', 'b', 'c'])
                        RaftServerMenuRow(
                          id: id,
                          name: id.toUpperCase(),
                          slug: id,
                          current: id == 'a',
                          onSelected: () {},
                        ),
                    ],
                    actions: const [],
                    onReorder: (_, _) {},
                  ),
                  onSearch: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final pointer = await t.startGesture(
        t.getCenter(find.byKey(const ValueKey('topbar-workspace-b'))),
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(const Offset(0, 7));
      await t.pump();
      expect(
        find.byWidgetPredicate((w) => w is Opacity && w.opacity == .3),
        findsOneWidget,
        reason: 'WorkspaceStripSortableAvatar uses opacity-30 after distance6',
      );
      await pointer.cancel();
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'workspace strip keyboard reorders and Escape cancels without switching',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 800);
      addTearDown(t.view.reset);
      final menu = RaftMenuController();
      addTearDown(menu.dispose);
      var picks = 0;
      final moves = <List<int>>[];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                RaftWorkspaceTopBar(
                  workspace: RaftServerSwitcher(
                    controller: menu,
                    workspaceName: 'First',
                    label: 'Switch Server',
                    topBar: true,
                    rows: [
                      for (final id in ['a', 'b', 'c'])
                        RaftServerMenuRow(
                          id: id,
                          name: id.toUpperCase(),
                          slug: id,
                          current: id == 'a',
                          onSelected: () => picks++,
                        ),
                    ],
                    actions: const [],
                    onReorder: (from, to) => moves.add([from, to]),
                  ),
                  onSearch: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final first = find.byKey(const ValueKey('topbar-workspace-a'));
      await t.tap(first);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      expect(moves, [
        [0, 1],
      ]);
      expect(picks, 0);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(moves, [
        [0, 1],
      ]);
      expect(picks, 0);
      await t.pump();
      final other = find.byKey(const ValueKey('topbar-workspace-b'));
      for (final dx in [7.0, 37.0]) {
        final mouse = await t.startGesture(
          t.getCenter(other),
          kind: PointerDeviceKind.mouse,
        );
        await mouse.moveBy(Offset(dx, 0));
        await t.pump();
        await mouse.up();
        await t.pump();
      }
      expect(moves, [
        [0, 1],
        [1, 2],
      ]);
      expect(picks, 0, reason: 'drag release must not switch workspaces');
      await t.tap(other);
      expect(picks, 1, reason: 'the following independent click is accepted');
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets(
      '$pack sidebar without title preserves the source content inset',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack)),
            home: Builder(
              builder: (context) {
                final recipe = RaftSidebarRecipe(
                  RaftTokens.of(context),
                  viewportWidth: 856,
                  viewportHeight: 944,
                  variant: RaftSidebarVariant.mountedProduct,
                );
                expect(
                  recipe.contentInset(headerInFlow: false).top,
                  pack == raftThemePackId ? 8 : 12,
                );
                expect(
                  recipe.contentInset(headerInFlow: true).top,
                  pack == raftThemePackId ? 4 : 12,
                );
                return const SizedBox();
              },
            ),
          ),
        );
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets('$pack chrome policy preserves legacy and native ownership', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(pack)),
          home: Builder(
            builder: (context) {
              final tokens = RaftTokens.of(context);
              expect(
                raftShowsWorkspaceTopBar(
                  tokens: tokens,
                  width: 856,
                  nativeWindowChrome: false,
                ),
                pack == raftThemePackId,
              );
              expect(
                raftShowsWorkspaceTopBar(
                  tokens: tokens,
                  width: 390,
                  nativeWindowChrome: false,
                ),
                false,
              );
              expect(
                raftShowsWorkspaceTopBar(
                  tokens: tokens,
                  width: 1280,
                  nativeWindowChrome: true,
                ),
                true,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
