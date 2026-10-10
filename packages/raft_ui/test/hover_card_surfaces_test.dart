import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget surfaceHost(Widget child, {RaftFamily family = RaftFamily.elegant}) =>
    MaterialApp(
      theme: raftTheme(family),
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
        280,
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
          footer: 'Cached snapshot only',
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
          // Inline in a wrapping row like Detected Runtimes.
          Wrap(
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
        'VERSION 2.1.0',
        'Max',
        'ada****@example.com',
        'OK',
        '5h',
        '42% used · resets in 3 hours',
        'Usage format unavailable',
        'Account-wide · updated 5 minutes ago',
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
  });
}
