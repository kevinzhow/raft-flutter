// Moving a section to another column or a new one (Web v1.24
// `sideSectionDrag.tsx`, WP-SIDE F13): the grip on a card's head, a mouse drag
// with the proxy and the place shown, the keyboard (Space, arrows, Space,
// Escape) with its announcements, the refusal where no room is left, and where
// no drag exists at all (touch, a phone, floating, one section).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show MessageAdapter, fixture;

/// How often each section's body was made (a move must not remake it).
final Map<ChannelSideSection, int> inits = {};

class _Body extends StatefulWidget {
  const _Body(this.section);
  final ChannelSideSection section;
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  @override
  void initState() {
    super.initState();
    inits[widget.section] = (inits[widget.section] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: Key('body-${widget.section.name}'),
    child: const ColoredBox(color: Color(0xFFEEEEEE)),
  );
}

class Rig {
  Rig(this.w, this.transport, this.store, this.announced);
  final WorkspaceController w;
  final MessageAdapter transport;
  final ChannelSideStore store;

  /// What the screen reader was told, in order.
  final List<String> announced;

  List<RequestOptions> get saves => [
    for (final c in transport.calls)
      if (c.method == 'PATCH' && c.path == '/servers/s1/sidebar-order') c,
  ];
}

Future<Rig> pump(
  WidgetTester t, {
  Size size = const Size(1200, 800),
  TargetPlatform platform = TargetPlatform.linux,
  bool tasks = true,
  bool files = true,
  bool dark = false,
  bool bodies = true,
  // Room the rail and the channel sidebar take out of the window before the
  // area sees it, as the full workspace does: the layout class comes from the
  // window, the fit from what is left.
  double chrome = 0,
  Map<String, Object> savedPreferences = const {},
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  inits.clear();
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues(savedPreferences);
  await t.runAsync(() async {
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  addTearDown(DevicePreferences.reset);
  final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  transport.routes['PATCH /servers/s1/sidebar-order'] = (_) => {};
  w.navigation.bind(
    'side-drag',
    RaftLocation.at(serverSlug: 's1', route: RaftRoute.channel, entityId: 'c1'),
  );
  await t.runAsync(() async {
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  TaskV2ConversationsFlag.of(w).markEnabled();
  final store = ChannelSideStore.of(w);
  final announced = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () =>
        t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark).copyWith(platform: platform),
      home: Scaffold(
        body: Row(
          children: [
            if (chrome > 0) SizedBox(width: chrome),
            Expanded(
              child: ChannelSideArea(
                controller: w,
                bodyOf: bodies ? (context, section) => _Body(section) : null,
                child: const ColoredBox(
                  key: Key('chat'),
                  color: Color(0xFFFFFFFF),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (tasks) store.setCardOpen(ChannelSideCard.tasks, true);
  if (files) store.setCardOpen(ChannelSideCard.files, true);
  await t.pump();
  return Rig(w, transport, store, announced);
}

/// A window wide enough for the dock (a desktop class) whose area, once the
/// rail and the sidebar have taken theirs, has no room for a third column:
/// 360 for the chat and three columns at the 160 floor need 840 of 780. The
/// Artifact is opened first, so Tasks and Files keep their place beside the
/// chat and it is the pane waiting behind them.
Future<Rig> _tooNarrowForAnotherColumn(WidgetTester t) async {
  final rig = await pump(
    t,
    size: const Size(1100, 800),
    chrome: 320,
    tasks: false,
    files: false,
  );
  WebPreviewStore.of(rig.w).open(
    const WebPreviewPage(url: 'https://example.com/a', conversationId: 'c1'),
  );
  await t.pump();
  rig.store.setCardOpen(ChannelSideCard.tasks, true);
  rig.store.setCardOpen(ChannelSideCard.files, true);
  await t.pump();
  return rig;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
}

Finder grip(ChannelSideSection s) =>
    find.byKey(Key('side-section-grip-${s.name}'));

Rect rect(WidgetTester t, String key) => t.getRect(find.byKey(Key(key)));

/// Presses the grip with a mouse, moves past the slop and on to [to].
Future<TestGesture> pickUp(
  WidgetTester t,
  ChannelSideSection s,
  Offset to,
) async {
  final g = await t.startGesture(
    t.getCenter(grip(s)),
    kind: PointerDeviceKind.mouse,
  );
  await g.moveBy(const Offset(0, 10));
  await g.moveTo(to);
  await t.pump();
  return g;
}

String columnsOf(ChannelSideLayout l) => [
  for (final c in l.columns)
    if (c.sections.any(
      (s) => s == ChannelSideSection.tasks || s == ChannelSideSection.files,
    ))
      [
        for (final s in c.sections)
          if (s == ChannelSideSection.tasks || s == ChannelSideSection.files)
            s.name,
      ].join('+'),
].join(' | ');

/// Space, an arrow or Escape on the focused grip.
Future<void> key(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyEvent(k);
  await t.pump();
}

void focusGrip(WidgetTester t, ChannelSideSection s) {
  Focus.of(t.element(grip(s))).requestFocus();
}

void main() {
  // The Artifact case mounts the real Files body, whose store the workspace
  // keeps (the debt every test with a real Files card carries).
  leakDebt(const ['SourceChannelFilesStore']);
  const files = ChannelSideSection.files;
  const tasks = ChannelSideSection.tasks;

  testWidgets('Expand and Restore preserve folds and the draggable dock', (
    t,
  ) async {
    final rig = await pump(t);
    final expandTasks = find.byKey(const Key('channel-side-card-tasks-expand'));
    final expandFiles = find.byKey(const Key('channel-side-card-files-expand'));
    final foldFiles = find.byKey(const Key('channel-side-card-files-collapse'));
    final bodyFiles = find.byKey(const Key('body-files'));
    await t.tap(foldFiles);
    await t.pump();
    expect(bodyFiles, findsNothing);
    final taskHead = rect(t, 'channel-side-card-tasks-header');
    final fileHead = rect(t, 'channel-side-card-files-header');
    final column = rect(t, 'channel-side-column-1');
    expect(taskHead.left, column.left + 1);
    expect(taskHead.right, column.right);
    expect(t.getSize(expandTasks), const Size.square(28));
    final taskTitle = find.descendant(
      of: find.byKey(const Key('channel-side-card-tasks-header')),
      matching: find.text('Tasks'),
    );
    expect(t.getTopLeft(taskTitle).dx - taskHead.left, 51);

    expect(expandTasks.hitTestable(), findsOne);
    await t.tap(expandTasks);
    await t.pump();
    expect(rect(t, 'chat').width, 360);
    expect(rect(t, 'channel-side-conversation').width, 160);
    expect(rect(t, 'channel-side-card-tasks-header').width, 1039);
    expect(foldFiles, findsNothing);

    await t.tap(expandFiles.hitTestable());
    await t.pump();
    expect(bodyFiles, findsOne);
    expect(find.byKey(const Key('body-tasks')), findsNothing);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(rect(t, 'channel-side-card-tasks-header'), taskHead);
    expect(rect(t, 'channel-side-card-files-header'), fileHead);
    expect(bodyFiles, findsNothing);
    expect(rig.store.collapsed(ChannelSideCard.files), isTrue);
    expect(rig.saves, isEmpty);

    await t.tap(expandTasks);
    await t.pump();
    await t.tap(expandTasks);
    await t.pump();
    expect(rect(t, 'channel-side-card-tasks-header'), taskHead);

    final g = await pickUp(t, files, Offset(taskHead.right - 6, 300));
    await g.up();
    await settle(t);
    expect(columnsOf(rig.store.layout), 'tasks | files');
    expect(rig.saves, hasLength(1));
    expect(inits[tasks], 1);
    expect(inits[files], 1);
    await t.pumpWidget(const SizedBox.shrink());
  });

  // A medium window (a foldable inner screen) covers the conversation, so
  // there is no dock to expand there; a touched tablet is where Expand by
  // finger lives (the cover at the foldable sizes is in
  // channel_side_fit_guard_test and channel_side_area_test).
  for (final size in [const Size(1104, 884), const Size(1180, 820)]) {
    testWidgets('touch $size expands by touch without a drag grip', (t) async {
      final rig = await pump(t, size: size, platform: TargetPlatform.android);
      final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
      final original = rect(t, 'channel-side-card-tasks-header');
      expect(grip(tasks), findsNothing);
      await t.tap(expand.hitTestable());
      await t.pump();
      expect(rect(t, 'channel-side-card-tasks-header').width, size.width - 161);
      await t.tap(expand.hitTestable());
      await t.pump();
      expect(rect(t, 'channel-side-card-tasks-header'), original);
      expect(rig.saves, isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('More actions moves Files into a new docked column', (t) async {
    final rig = await pump(t);
    final more = find.byKey(const Key('channel-side-card-files-overflow'));
    await t.tap(more.hitTestable());
    await t.pumpAndSettle();
    await t.tap(find.text('Move right').hitTestable());
    await settle(t);
    expect(columnsOf(rig.store.layout), 'tasks | files');
    expect(rig.saves, hasLength(1));
    expect(inits[files], 1);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expanded dock resizes from its displayed seam', (t) async {
    final rig = await pump(t);
    final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
    const column = 'channel-side-column-1';
    const conversation = 'channel-side-conversation';
    final filesBefore = rect(t, 'channel-side-card-files-header');
    final normalWidth = rect(t, column).width;
    Future<void> clickExpand() async {
      await t.tap(expand.hitTestable());
      await t.pump();
    }

    Future<TestGesture> dragFromSeam(double delta) async {
      final dock = rect(t, column);
      final g = await t.startGesture(
        dock.topLeft + const Offset(6, 116),
        kind: PointerDeviceKind.mouse,
      );
      for (var step = 0; step < 8; step++) {
        await g.moveBy(Offset(delta / 8, 0));
        await t.pump();
      }
      return g;
    }

    await clickExpand();
    final shownWidth = rect(t, column).width;
    expect(rect(t, conversation).width, 160);
    final clamped = await dragFromSeam(-80);
    await clamped.up();
    await t.pump();
    expect(rect(t, column).width, shownWidth);
    expect(rig.saves, isEmpty);
    await clickExpand();
    expect(rect(t, column).width, normalWidth);
    expect(rect(t, 'channel-side-card-files-header'), filesBefore);

    await clickExpand();
    final moved = await dragFromSeam(80);
    final liveWidth = rect(t, column).width;
    final liveConversation = rect(t, conversation).width;
    await moved.up();
    await settle(t);
    expect(liveWidth, shownWidth - 80);
    expect(liveConversation, 240);
    expect(rect(t, column).width, shownWidth - 80);
    expect(rect(t, 'channel-side-card-files-header').top, filesBefore.top);
    expect(rig.saves, hasLength(1));
    await clickExpand();
    expect(rect(t, column).width, shownWidth);
    await clickExpand();
    expect(rect(t, column).width, shownWidth - 80);
    expect(rect(t, conversation).width, 240);
    expect(rig.saves, hasLength(1));
  });

  testWidgets('expanded width survives rebind with its saved desktop layout', (
    t,
  ) async {
    const layoutKey = 'raft.channelSide.layout';
    final legacyLayout = ChannelSideLayout.defaults.resize(1, 960);
    final rig = await pump(
      t,
      savedPreferences: {layoutKey: jsonEncode(legacyLayout.toJson())},
    );
    const conversation = 'channel-side-conversation';
    const column = 'channel-side-column-1';
    expect(rect(t, conversation).width, 360);
    expect(rect(t, column).width, 840);
    final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
    await t.tap(expand.hitTestable());
    await t.pump();
    final gesture = await t.startGesture(
      rect(t, column).topLeft + const Offset(6, 116),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(80, 0));
    await t.pump();
    expect(rect(t, conversation).width, 240);
    expect(rect(t, column).width, 960);
    await gesture.up();
    await settle(t);
    expect(rig.saves, hasLength(1));
    final preferences = DevicePreferences.current!;
    await t.runAsync(preferences.reload);
    final saved = {
      for (final key in preferences.getKeys())
        if (key.startsWith('raft.channelSide.')) key: preferences.get(key)!,
    };
    expect(jsonDecode(saved[layoutKey]! as String), legacyLayout.toJson());
    expect(
      (rig.saves.single.data as Map)['channelSideLayout'],
      legacyLayout.toJson(),
    );
    final areaState = t.state(find.byType(ChannelSideArea));
    final rebound = await pump(t, savedPreferences: saved);
    expect(t.state(find.byType(ChannelSideArea)), same(areaState));
    expect(rebound.w, isNot(same(rig.w)));
    final reloaded = (rect(t, conversation).width, rect(t, column).width);
    expect(reloaded, (240, 960));
    expect(saved['raft.channelSide.conversationWidth'], '240');
    expect((rig.saves.single.data as Map).keys, ['channelSideLayout']);
    await t.tap(expand.hitTestable());
    await t.pump();
    await t.tap(expand.hitTestable());
    await t.pump();
    expect((rect(t, conversation).width, rect(t, column).width), reloaded);
    expect(rebound.saves, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
    final fresh = await pump(t, savedPreferences: saved);
    expect((rect(t, conversation).width, rect(t, column).width), reloaded);
    expect(fresh.saves, isEmpty);
    final handle = find.byKey(const Key('channel-side-column-resize-1'));
    Focus.of(
      t.element(
        find.descendant(of: handle, matching: find.byType(RaftHoverRegion)),
      ),
    ).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await settle(t);
    expect((rect(t, conversation).width, rect(t, column).width), (224, 976));
    expect(fresh.saves, hasLength(1));
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expanded resize fits a changing viewport with Files beside it', (
    t,
  ) async {
    final rig = await pump(t, size: const Size(1190, 800));
    await t.tap(
      find.byKey(const Key('channel-side-card-files-overflow')).hitTestable(),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Move right').hitTestable());
    await settle(t);
    expect(columnsOf(rig.store.layout), 'tasks | files');
    final savesBefore = rig.saves.length;
    final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
    await t.tap(expand.hitTestable());
    await t.pump();
    Rect taskDock() => rect(t, 'channel-side-column-1');
    (double, double, double) widths() => (
      rect(t, 'channel-side-conversation').width,
      taskDock().width,
      rect(t, 'channel-side-column-2').width,
    );
    expect(widths(), (160, 870, 160));
    expect(
      rect(t, 'channel-side-card-files-header').left,
      taskDock().right + 1,
    );
    final gesture = await t.startGesture(
      taskDock().topLeft + const Offset(6, 116),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(80, 0));
    await t.pump();
    final held = widths();
    t.view.physicalSize = const Size(1070, 800);
    await t.pump();
    final shrunk = widths();
    await gesture.moveBy(const Offset(20, 0));
    await t.pump();
    final continued = widths();
    expect(rig.saves, hasLength(savesBefore));
    await gesture.up();
    await settle(t);
    final released = widths();
    t.view.physicalSize = const Size(1190, 800);
    await t.pump();
    expect(held, (240, 790, 160));
    expect(shrunk, (240, 670, 160));
    expect(continued, (260, 650, 160));
    expect(released, continued);
    expect(widths(), (260, 770, 160));
    expect(
      rect(t, 'channel-side-card-files-header').left,
      taskDock().right + 1,
    );
    expect(rig.saves, hasLength(savesBefore + 1));
    await t.tap(expand.hitTestable());
    await t.pump();
    await t.tap(expand.hitTestable());
    await t.pump();
    expect(widths(), (260, 770, 160));
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expanded dock suspends move grips until Restore', (t) async {
    final rig = await pump(t);
    final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
    final proxy = find.byKey(const Key('side-section-proxy'));
    expect(grip(tasks).hitTestable(), findsOne);
    await t.tap(expand);
    await t.pump();
    final header = rect(t, 'channel-side-card-tasks-header');
    final formerGrip = header.topCenter + const Offset(0, 16);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(formerGrip);
    await t.pump();
    await mouse.down(formerGrip);
    await mouse.moveBy(const Offset(24, 12));
    await t.pump();
    final pickedUpWhileExpanded = proxy.evaluate().isNotEmpty;
    await mouse.cancel();
    await mouse.removePointer();
    await t.pump();
    expect(pickedUpWhileExpanded, isFalse);
    expect(grip(tasks), findsNothing);
    expect(grip(files), findsNothing);
    expect(rig.saves, isEmpty);

    await t.tap(expand);
    await t.pump();
    expect(grip(tasks).hitTestable(), findsOne);
    expect(grip(files).hitTestable(), findsOne);
    final restoredDrag = await pickUp(t, tasks, header.center);
    expect(proxy, findsOne);
    await restoredDrag.cancel();
    await t.pump();
    expect(proxy, findsNothing);
    focusGrip(t, files);
    await t.pump();
    await key(t, LogicalKeyboardKey.space);
    expect(proxy, findsOne);
    await key(t, LogicalKeyboardKey.arrowDown);
    expect(find.byKey(const Key('side-section-drop-slot')), findsOne);
    await key(t, LogicalKeyboardKey.escape);
    expect(proxy, findsNothing);
    expect(columnsOf(rig.store.layout), 'tasks+files');
    expect(rig.saves, isEmpty);
  });

  group('a mouse drag', () {
    testWidgets('Files to a new column right of Tasks: saved once', (t) async {
      final rig = await pump(t);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      final column = rect(t, 'channel-side-column-1');
      final g = await pickUp(t, files, Offset(column.right - 6, 300));
      // Mid-drag: Files stays faded where it is, a proxy follows the pointer,
      // the new column's strip shows at the edge, nothing is saved yet.
      expect(find.byKey(const Key('side-section-proxy')), findsOne);
      expect(find.byKey(const Key('side-section-drop-slot')), findsOne);
      final slot = t.getRect(find.byKey(const Key('side-section-drop-slot')));
      expect(slot.right, lessThanOrEqualTo(1200));
      expect(slot.height, greaterThan(700));
      expect(
        t
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('channel-side-card-files')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        .4,
      );
      expect(rig.saves, isEmpty);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'tasks | files');
      expect(rig.saves, hasLength(1));
      expect(
        (rig.saves.single.data as Map)['channelSideLayout']['columns'],
        isA<List>(),
      );
      // Files stands in a column of its own, right of Tasks, and the drag is over.
      expect(
        rect(t, 'channel-side-column-2').left,
        greaterThan(rect(t, 'channel-side-column-1').left),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('channel-side-column-2')),
          matching: find.byKey(const Key('channel-side-card-files')),
        ),
        findsOne,
      );
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      expect(find.byKey(const Key('side-section-drop-slot')), findsNothing);
      expect(
        t
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byKey(const Key('channel-side-card-files')),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        1,
      );
    });

    testWidgets('into the other column, above a section', (t) async {
      final rig = await pump(t);
      rig.store.moveSection(files, const ChannelSideDropNewColumn(2));
      await t.pump();
      await settle(t);
      rig.transport.calls.clear();
      expect(columnsOf(rig.store.layout), 'tasks | files');
      final target = rect(t, 'channel-side-column-1');
      final g = await pickUp(t, files, Offset(target.center.dx, 100));
      expect(find.byKey(const Key('side-section-drop-slot')), findsOne);
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'files+tasks');
      expect(rig.saves, hasLength(1));
      // One column is left.
      expect(find.byKey(const Key('channel-side-column-2')), findsNothing);
    });

    testWidgets('dropped on the chat: a new column left of the others', (
      t,
    ) async {
      final rig = await pump(t);
      final g = await pickUp(t, files, const Offset(300, 300));
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'files | tasks');
      expect(rig.saves, hasLength(1));
    });

    testWidgets('Escape cancels: nothing saved, nothing moved', (t) async {
      final rig = await pump(t);
      final column = rect(t, 'channel-side-column-1');
      final g = await pickUp(t, files, Offset(column.right - 6, 300));
      expect(find.byKey(const Key('side-section-drop-slot')), findsOne);
      await key(t, LogicalKeyboardKey.escape);
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      expect(find.byKey(const Key('side-section-drop-slot')), findsNothing);
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      expect(rig.saves, isEmpty);
      expect(rig.announced.last, 'Moving Files cancelled.');
    });

    testWidgets('released over no place: nothing saved', (t) async {
      final rig = await pump(t);
      final g = await pickUp(t, files, const Offset(-50, 300));
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      expect(rig.saves, isEmpty);
    });

    testWidgets('a press that stays under the slop is no drag', (t) async {
      await pump(t);
      final g = await t.startGesture(
        t.getCenter(grip(files)),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(2, 1));
      await t.pump();
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      await g.up();
    });

    testWidgets('the head keeps its buttons: Close still closes', (t) async {
      final rig = await pump(t);
      await t.tap(find.byKey(const Key('channel-side-card-files-close')));
      await t.pump();
      expect(rig.store.cardOpen(ChannelSideCard.files), isFalse);
    });

    testWidgets('a new column that does not fit is refused, with the reason', (
      t,
    ) async {
      final rig = await _tooNarrowForAnotherColumn(t);
      final column = rect(t, 'channel-side-column-1');
      final expand = find.byKey(const Key('channel-side-card-tasks-expand'));
      final overflow = find.byKey(
        const Key('channel-side-card-tasks-overflow'),
      );
      expect(expand.hitTestable(), findsOne);
      expect(overflow.hitTestable(), findsOne);
      final g = await pickUp(t, files, Offset(column.left + 6, 300));
      expect(
        find.text('The window is too narrow for another column.'),
        findsOne,
      );
      expect(find.byKey(const Key('side-section-drop-slot')), findsNothing);
      expect(
        rig.announced,
        contains('The window is too narrow for another column.'),
      );
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      expect(rig.saves, isEmpty);
      expect(
        find.text('The window is too narrow for another column.'),
        findsNothing,
      );
    });
  });

  group('the keyboard', () {
    testWidgets('the grip is a labelled button with its instructions', (
      t,
    ) async {
      await pump(t);
      final node = t.getSemantics(grip(files));
      expect(node.label, contains('Move Files'));
      expect(node.hint, contains('Press Space to pick up the section'));
      expect(node.value, 'movable section');
      // Along the head's top edge: 96 wide, centred, 24 tall.
      final g = t.getRect(grip(files));
      final head = rect(t, 'channel-side-card-files-header');
      expect(g.width, 96);
      expect(g.height, 24);
      expect(g.center.dx, closeTo(head.center.dx, .5));
      expect(g.top, closeTo(head.top + 6, .5));
    });

    testWidgets('Space picks up, arrows choose, Space drops; announced', (
      t,
    ) async {
      final rig = await pump(t);
      focusGrip(t, files);
      await t.pump();
      await key(t, LogicalKeyboardKey.space);
      expect(rig.announced, ['Picked up Files.']);
      await key(t, LogicalKeyboardKey.arrowDown);
      expect(
        rig.announced.last,
        'Files will move to a new column left of Tasks.',
      );
      await key(t, LogicalKeyboardKey.arrowDown);
      expect(rig.announced.last, 'Files will move above Tasks.');
      await key(t, LogicalKeyboardKey.arrowDown);
      expect(
        rig.announced.last,
        'Files will move to a new column right of Tasks.',
      );
      expect(find.byKey(const Key('side-section-drop-slot')), findsOne);
      expect(rig.saves, isEmpty);
      await key(t, LogicalKeyboardKey.space);
      await settle(t);
      expect(rig.announced.last, 'Files moved to a new column right of Tasks.');
      expect(columnsOf(rig.store.layout), 'tasks | files');
      expect(rig.saves, hasLength(1));
      // The focus is back on the grip, in its new column.
      expect(Focus.of(t.element(grip(files))).hasPrimaryFocus, isTrue);
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
    });

    testWidgets('Up from the start goes to the last place; Escape cancels', (
      t,
    ) async {
      final rig = await pump(t);
      focusGrip(t, files);
      await t.pump();
      await key(t, LogicalKeyboardKey.space);
      await key(t, LogicalKeyboardKey.arrowUp);
      expect(
        rig.announced.last,
        'Files will move to a new column right of Tasks.',
      );
      await key(t, LogicalKeyboardKey.escape);
      expect(rig.announced.last, 'Moving Files cancelled.');
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      expect(columnsOf(rig.store.layout), 'tasks+files');
      expect(rig.saves, isEmpty);
    });

    testWidgets('the focus leaving the grip cancels a keyboard move', (
      t,
    ) async {
      final rig = await pump(t);
      focusGrip(t, files);
      await t.pump();
      await key(t, LogicalKeyboardKey.space);
      expect(find.byKey(const Key('side-section-proxy')), findsOne);
      focusGrip(t, tasks);
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('side-section-proxy')), findsNothing);
      expect(rig.announced.last, 'Moving Files cancelled.');
      expect(rig.saves, isEmpty);
    });

    testWidgets('a place with no room is not offered, and said once', (
      t,
    ) async {
      final rig = await _tooNarrowForAnotherColumn(t);
      focusGrip(t, files);
      await t.pump();
      await key(t, LogicalKeyboardKey.space);
      expect(
        rig.announced.single,
        'Picked up Files. The window is too narrow for another column.',
      );
      // Every place the arrows reach is one that fits.
      final said = <String>{};
      for (var i = 0; i < 8; i++) {
        await key(t, LogicalKeyboardKey.arrowDown);
        said.add(rig.announced.last);
      }
      expect(said, isNotEmpty);
      for (final s in said) {
        expect(s, isNot(contains('new column')));
      }
    });

    testWidgets('Artifact can be picked up too', (t) async {
      final rig = await pump(t, size: const Size(1400, 800), bodies: false);
      WebPreviewStore.of(rig.w).open(
        const WebPreviewPage(
          url: 'https://example.com/a',
          conversationId: 'c1',
        ),
      );
      await t.pump();
      expect(grip(ChannelSideSection.artifact), findsOne);
      focusGrip(t, ChannelSideSection.artifact);
      await t.pump();
      await key(t, LogicalKeyboardKey.space);
      expect(rig.announced.single, 'Picked up Artifact.');
      await key(t, LogicalKeyboardKey.escape);
      // The real Tasks and Files bodies ask the server: let that finish.
      await settle(t);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('no drag', () {
    testWidgets('both sections open on desktop: both have a grip', (t) async {
      await pump(t);
      expect(grip(tasks), findsOne);
      expect(grip(files), findsOne);
    });

    testWidgets('one section alone has nowhere to go', (t) async {
      await pump(t, files: false);
      expect(grip(tasks), findsNothing);
    });

    testWidgets('by touch: an unfolded tablet is as wide, still no grip', (
      t,
    ) async {
      await pump(
        t,
        size: const Size(856, 944),
        platform: TargetPlatform.android,
      );
      expect(find.byKey(const Key('channel-side-column-1')), findsOne);
      expect(grip(files), findsNothing);
      expect(grip(tasks), findsNothing);
    });

    testWidgets('a phone: the cards cover the chat, no grip', (t) async {
      await pump(
        t,
        size: const Size(390, 844),
        platform: TargetPlatform.android,
      );
      expect(grip(files), findsNothing);
    });

    testWidgets('a narrow desktop window: covering, no grip', (t) async {
      await pump(t, size: const Size(390, 844));
      expect(find.byKey(const Key('channel-side-overlay')), findsOne);
      expect(grip(files), findsNothing);
      expect(
        find.byKey(const Key('channel-side-card-files-expand')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('channel-side-card-files-overflow')),
        findsNothing,
      );
    });

    testWidgets('a wide compact window: covering, no grip', (t) async {
      await pump(t, size: const Size(600, 800));
      expect(find.byKey(const Key('channel-side-overlay')), findsOne);
      expect(grip(files), findsNothing);
    });
  });

  group('the moved card', () {
    testWidgets('keeps its body: no remount, same state', (t) async {
      final rig = await pump(t);
      expect(inits, {tasks: 1, files: 1});
      final column = rect(t, 'channel-side-column-1');
      final g = await pickUp(t, files, Offset(column.right - 6, 300));
      await g.up();
      await settle(t);
      expect(columnsOf(rig.store.layout), 'tasks | files');
      expect(find.byKey(const Key('body-files')), findsOne);
      expect(inits, {tasks: 1, files: 1});
    });
  });
}
