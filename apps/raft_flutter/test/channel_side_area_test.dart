// The side area (WP-SIDE): Tasks and Files as cards beside the chat, floating
// over it or covering it. Geometry, paint (seam, surface), resize and split,
// the phone's cover with its switch and Back, and the chat staying mounted.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_card.dart'
    show ChannelSideMode;
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

int probeBuilds = 0, probeInits = 0, probeTaps = 0;

/// Stands for the channel column: a header, the messages and the composer.
class _Chat extends StatefulWidget {
  const _Chat();
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  @override
  void initState() {
    super.initState();
    probeInits++;
  }

  @override
  Widget build(BuildContext context) {
    probeBuilds++;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(key: Key('chat-header'), height: 56),
        Expanded(
          child: GestureDetector(
            key: const Key('chat-messages'),
            behavior: HitTestBehavior.opaque,
            onTap: () => probeTaps++,
          ),
        ),
        RaftComposer(
          key: const Key('chat-composer'),
          onSend: (_) async => true,
        ),
      ],
    );
  }
}

class AreaRig {
  AreaRig(this.w, this.transport, this.store);
  final WorkspaceController w;
  final MessageAdapter transport;
  final ChannelSideStore store;

  List<RequestOptions> get saves => [
    for (final c in transport.calls)
      if (c.method == 'PATCH' && c.path == '/servers/s1/sidebar-order') c,
  ];
}

Future<AreaRig> pumpArea(
  WidgetTester t, {
  required Size size,
  bool dark = false,
  TargetPlatform platform = TargetPlatform.linux,
  bool taskV2 = true,
  Widget? chat,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  probeBuilds = probeInits = probeTaps = 0;
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  addTearDown(DevicePreferences.reset);
  final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  transport.routes['PATCH /servers/s1/sidebar-order'] = (_) => {};
  w.navigation.bind(
    'side-area',
    RaftLocation.at(serverSlug: 's1', route: RaftRoute.channel, entityId: 'c1'),
  );
  // The flags ask the server once as they are made: let that finish outside
  // the fake clock.
  await t.runAsync(() async {
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  if (taskV2) TaskV2ConversationsFlag.of(w).markEnabled();
  final store = ChannelSideStore.of(w);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: ChannelSideArea(
          controller: w,
          bodyOf: (context, section) => SizedBox.expand(
            key: Key('body-${section.name}'),
            child: const ColoredBox(color: Color(0xFFEEEEEE)),
          ),
          child: chat ?? const _Chat(),
        ),
      ),
    ),
  );
  await t.pump();
  return AreaRig(w, transport, store);
}

Border border(BoxDecoration d) => d.border! as Border;

/// Lets a save (a request through the fake clock) go out and answer.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

Rect rect(WidgetTester t, String key) => t.getRect(find.byKey(Key(key)));

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const []);
  const desktop = Size(1200, 800);

  group('flag off', () {
    testWidgets('nothing stands beside the chat, however the cards are set', (
      t,
    ) async {
      final rig = await pumpArea(t, size: desktop, taskV2: false);
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      expect(find.byKey(const Key('channel-side-column-1')), findsNothing);
      expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);
      expect(rect(t, 'chat-header').width, 1200);
    });
  });

  group('desktop, beside the chat', () {
    testWidgets(
      'the column stands right of the whole channel column; the chat keeps 360',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        final column = rect(t, 'channel-side-column-1');
        expect(column.right, 1200);
        expect(column.width, 360);
        expect(column.top, 0);
        expect(column.bottom, 800);
        // The header is the chat's: it ends where the column begins.
        expect(rect(t, 'chat-header').right, column.left);
        expect(rect(t, 'chat-header').width, greaterThanOrEqualTo(360));
        // Its own head is as high as the channel header and level with it.
        final head = rect(t, 'channel-side-card-tasks-header');
        expect(head.height, 44);
        expect(head.top, rect(t, 'chat-header').top);
        expect(
          find.byKey(const Key('channel-side-card-tasks-close')),
          findsOne,
        );
        expect(find.byKey(const Key('body-tasks')), findsOne);
      },
    );

    testWidgets(
      'a medium window covers with the pane opened last, nothing clipped',
      (t) async {
        // 360 for the chat and the two panes at their own minimums (280 and
        // 480) do not fit in 800. Clipping both to 160 was the Web desktop
        // rule; a medium window covers instead.
        final rig = await pumpArea(t, size: const Size(800, 800));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        WebPreviewStore.of(rig.w).open(
          const WebPreviewPage(
            url: 'https://example.com/a',
            conversationId: 'c1',
          ),
        );
        await t.pump();
        expect(rect(t, 'channel-side-overlay').width, 800);
        expect(find.byKey(const Key('channel-side-column-1')), findsNothing);
        // The web page opened last, so it is the one on top.
        expect(find.byKey(const Key('body-artifact')), findsOne);
        expect(find.byKey(const Key('body-tasks')), findsNothing);
        // The chat keeps its whole slot instead of being clipped into it.
        expect(rect(t, 'chat-header').width, 800);
      },
    );

    testWidgets(
      'both cards stack 60/40 in one column with a seam; collapse only where stacked',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        // Alone: no fold chevron.
        expect(
          find.byKey(const Key('channel-side-card-tasks-collapse')),
          findsNothing,
        );
        rig.store.setCardOpen(ChannelSideCard.files, true);
        await t.pump();
        final tasks = rect(t, 'channel-side-card-tasks');
        final files = rect(t, 'channel-side-card-files');
        expect(tasks.height, closeTo(799 * .6, 1));
        expect(files.height, closeTo(799 * .4, 1));
        expect(files.top, closeTo(tasks.bottom + 1, .5));
        expect(
          find.byKey(const Key('channel-side-card-tasks-collapse')),
          findsOne,
        );
        expect(
          find.byKey(const Key('channel-side-card-files-collapse')),
          findsOne,
        );
        // Folding Tasks leaves its head; Files takes the rest; the body stays mounted.
        await t.tap(find.byKey(const Key('channel-side-card-tasks-collapse')));
        await t.pump();
        expect(rect(t, 'channel-side-card-tasks').height, 44);
        expect(rect(t, 'channel-side-card-files').height, closeTo(800 - 44, 1));
        expect(rig.store.collapsed(ChannelSideCard.tasks), isTrue);
        expect(
          find.byKey(const Key('body-tasks'), skipOffstage: false),
          findsOne,
        );
        expect(find.byKey(const Key('body-tasks')), findsNothing);
        expect(find.bySemanticsLabel('Expand Tasks'), findsWidgets);
        Border seam(String section) {
          final frame = find.descendant(
            of: find.byKey(Key('channel-side-card-$section-header')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container && widget.decoration is BoxDecoration,
            ),
          );
          return (t.widget<Container>(frame.first).decoration! as BoxDecoration)
                  .border!
              as Border;
        }

        expect(seam('tasks').bottom.width, 1);
        await t.tap(find.byKey(const Key('channel-side-card-tasks-collapse')));
        await t.pump();
        await t.tap(find.byKey(const Key('channel-side-card-files-collapse')));
        await t.pump();
        expect(seam('files').bottom, BorderSide.none);
        await t.tap(find.byKey(const Key('channel-side-card-tasks-collapse')));
        await t.pump();
        expect(seam('files').bottom.width, 1);
      },
    );

    testWidgets(
      'a column too short for its sections shows one at a time under a switch',
      (t) async {
        final rig = await pumpArea(t, size: const Size(1200, 300));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        rig.store.setCardOpen(ChannelSideCard.files, true);
        await t.pump();
        expect(find.byKey(const Key('channel-side-switch')), findsOne);
        // Files was opened last: it shows.
        expect(find.byKey(const Key('body-files')), findsOne);
        expect(find.byKey(const Key('body-tasks')), findsNothing);
        await t.tap(find.byKey(const Key('channel-side-switch-tasks')));
        await t.pump();
        expect(find.byKey(const Key('body-tasks')), findsOne);
        expect(find.byKey(const Key('body-files')), findsNothing);
        expect(
          find.byKey(const Key('body-files'), skipOffstage: false),
          findsOne,
        );
      },
    );

    testWidgets('the width handle drags live and saves once, on release', (
      t,
    ) async {
      final rig = await pumpArea(t, size: desktop);
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      final handle = find.byKey(const Key('channel-side-column-resize-1'));
      expect(t.getRect(handle).width, 12);
      expect(t.getRect(handle).left, 840);
      final drag = await t.startGesture(t.getCenter(handle));
      await drag.moveBy(const Offset(-60, 0));
      await drag.moveBy(const Offset(-40, 0));
      await t.pump();
      expect(rect(t, 'channel-side-column-1').width, 460);
      expect(rect(t, 'chat-header').width, 740);
      expect(rig.saves, isEmpty);
      await drag.up();
      await settle(t);
      expect(rig.store.layout.columns[1].width, 460);
      expect(rig.saves, hasLength(1));
      expect(
        (rig.saves.single.data
            as Map)['channelSideLayout']['columns'][1]['width'],
        460,
      );
    });

    testWidgets('a seam keeps moving after the adjacent column clips', (
      t,
    ) async {
      final rig = await pumpArea(t, size: desktop);
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      WebPreviewStore.of(rig.w).open(
        const WebPreviewPage(
          url: 'https://example.invalid',
          conversationId: 'c1',
        ),
      );
      await t.pump();
      final handle = find.byKey(const Key('channel-side-column-resize-1'));
      final drag = await t.startGesture(t.getCenter(handle));
      await drag.moveBy(const Offset(60, 0));
      await drag.moveBy(const Offset(190, 0));
      await t.pump();
      expect(rect(t, 'channel-side-column-1').width, 160);
      expect(rect(t, 'channel-side-column-2').width, 430);
      expect(rect(t, 'chat-header').width, 610);
      await drag.up();
      await settle(t);
      expect(rig.saves, hasLength(1));
      expect(rig.store.layout.columns[2].width, 430);
    });

    testWidgets(
      'a desktop seam clips chat to 160 and preserves its content floor',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        final drag = await t.startGesture(
          t.getCenter(find.byKey(const Key('channel-side-column-resize-1'))),
        );
        await drag.moveBy(const Offset(-900, 0));
        await drag.up();
        await settle(t);
        expect(rect(t, 'channel-side-conversation').width, 160);
        expect(rect(t, 'chat-header').width, 360);
      },
    );

    testWidgets('the width handle has a keyboard way and a name', (t) async {
      final rig = await pumpArea(t, size: desktop);
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      final handle = find.byKey(const Key('channel-side-column-resize-1'));
      expect(t.getSemantics(handle).label, 'Resize Tasks');
      Focus.of(
        t.element(
          find.descendant(of: handle, matching: find.byType(RaftHoverRegion)),
        ),
      ).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(t);
      expect(rect(t, 'channel-side-column-1').width, 376);
      expect(rig.saves, hasLength(1));
    });

    testWidgets(
      'the seam between two sections drags their split and saves on release',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        rig.store.setCardOpen(ChannelSideCard.files, true);
        await t.pump();
        final seam = find.byKey(const Key('channel-side-split-0'));
        expect(t.getSemantics(seam).label, 'Resize Tasks and files');
        final before = rect(t, 'channel-side-card-tasks').height;
        final drag = await t.startGesture(t.getCenter(seam));
        await drag.moveBy(const Offset(0, -100));
        await t.pump();
        expect(
          rect(t, 'channel-side-card-tasks').height,
          closeTo(before - 100, 1),
        );
        expect(
          rig.store.splitShares([
            ChannelSideSection.tasks,
            ChannelSideSection.files,
          ]),
          [.6, .4],
        );
        await drag.up();
        await settle(t);
        final shares = rig.store.splitShares([
          ChannelSideSection.tasks,
          ChannelSideSection.files,
        ]);
        expect(shares[0], closeTo((before - 100) / 799, .005));
        // Dragged to the end, each stays at least 160px.
        final again = await t.startGesture(t.getCenter(seam));
        await again.moveBy(const Offset(0, -900));
        await again.up();
        await t.pump();
        expect(rect(t, 'channel-side-card-tasks').height, closeTo(160, 1));
      },
    );

    testWidgets('the cards follow the person to another channel', (t) async {
      final rig = await pumpArea(t, size: desktop);
      rig.store.setCardOpen(ChannelSideCard.files, true);
      await t.pump();
      rig.w.channel = RaftChannel({'id': 'c2', 'name': 'two', 'joined': true});
      rig.w.channels = [rig.w.channel!];
      rig.w.notifyListeners();
      await t.pump();
      expect(find.byKey(const Key('channel-side-card-files')), findsOne);
    });

    testWidgets(
      'an old ?chatTab=files link opens that card; closing it clears the query',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        rig.w.navigation.navigate(
          rig.w.location.withQuery({'chatTab': 'files'}),
          kind: RaftNavigationKind.replace,
        );
        rig.w.notifyListeners();
        await t.pump();
        expect(find.byKey(const Key('channel-side-card-files')), findsOne);
        await t.tap(find.byKey(const Key('channel-side-card-files-close')));
        await t.pump();
        expect(rig.w.location.chatTab, isNull);
        expect(find.byKey(const Key('channel-side-card-files')), findsNothing);
      },
    );

    testWidgets('Escape does not close a card', (t) async {
      final rig = await pumpArea(t, size: desktop);
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(rig.store.cardOpen(ChannelSideCard.tasks), isTrue);
    });
  });

  group('the chat stays mounted and unbuilt', () {
    testWidgets(
      'opening, closing, resizing and changing mode never remount or rebuild it',
      (t) async {
        final rig = await pumpArea(t, size: desktop);
        expect((probeInits, probeBuilds), (1, 1));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        rig.store.setCardOpen(ChannelSideCard.files, true);
        await t.pump();
        rig.store.resizeColumn(1, 420, false);
        await t.pump();
        rig.store.setCollapsed(ChannelSideCard.files, true);
        await t.pump();
        // A compact viewport covers the conversation at either width.
        t.view.physicalSize = const Size(600, 800);
        await t.pump();
        expect(find.byKey(const Key('channel-side-overlay')), findsOne);
        t.view.physicalSize = const Size(390, 844);
        await t.pump();
        expect(find.byKey(const Key('channel-side-overlay')), findsOne);
        rig.store.setCardOpen(ChannelSideCard.tasks, false);
        rig.store.setCardOpen(ChannelSideCard.files, false);
        await t.pump();
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
        expect((probeInits, probeBuilds), (1, 1));
      },
    );
  });

  group('compact: covering', () {
    testWidgets(
      'a phone: one card covers the whole conversation column, no X, no Back of its own',
      (t) async {
        final rig = await pumpArea(t, size: const Size(390, 844));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        // A phone's channel header stands above this area (workspace_view
        // mounts `mobilePageHeader` outside RaftAdaptiveWorkspace), and its
        // Back is what closes the card, so the cover takes the whole area.
        final cover = rect(t, 'channel-side-overlay');
        expect(cover, const Rect.fromLTRB(0, 0, 390, 844));
        expect(
          find.byKey(const Key('channel-side-card-tasks-close')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('channel-side-card-tasks-back')),
          findsNothing,
        );
        expect(find.byKey(const Key('channel-side-switch')), findsNothing);
        // The chat and the composer are inert under it.
        await t.tap(
          find.byKey(const Key('chat-messages')),
          warnIfMissed: false,
        );
        expect(probeTaps, 0);
        expect(
          find.descendant(
            of: find.byKey(const Key('chat-composer')),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'focus moves into the card under a cover and goes back once it is gone',
      (t) async {
        final rig = await pumpArea(t, size: const Size(390, 844));
        await t.tap(find.byType(TextField));
        await t.pump();
        final composerFocus = FocusManager.instance.primaryFocus!;
        expect(
          composerFocus.context!.findAncestorWidgetOfExactType<RaftComposer>(),
          isNotNull,
        );
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        await t.pump();
        final inCard = FocusManager.instance.primaryFocus!;
        expect(inCard, isNot(same(composerFocus)));
        expect(
          find.descendant(
            of: find.byKey(const Key('channel-side-overlay')),
            matching: find.byElementPredicate((e) => e == inCard.context),
          ),
          findsOne,
        );
        rig.store.setCardOpen(ChannelSideCard.tasks, false);
        await t.pump();
        await t.pump();
        expect(FocusManager.instance.primaryFocus, same(composerFocus));
      },
    );

    testWidgets(
      'both open: a Tasks | Files switch on top, one card at a time; Back closes the cards before the channel',
      (t) async {
        final rig = await pumpArea(t, size: const Size(390, 844));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        rig.store.setCardOpen(ChannelSideCard.files, true);
        await t.pump();
        expect(find.byKey(const Key('channel-side-switch')), findsOne);
        expect(
          t.getRect(find.byKey(const Key('channel-side-switch'))).height,
          56,
        );
        expect(find.byKey(const Key('body-files')), findsOne);
        await t.tap(find.byKey(const Key('channel-side-switch-tasks')));
        await t.pump();
        expect(find.byKey(const Key('body-tasks')), findsOne);
        expect(find.byKey(const Key('body-files')), findsNothing);
        // The header's Back (channelBackClosingSide): the cards first.
        var channelBack = 0;
        final back = channelBackClosingSide(rig.w, () => channelBack++)!;
        back();
        await t.pump();
        expect(rig.store.cardOpen(ChannelSideCard.tasks), isFalse);
        expect(rig.store.cardOpen(ChannelSideCard.files), isFalse);
        expect(channelBack, 0);
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
        back();
        expect(channelBack, 1);
      },
    );

    testWidgets('a wide compact viewport covers the whole panel', (t) async {
      final rig = await pumpArea(t, size: const Size(600, 800));
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      expect(
        rect(t, 'channel-side-overlay'),
        const Rect.fromLTRB(0, 0, 600, 800),
      );
      await t.tapAt(const Offset(100, 300));
      expect(probeTaps, 0);
    });
  });

  group('paint', () {
    for (final dark in [false, true]) {
      testWidgets(
        '${dark ? 'dark' : 'light'}: a 1px line-seam on the left edge, the layer-canvas surface',
        (t) async {
          final rig = await pumpArea(t, size: desktop, dark: dark);
          rig.store.setCardOpen(ChannelSideCard.tasks, true);
          await t.pump();
          final tokens = RaftTokens.of(
            t.element(find.byKey(const Key('chat-header'))),
          );
          final frame = find.descendant(
            of: find.byKey(const Key('channel-side-column-1')),
            matching: find.byType(RaftSidePanelFrame),
          );
          final container = t.widget<Container>(
            find.descendant(of: frame, matching: find.byType(Container)).first,
          );
          final decoration = container.decoration! as BoxDecoration;
          final seam = border(container.foregroundDecoration! as BoxDecoration);
          expect(decoration.color, tokens.colors['layer-canvas']);
          expect(seam.left.width, 1);
          expect(seam.left.color, tokens.colors['line-seam']);
          expect(seam.right, BorderSide.none);
          expect(seam.top, BorderSide.none);
          expect(decoration.borderRadius, BorderRadius.zero);
          expect(decoration.boxShadow, isNull);
          // The seam is the column's left edge: the column starts where the chat ends.
          expect(rect(t, 'channel-side-column-1').left, 840);
          final card = t.widget<ColoredBox>(
            find.byKey(const Key('channel-side-card-tasks')),
          );
          expect(card.color, tokens.colors['layer-canvas']);
          // Its head has the card surface and a seam under it.
          final head = t
              .widgetList<Container>(
                find.descendant(
                  of: find.byKey(const Key('channel-side-card-tasks-header')),
                  matching: find.byType(Container),
                ),
              )
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .where((d) => d.color == tokens.colors['layer-canvas']);
          expect(head, isNotEmpty);
          expect(
            head.any((d) => (d.border as Border?)?.bottom.width == 1),
            isTrue,
          );
          // Between two stacked sections: a 1px seam.
          rig.store.setCardOpen(ChannelSideCard.files, true);
          await t.pump();
          final seams = find.descendant(
            of: find.byKey(const Key('channel-side-column-1')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is ColoredBox &&
                  w.color == tokens.colors['line-seam'] &&
                  t.getSize(find.byWidget(w)).height == 1,
            ),
          );
          expect(seams, findsWidgets);
        },
      );
    }
  });

  group('interaction at the folding sizes', () {
    testWidgets(
      '856x944 Android: the card covers, its head has Back, nothing to drag',
      (t) async {
        final rig = await pumpArea(
          t,
          size: const Size(856, 944),
          platform: TargetPlatform.android,
        );
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        expect(rect(t, 'channel-side-overlay').width, 856);
        // The column is the cover, not a dock beside the chat.
        expect(
          find.descendant(
            of: find.byKey(const Key('channel-side-overlay')),
            matching: find.byKey(const Key('channel-side-column-1')),
          ),
          findsOne,
        );
        // A covering column has no width to drag.
        expect(
          find.byKey(const Key('channel-side-column-resize-1')),
          findsNothing,
        );
        // Not a phone: the card draws its own Back, and no X beside it.
        final back = find.byKey(const Key('channel-side-card-tasks-back'));
        expect(back.hitTestable(), findsOne);
        expect(
          find.byKey(const Key('channel-side-card-tasks-close')),
          findsNothing,
        );
        expect(rect(t, 'chat-header').width, 856);
        await t.tap(back);
        await t.pump();
        expect(rig.store.cardOpen(ChannelSideCard.tasks), isFalse);
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
      },
    );

    testWidgets('944x856 Android: the chat keeps its whole slot', (t) async {
      final rig = await pumpArea(
        t,
        size: const Size(944, 856),
        platform: TargetPlatform.android,
      );
      rig.store.setCardOpen(ChannelSideCard.tasks, true);
      rig.store.setCardOpen(ChannelSideCard.files, true);
      await t.pump();
      expect(rect(t, 'chat-header').width, 944);
      // Both open in one column: the cover shows one at a time under a switch.
      expect(find.byKey(const Key('channel-side-switch')), findsOne);
      expect(rect(t, 'channel-side-overlay').width, 944);
    });

    testWidgets(
      '390x844 Linux: a narrow window covers like a phone, with a mouse (no handle)',
      (t) async {
        final rig = await pumpArea(t, size: const Size(390, 844));
        rig.store.setCardOpen(ChannelSideCard.tasks, true);
        await t.pump();
        expect(find.byKey(const Key('channel-side-overlay')), findsOne);
        expect(
          find.byKey(const Key('channel-side-column-resize-1')),
          findsNothing,
        );
        expect(ChannelSideCards.closeCovering(rig.w), isTrue);
        await t.pump();
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
        expect(ChannelSideCards.closeCovering(rig.w), isFalse);
      },
    );
  });

  test('placeChannelSide: docked widths and compact cover', () {
    VisibleChannelSideColumn column(int i, int width) =>
        VisibleChannelSideColumn(
          column: i,
          sections: const [ChannelSideSection.tasks],
          width: width,
          minWidth: 280,
        );
    final fits = placeChannelSide(
      [column(1, 360)],
      width: 1000,
      compact: false,
      layout: RaftLayoutClass.wide,
    );
    expect(fits.mode, ChannelSideMode.beside);
    expect(fits.columns.single.width, 360);
    // 360 for the chat and both columns at their 280 minimum do not fit in
    // 800: the second waits behind the first instead of both clipping.
    final stacked = placeChannelSide(
      [column(1, 360), column(2, 480)],
      width: 800,
      compact: false,
      layout: RaftLayoutClass.wide,
    );
    expect(stacked.mode, ChannelSideMode.beside);
    expect(stacked.columns.single.width, 360);
    expect(stacked.stackedBelow, 1);
    expect(stacked.columns.every((c) => c.width >= 280), isTrue);
    expect(
      placeChannelSide(
        [column(1, 360)],
        width: 600,
        compact: true,
        layout: RaftLayoutClass.compact,
      ).mode,
      ChannelSideMode.overlay,
    );
    expect(
      placeChannelSide(
        [column(1, 360)],
        width: 519,
        compact: true,
        layout: RaftLayoutClass.compact,
      ).mode,
      ChannelSideMode.overlay,
    );
  });
}
