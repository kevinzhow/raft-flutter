import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_typography_test.dart' show loadTaskFonts;

Widget surfaceHost(Widget child, {TargetPlatform? platform}) => MaterialApp(
  theme: raftTheme().copyWith(platform: platform),
  home: Scaffold(body: Center(child: child)),
);

Future<TestGesture> hoverAt(WidgetTester tester, Offset at) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(at);
  return mouse;
}

Future<void> finish(WidgetTester tester, TestGesture mouse) async {
  await mouse.removePointer();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('reaction reactors popover', () {
    Widget tile(List<Map<String, dynamic>> reactions, {Set<String>? mine}) =>
        surfaceHost(
          SizedBox(
            width: 600,
            child: RaftMessageTile(
              author: 'Ada',
              avatar: const SizedBox.square(dimension: 36),
              content: 'hello',
              timestamp: '10:00',
              reactions: reactions,
              reactedEmojis: mine ?? const {},
              reactionViewerId: 'me',
              onReaction: (_) {},
            ),
          ),
          platform: TargetPlatform.linux,
        );

    testWidgets('names the viewer first, five names, then +N more', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          [
            {
              'emoji': '👍',
              'count': 8,
              'reactorIds': ['a', 'me', 'b', 'c', 'd', 'e', 'f', 'g'],
              'reactorNames': ['Ada', 'Me', 'Bo', 'Cy', 'Di', 'Ed', 'Fa', 'Gu'],
            },
          ],
          mine: {'👍'},
        ),
      );
      final mouse = await hoverAt(
        tester,
        tester.getCenter(find.byKey(const ValueKey('reaction-👍'))),
      );
      // Opens at once (no delay), below the chip's left edge.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final popup = find.byKey(const ValueKey('reaction-reactors-popover'));
      expect(popup, findsOneWidget);
      for (final name in ['You', 'Ada', 'Bo', 'Cy', 'Di']) {
        expect(
          find.descendant(of: popup, matching: find.text(name)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: popup, matching: find.text('Me')),
        findsNothing,
      );
      expect(
        find.descendant(of: popup, matching: find.text('+3 more')),
        findsOneWidget,
      );
      final chip = tester.getRect(find.byKey(const ValueKey('reaction-👍')));
      final rect = tester.getRect(popup);
      expect(rect.top, moreOrLessEquals(chip.bottom + 4));
      expect(rect.left, moreOrLessEquals(chip.left));
      // Leaving closes it at once; a press closes it too.
      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(popup, findsNothing);
      await finish(tester, mouse);
    });

    testWidgets('canonical previewK actors; no names shows the emoji', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile([
          {
            'emoji': '🎉',
            'count': 2,
            'previewK': [
              {'id': 'x', 'displayName': 'Xi'},
            ],
          },
          {'emoji': '🔥', 'count': 1},
        ]),
      );
      final mouse = await hoverAt(
        tester,
        tester.getCenter(find.byKey(const ValueKey('reaction-🎉'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final popup = find.byKey(const ValueKey('reaction-reactors-popover'));
      expect(find.descendant(of: popup, matching: find.text('Xi')), findsOne);
      expect(
        find.descendant(of: popup, matching: find.text('+1 more')),
        findsOne,
      );
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('reaction-🔥'))),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.descendant(of: popup, matching: find.text('🔥')), findsOne);
      await finish(tester, mouse);
    });

    testWidgets('a row scrolled under a resting pointer opens nothing', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        surfaceHost(
          SizedBox(
            width: 600,
            height: 300,
            child: ListView(
              controller: scroll,
              children: [
                for (var i = 0; i < 30; i++)
                  RaftMessageTile(
                    key: ValueKey('row-$i'),
                    author: 'A$i',
                    avatar: const SizedBox.square(dimension: 36),
                    content: 'm$i',
                    timestamp: '10:00',
                    reactions: [
                      {
                        'emoji': '👍',
                        'count': 1,
                        'reactorIds': ['u$i'],
                        'reactorNames': ['User $i'],
                      },
                    ],
                    onReaction: (_) {},
                  ),
              ],
            ),
          ),
          platform: TargetPlatform.linux,
        ),
      );
      final chip = find.byKey(const ValueKey('reaction-👍')).first;
      final mouse = await hoverAt(tester, tester.getCenter(chip));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('User 0'), findsOneWidget);
      for (var step = 1; step <= 8; step++) {
        scroll.jumpTo(step * 37.0);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byKey(const ValueKey('reaction-reactors-popover')),
          findsNothing,
          reason: 'scroll step $step',
        );
      }
      await finish(tester, mouse);
    });
  });

  group('profile preview card', () {
    testWidgets('agent card: status, handle, facts, description, activity', (
      tester,
    ) async {
      // The v1.24 card is taller (337 with these rows): give it the room.
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(
        surfaceHost(
          RaftHoverCard(
            card: (_) => RaftProfilePreviewCard(
              avatar: const RaftAvatarSlot(
                name: 'Nova',
                slot: RaftAvatarSlotContext.mentionCard,
              ),
              name: 'Nova',
              subtitle: '@nova',
              status: const RaftProfilePreviewStatus(
                activity: RaftActivityTone.working,
                text: 'Working',
              ),
              facts: const [
                RaftProfilePreviewFact('Computer', 'build-box'),
                RaftProfilePreviewFact('Runtime', 'Codex CLI'),
                RaftProfilePreviewFact('Model', 'GPT-6'),
                RaftProfilePreviewFact('Reasoning', 'high', capitalize: true),
              ],
              description: 'Ships the release',
              activity: const [
                RaftProfilePreviewActivity(
                  time: '10:00:01',
                  activity: RaftActivityTone.thinking,
                  text: 'Thinking',
                ),
              ],
              onOpenActivity: () => opened++,
            ),
            child: const SizedBox(width: 36, height: 36, child: Text('N')),
          ),
        ),
      );
      final mouse = await hoverAt(tester, tester.getCenter(find.text('N')));
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pump(const Duration(milliseconds: 300));
      for (final text in [
        'Nova',
        '@nova',
        'Working',
        'build-box',
        'Codex CLI',
        'GPT-6',
        'High',
        'Ships the release',
        'Recent activity',
        '10:00:01',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('raft-hover-card-surface')))
            .width,
        300,
      );
      // The heading link dismisses the card first, then opens activity.
      await mouse.moveTo(tester.getCenter(find.text('Recent activity')));
      await tester.pump();
      await tester.tap(
        find.text('Recent activity'),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(opened, 1);
      expect(find.text('Ships the release'), findsNothing);
      await finish(tester, mouse);
    });

    testWidgets('member and unavailable cards have no facts grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        surfaceHost(
          const RaftProfilePreviewCard(
            avatar: SizedBox.square(dimension: 48),
            name: '@ghost',
            subtitle: 'Profile unavailable',
          ),
        ),
      );
      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-preview-facts')), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-preview-activity')),
        findsNothing,
      );
    });
  });

  group('runtime usage card', () {
    RaftRuntimeUsageData data({String? state = 'fresh'}) =>
        RaftRuntimeUsageData(
          provider: 'Claude',
          version: '2.1.0',
          state: state,
          updated: '5 minutes ago',
          statusText: 'Cached snapshot only',
          accounts: const [
            RaftRuntimeUsageAccount(
              health: 'ok',
              plan: 'Max',
              identity: 'ada****@example.com',
              windows: [
                RaftRuntimeUsageWindow(
                  label: '5h',
                  status: 'ok',
                  percent: 42,
                  reset: 'in 3 hours',
                ),
                RaftRuntimeUsageWindow(
                  label: 'Weekly',
                  status: 'parse_unavailable',
                ),
              ],
            ),
          ],
        );

    Widget chip(RaftRuntimeUsageData value, {VoidCallback? onOpen}) =>
        surfaceHost(
          // A pointer window: the hover card is for a mouse, at any width
          // (a touch screen opens the sheet instead).
          RaftInteractionScope(
            interaction: RaftInteraction.pointerMode,
            // Inline in a wrapping row like Detected Runtimes.
            child: Wrap(
              children: [
                RaftRuntimeUsageChip(
                  label: 'Claude Code',
                  data: value,
                  onOpen: onOpen ?? () {},
                  onRefresh: () {},
                  chip: RaftRuntimeChip(
                    label: 'Claude Code',
                    detected: true,
                    trailing: value.known
                        ? RaftRuntimeUsageStatus(attention: value.attention)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );

    testWidgets('hover opens the usage card after 200ms with its content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opens = 0;
      await tester.pumpWidget(chip(data(), onOpen: () => opens++));
      // A window whose format is unavailable needs attention (isAttention).
      expect(
        find.byKey(const ValueKey('runtime-usage-health-true')),
        findsOneWidget,
      );
      final mouse = await hoverAt(
        tester,
        tester.getCenter(find.text('Claude Code')),
      );
      await tester.pump(const Duration(milliseconds: 190));
      expect(find.text('Claude usage'), findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opens, 1);
      for (final text in [
        'Claude usage',
        '2.1.0',
        'Max',
        'ada****@example.com',
        'ok',
        '5h',
        '42% used · resets in 3 hours',
        'Usage unavailable',
        'Updated 5 minutes ago',
        'Cached snapshot only',
        'Refresh',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      final card = tester.getRect(
        find.byKey(const ValueKey('runtime-usage-card')),
      );
      expect(card.width, 390);
      expect(
        card.top,
        moreOrLessEquals(
          tester.getRect(find.byType(RaftRuntimeChip)).bottom + 8,
        ),
      );
      // Grace: 160ms after leaving.
      await mouse.moveTo(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Claude usage'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Claude usage'), findsNothing);
      await finish(tester, mouse);
    });

    testWidgets('a click pins it; Escape closes; focus opens it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(chip(data(state: 'stale')));
      expect(
        find.byKey(const ValueKey('runtime-usage-health-true')),
        findsOneWidget,
      );
      final mouse = await hoverAt(
        tester,
        tester.getCenter(find.text('Claude Code')),
      );
      await mouse.down(tester.getCenter(find.text('Claude Code')));
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Stale snapshot · every value below is last known'),
        findsOneWidget,
      );
      await mouse.moveTo(const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Claude usage'), findsOneWidget, reason: 'pinned');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Claude usage'), findsNothing);
      await mouse.removePointer();

      // Keyboard: the chip is reachable with Tab and opens on focus.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(chip(data(state: 'stale')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Claude usage'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('no snapshot yet; no health dot', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(chip(data(state: 'missing')));
      expect(find.byType(RaftRuntimeUsageStatus), findsNothing);
      final mouse = await hoverAt(
        tester,
        tester.getCenter(find.text('Claude Code')),
      );
      await tester.pump(const Duration(milliseconds: 210));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No snapshot yet'), findsOneWidget);
      await finish(tester, mouse);
    });

    RaftRuntimeUsageData fiveWindowData() => const RaftRuntimeUsageData(
      provider: 'Antigravity',
      runtimeName: 'Antigravity CLI',
      version: '1.5.10',
      state: 'fresh',
      updated: '10 minutes ago',
      accounts: [
        RaftRuntimeUsageAccount(
          health: 'ok',
          windows: [
            RaftRuntimeUsageWindow(
              label: 'Gemini Models · Weekly Limit Remaining',
              status: 'ok',
              percent: 2,
              reset: 'in 7 days',
            ),
            RaftRuntimeUsageWindow(
              label: 'Gemini Models · Five Hour Limit Remaining',
              status: 'ok',
              percent: 4,
              reset: 'in 5 hours',
            ),
            RaftRuntimeUsageWindow(
              label: 'Claude and GPT models · Weekly Limit Remaining',
              status: 'ok',
              percent: 0,
              reset: 'in 7 days',
            ),
            RaftRuntimeUsageWindow(
              label: 'Claude and GPT models · Five Hour Limit Remaining',
              status: 'ok',
              percent: 0,
              reset: 'in 5 hours',
            ),
            RaftRuntimeUsageWindow(
              label: 'Gemini 4 Argon · Gemini 4 Argon Weekly Limit',
              status: 'ok',
              percent: 0,
              reset: 'in 7 days',
            ),
          ],
        ),
      ],
    );

    Widget positionedChip(
      RaftRuntimeUsageData value, {
      required double top,
      required VoidCallback onRefresh,
    }) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: RaftInteractionScope(
          interaction: RaftInteraction.pointerMode,
          child: Stack(
            children: [
              Positioned(
                left: 120,
                top: top,
                child: RaftRuntimeUsageChip(
                  label: 'Antigravity CLI',
                  data: value,
                  onOpen: () {},
                  onRefresh: onRefresh,
                  chip: RaftRuntimeChip(
                    label: 'Antigravity CLI',
                    detected: true,
                    trailing: RaftRuntimeUsageStatus(
                      attention: value.attention,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    testWidgets(
      'five-window usage card near vertical midpoint keeps bottom actions unclipped and clickable',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadTaskFonts(tester);
        var refreshes = 0;
        await tester.pumpWidget(
          positionedChip(
            fiveWindowData(),
            top: 468,
            onRefresh: () => refreshes++,
          ),
        );
        await tester.tap(find.text('Antigravity CLI'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-card')),
        );
        final actions = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-actions')),
        );
        final refresh = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-refresh')),
        );
        expect(card.top, greaterThanOrEqualTo(8));
        expect(card.bottom, lessThanOrEqualTo(792));
        expect(actions.bottom, lessThanOrEqualTo(card.bottom));
        expect(refresh.top, greaterThanOrEqualTo(card.top));
        expect(refresh.bottom, lessThanOrEqualTo(card.bottom));
        await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
        await tester.pump();
        expect(refreshes, 1);
      },
    );

    testWidgets(
      'compact desktop viewport keeps bottom actions pinned and clickable while usage body scrolls',
      (tester) async {
        tester.view.physicalSize = const Size(900, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadTaskFonts(tester);
        var refreshes = 0;
        await tester.pumpWidget(
          positionedChip(
            fiveWindowData(),
            top: 200,
            onRefresh: () => refreshes++,
          ),
        );
        await tester.tap(find.text('Antigravity CLI'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-card')),
        );
        final refresh = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-refresh')),
        );
        expect(card.top, greaterThanOrEqualTo(8));
        expect(card.bottom, lessThanOrEqualTo(412));
        expect(refresh.top, greaterThanOrEqualTo(card.top));
        expect(refresh.bottom, lessThanOrEqualTo(card.bottom));
        await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
        await tester.pump();
        expect(refreshes, 1);

        await tester.drag(
          find.text('Gemini Models · Weekly Limit Remaining'),
          const Offset(0, -240),
        );
        await tester.pumpAndSettle();
        final fifthWindow = tester.getRect(
          find.text('Gemini 4 Argon · Gemini 4 Argon Weekly Limit'),
        );
        final actionsAfterScroll = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-actions')),
        );
        expect(fifthWindow.bottom, lessThanOrEqualTo(actionsAfterScroll.top));
        expect(actionsAfterScroll.bottom, lessThanOrEqualTo(card.bottom));
      },
    );

    testWidgets(
      'compact landscape mobile sheet keeps bottom actions pinned and clickable',
      (tester) async {
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadTaskFonts(tester);
        var sheetRefreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: TargetPlatform.android),
            home: Scaffold(
              body: RaftRuntimeUsageSheet(
                data: fiveWindowData(),
                onRefresh: () => sheetRefreshes++,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-sheet')),
        );
        final sheetRefresh = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-refresh')),
        );
        expect(sheetRefresh.top, greaterThanOrEqualTo(sheet.top));
        expect(sheetRefresh.bottom, lessThanOrEqualTo(sheet.bottom));
        await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
        await tester.pump();
        expect(sheetRefreshes, 1);
      },
    );

    testWidgets(
      'narrow desktop window and short viewport with tall footer do not clip or overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await loadTaskFonts(tester);
        var refreshes = 0;
        await tester.pumpWidget(
          positionedChip(
            fiveWindowData(),
            top: 468,
            onRefresh: () => refreshes++,
          ),
        );
        await tester.tap(find.text('Antigravity CLI'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final card = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-card')),
        );
        final refresh = tester.getRect(
          find.byKey(const ValueKey('runtime-usage-refresh')),
        );
        expect(refresh.top, greaterThanOrEqualTo(card.top));
        expect(refresh.bottom, lessThanOrEqualTo(card.bottom));
        await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
        await tester.pump();
        expect(refreshes, 1);

        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = const Size(420, 180);
        var shortRefreshes = 0;
        final tallFooterData = RaftRuntimeUsageData(
          provider: 'Antigravity',
          runtimeName: 'Antigravity CLI',
          version: '1.5.10',
          state: 'fresh',
          updated: '10 minutes ago',
          statusText: 'Refresh requested just now',
          accounts: fiveWindowData().accounts,
          claudeLimitReset: RaftRuntimeClaudeLimitReset(
            onView: () {},
            onUseFiveHour: () {},
            ownerOnly: true,
          ),
          auth: const RaftRuntimeAuthData(
            runtime: 'antigravity',
            status: 'logged_in',
            action: RaftRuntimeAuthActionKind.unavailable,
            unavailableText: 'Install a newer CLI to sign in from Raft.',
            installCommand: 'curl -fsSL https://example.invalid/install | sh',
          ),
        );
        await tester.pumpWidget(
          positionedChip(
            tallFooterData,
            top: 90,
            onRefresh: () => shortRefreshes++,
          ),
        );
        await tester.tap(find.text('Antigravity CLI'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('runtime-usage-card')),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('runtime-usage-refresh')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('runtime-usage-refresh')));
        await tester.pump();
        expect(shortRefreshes, 1);
      },
    );
  });

  group('hover-revealed code copy', () {
    double copyOpacity(WidgetTester tester) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byTooltip('Copy Code'),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    for (final density in RaftDensity.values) {
      testWidgets('index.css .r-code-copy reveal ($density)', (tester) async {
        await tester.pumpWidget(
          surfaceHost(
            RaftDensityScope(
              density: density,
              child: const SizedBox(
                width: 500,
                child: RaftCodeBlock(code: 'echo hi', language: 'bash'),
              ),
            ),
          ),
        );
        final touch = density == RaftDensity.touch;
        // hover:none shows it at .55; pointer layouts hide it at rest.
        expect(copyOpacity(tester), touch ? .55 : 0);
        if (touch) return;
        final mouse = await hoverAt(
          tester,
          tester.getTopLeft(find.byType(RaftCodeBlock)) + const Offset(20, 20),
        );
        await tester.pump();
        expect(copyOpacity(tester), .55);
        await mouse.moveTo(tester.getCenter(find.byTooltip('Copy Code')));
        await tester.pump();
        expect(copyOpacity(tester), 1);
        await finish(tester, mouse);
      });
    }

    testWidgets('keyboard reaches the hidden copy control', (tester) async {
      await tester.pumpWidget(
        surfaceHost(
          const RaftDensityScope(
            density: RaftDensity.desktop,
            child: SizedBox(
              width: 500,
              child: RaftCodeBlock(code: 'echo hi', language: 'bash'),
            ),
          ),
        ),
      );
      expect(copyOpacity(tester), 0);
      for (var i = 0; i < 4 && copyOpacity(tester) == 0; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(copyOpacity(tester), .55);
    });
  });

  testWidgets('attachment names show a tooltip only when cut off', (
    tester,
  ) async {
    const long = 'quarterly-visual-parity-baseline-report-final-v2.pdf';
    await tester.pumpWidget(
      surfaceHost(
        RaftTooltipProvider(
          delay: const Duration(milliseconds: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RaftAttachmentCard(filename: 'a.pdf', onOpen: () {}),
              const SizedBox(height: 16),
              RaftAttachmentCard(filename: long, onOpen: () {}),
            ],
          ),
        ),
      ),
    );
    final mouse = await hoverAt(tester, tester.getCenter(find.text('a.pdf')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('raft-tooltip-surface')), findsNothing);
    await mouse.moveTo(tester.getCenter(find.text(long)));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('raft-tooltip-surface')),
        matching: find.text(long),
      ),
      findsOneWidget,
    );
    await finish(tester, mouse);
  });

  for (final density in RaftDensity.values) {
    testWidgets('image actions stay absent on hover / focus ($density)', (
      tester,
    ) async {
      var opened = 0;
      TestGesture? mouse;
      void expectNoActions() {
        expect(find.byKey(const ValueKey('image-actions')), findsNothing);
        expect(find.byTooltip('Share shot.png'), findsNothing);
        expect(find.byTooltip('Download shot.png'), findsNothing);
      }

      try {
        await tester.pumpWidget(
          surfaceHost(
            RaftDensityScope(
              density: density,
              child: RaftAttachmentCard(
                filename: 'shot.png',
                mimeType: 'image/png',
                imageWidth: 320,
                imageHeight: 200,
                preview: const ColoredBox(color: Color(0xff336699)),
                onOpen: () => opened++,
              ),
            ),
          ),
        );
        expectNoActions();
        mouse = await hoverAt(
          tester,
          tester.getCenter(find.byType(RaftAttachmentCard)),
        );
        await tester.pump();
        expectNoActions();
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expectNoActions();
        // Keyboard focus still opens the image, without extra action targets.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expectNoActions();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened, 1);
        expectNoActions();
      } finally {
        await mouse?.removePointer();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }
    });
  }
}
