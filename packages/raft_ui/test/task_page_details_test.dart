import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

final _toggle = find.byKey(const ValueKey('task-details-toggle'));
final _drawer = find.byKey(const ValueKey('task-head-pull-down'));
final _title = find.byKey(const ValueKey('task-modal-title'));
final _discussion = find.byKey(const ValueKey('discussion'));
final _draft = find.byKey(const ValueKey('draft'));

Future<void> _openTask(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  bool inPlace = false,
  bool tallHistory = false,
  bool legacy = false,
  bool unavailable = false,
  ValueNotifier<String>? liveStatus,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: ListenableBuilder(
                    listenable:
                        liveStatus ??
                        const AlwaysStoppedAnimation('in_progress'),
                    builder: (context, _) => RaftTaskSurface(
                      page: !inPlace,
                      inPlace: inPlace,
                      conversation: RaftTaskConversation(
                        ref: '#general:#8',
                        onViewInChannel: () {},
                      ),
                      task: {
                        'id': 't1',
                        'taskNumber': 8,
                        'title': 'Review the release',
                        'status': liveStatus?.value ?? 'in_progress',
                        'createdByName': 'Alice',
                      },
                      history: [
                        if (tallHistory)
                          for (var i = 0; i < 30; i++)
                            {
                              'eventType': 'created',
                              'actorName': 'Reviewer $i',
                            },
                      ],
                      assignees: const [],
                      legacy: legacy,
                      loading: false,
                      historyLoading: false,
                      busy: false,
                      canStatus: true,
                      canAssign: false,
                      canCleanupDelete: false,
                      statusOptions: raftTaskStatuses,
                      onClose: () => Navigator.of(context).pop(),
                      onRetry: () async {},
                      onLoadAssignees: () async {},
                      onUpdate: (_, _) async {},
                      formatTime: (_) => '09:00',
                      unresolvedBody: unavailable
                          ? const Text('Task unavailable')
                          : null,
                      discussionBuilder: (slot) => Column(
                        children: [
                          Expanded(
                            child: CustomScrollView(
                              key: const ValueKey('discussion'),
                              slivers: [
                                SliverToBoxAdapter(child: slot),
                                SliverList.builder(
                                  itemCount: 60,
                                  itemBuilder: (_, i) => SizedBox(
                                    height: 48,
                                    child: Text('reply $i'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const TextField(key: ValueKey('draft')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open task'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open task'));
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester, Finder parent) => tester
    .state<ScrollableState>(
      find.descendant(of: parent, matching: find.byType(Scrollable)).first,
    )
    .position;

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool mouse = false,
}) async {
  await tester.tap(
    target,
    kind: mouse ? PointerDeviceKind.mouse : PointerDeviceKind.touch,
  );
  await tester.pumpAndSettle();
}

void _expectToggleSemantics(WidgetTester tester, {required bool expanded}) {
  final data = tester.getSemantics(_toggle).getSemanticsData();
  expect(data.label, expanded ? 'Hide task details' : 'Show task details');
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(data.flagsCollection.isExpanded.toBoolOrNull(), expanded);
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets('narrow task drawer preserves the discussion on $platform', (
      tester,
    ) async {
      await _openTask(tester, platform: platform);
      expect(_toggle, findsOneWidget);
      _expectToggleSemantics(tester, expanded: false);
      expect(_title, findsNothing);
      expect(_drawer, findsNothing);
      await tester.enterText(_draft, 'Unsent reply');
      final position = _position(tester, _discussion);
      position.jumpTo(480);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(_discussion);
      final draft = tester.state(
        find.descendant(of: _draft, matching: find.byType(EditableText)),
      );

      final mouse = platform == TargetPlatform.linux;
      await _tap(tester, _toggle, mouse: mouse);
      expect(_drawer, findsOneWidget);
      _expectToggleSemantics(tester, expanded: true);
      expect(find.descendant(of: _drawer, matching: _title), findsOneWidget);
      expect(tester.getRect(_discussion), viewport);
      expect(_position(tester, _discussion), same(position));
      expect(position.pixels, 480);

      await _tap(tester, _toggle, mouse: mouse);
      expect(_drawer, findsNothing);
      expect(_title, findsNothing);
      expect(tester.getRect(_discussion), viewport);
      expect(_position(tester, _discussion), same(position));
      expect(position.pixels, 480);
      expect(find.text('Unsent reply'), findsOneWidget);
      expect(
        tester.state(
          find.descendant(of: _draft, matching: find.byType(EditableText)),
        ),
        same(draft),
      );

      await _tap(tester, _toggle, mouse: mouse);
      await tester.tapAt(Offset(12, viewport.bottom - 16));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_drawer, findsOneWidget);
      final focus = tester.widget<RaftButton>(_toggle).focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(_toggle, findsOneWidget);
      _expectToggleSemantics(tester, expanded: false);
      expect(focus.hasPrimaryFocus, isTrue);
    }, semanticsEnabled: true);
  }

  testWidgets('platform Back closes the narrow drawer before the task', (
    tester,
  ) async {
    await _openTask(tester);
    await _tap(tester, _toggle);
    expect(_drawer, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_drawer, findsNothing);
    expect(_toggle, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_drawer, findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open task'), findsOneWidget);
  });

  for (final size in [const Size(856, 944), const Size(944, 856)]) {
    testWidgets('wide touch slot starts pinned and can reopen at $size', (
      tester,
    ) async {
      await _openTask(tester, size: size, inPlace: true);
      expect(_title, findsOneWidget);
      expect(_toggle, findsOneWidget);
      final position = _position(tester, _discussion);
      position.jumpTo(480);
      await tester.pumpAndSettle();
      final pinnedViewport = tester.getRect(_discussion);

      await _tap(tester, _toggle);
      expect(_title, findsNothing);
      expect(_drawer, findsNothing);
      expect(
        tester.getRect(_discussion).height,
        greaterThan(pinnedViewport.height),
      );
      expect(_position(tester, _discussion), same(position));
      expect(position.pixels, 480);

      await _tap(tester, _toggle);
      expect(_title, findsOneWidget);
      expect(tester.getRect(_discussion), pinnedViewport);
      expect(_position(tester, _discussion), same(position));
      expect(position.pixels, 480);
    });
  }

  testWidgets('short window scrolls history inside the drawer', (tester) async {
    await _openTask(tester, size: const Size(390, 235), tallHistory: true);
    await _tap(tester, _toggle);
    await _tap(tester, find.text('History'));
    final position = _position(tester, _drawer);
    final bounds = tester.getRect(_drawer);
    expect(bounds.bottom, lessThanOrEqualTo(235));
    expect(position.maxScrollExtent, greaterThan(120));
    await tester.dragFrom(bounds.center, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(_drawer, findsOneWidget);
    expect(position.pixels, greaterThan(0));
    expect(_position(tester, _discussion).pixels, 0);
  });

  testWidgets('the open drawer follows live task status', (tester) async {
    final status = ValueNotifier('in_progress');
    addTearDown(status.dispose);
    await _openTask(tester, liveStatus: status);
    await _tap(tester, _toggle);
    status.value = 'closed';
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _drawer, matching: find.text('Closed')),
      findsOneWidget,
    );
  });

  testWidgets('legacy pages keep their read-only presentation', (tester) async {
    await _openTask(tester, legacy: true);
    expect(_toggle, findsNothing);
    expect(find.text('Review the release'), findsOneWidget);
  });

  testWidgets('unavailable pages keep their resolution body', (tester) async {
    await _openTask(tester, unavailable: true);
    expect(_toggle, findsNothing);
    expect(find.text('Task unavailable'), findsOneWidget);
  });
}
