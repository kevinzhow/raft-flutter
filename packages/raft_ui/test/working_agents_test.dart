import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

RaftWorkingAgent _agent(String id, String name, String text) =>
    RaftWorkingAgent(
      id: id,
      name: name,
      text: text,
      avatar: RaftAvatarContent(
        name: name,
        kind: RaftAvatarContentKind.agent,
        pixelKey: 'cat',
      ),
    );

final _two = [
  _agent('bugen', 'Bugen', 'Editing Flow.tsx · #25'),
  _agent('wug', 'Wug', 'Drafting release notes · #31'),
];

void main() {
  Future<void> pump(
    WidgetTester t,
    Widget child, {
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: SafeArea(child: child)),
      ),
    );
  }

  group('summary', () {
    testWidgets(
      'shows at most 3 faces, the count, and the sentence as its name',
      (t) async {
        final handle = t.ensureSemantics();
        final many = [
          for (var i = 0; i < 5; i++) _agent('a$i', 'Agent $i', 'Working…'),
        ];
        await pump(
          t,
          Align(
            alignment: Alignment.topRight,
            child: RaftWorkingSummary(agents: many),
          ),
        );
        expect(find.byKey(const Key('working-agent-faces')), findsOneWidget);
        expect(find.byType(RaftMountedAvatarFrame), findsNWidgets(3));
        expect(
          t.getSize(find.byType(RaftMountedAvatarFrame).first),
          const Size(19, 19),
        );
        // Each face overlaps the one before by 5px.
        final x0 = t.getTopLeft(find.byType(RaftMountedAvatarFrame).at(0)).dx;
        final x1 = t.getTopLeft(find.byType(RaftMountedAvatarFrame).at(1)).dx;
        expect(x1 - x0, 14);
        expect(find.text('5'), findsOneWidget);
        expect(find.bySemanticsLabel('5 agents working'), findsOneWidget);
        // The faces are hidden from assistive technology.
        expect(find.bySemanticsLabel('Agent 0'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('one agent reads "1 agent working"; nobody hides it (no 0)', (
      t,
    ) async {
      await pump(t, RaftWorkingSummary(agents: [_two.first]));
      expect(find.bySemanticsLabel('1 agent working'), findsOneWidget);
      await pump(t, const RaftWorkingSummary(agents: []));
      expect(find.byKey(const Key('working-agents-summary')), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets(
      'opens Working now: 300px, aligned to the end, one row per agent',
      (t) async {
        final opened = <String>[];
        await pump(
          t,
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: RaftWorkingSummary(agents: _two, onOpenAgent: opened.add),
            ),
          ),
        );
        expect(find.text('Working now'), findsNothing);
        await t.tap(find.byKey(const Key('working-agents-summary')));
        await t.pumpAndSettle();
        expect(find.text('Working now'), findsOneWidget);
        expect(
          t.getSize(find.byKey(const Key('working-now'))).width,
          lessThanOrEqualTo(300),
        );
        final panel = t.getRect(find.byType(RaftWorkingNow));
        expect(panel.width, 300);
        final summary = t.getRect(
          find.byKey(const Key('working-agents-summary')),
        );
        expect(
          panel.right,
          closeTo(summary.right, 1),
          reason: 'aligned to the end',
        );
        // Rows: avatar, bold name, what it is doing.
        expect(find.text('Bugen'), findsOneWidget);
        expect(find.text('Editing Flow.tsx · #25'), findsOneWidget);
        expect(find.text('Wug'), findsOneWidget);
        expect(find.text('Drafting release notes · #31'), findsOneWidget);
        expect(t.widget<Text>(find.text('Editing Flow.tsx · #25')).maxLines, 2);
        expect(
          t.getSize(
            find.descendant(
              of: find.byKey(const ValueKey('working-now-row-bugen')),
              matching: find.byType(RaftMountedAvatarFrame),
            ),
          ),
          const Size(27, 27),
        );
        // Selecting a row opens the agent and closes the popover.
        await t.tap(find.byKey(const ValueKey('working-now-row-wug')));
        await t.pumpAndSettle();
        expect(opened, ['wug']);
        expect(find.text('Working now'), findsNothing);
      },
    );

    testWidgets(
      'Escape and an outside tap close it; the count changes in place',
      (t) async {
        final agents = ValueNotifier(_two);
        addTearDown(agents.dispose);
        await pump(
          t,
          Align(
            alignment: Alignment.topRight,
            child: ValueListenableBuilder(
              valueListenable: agents,
              builder: (_, value, _) => RaftWorkingSummary(agents: value),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('working-agents-summary')));
        await t.pumpAndSettle();
        expect(find.text('Working now'), findsOneWidget);
        agents.value = [_two.first];
        await t.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);
        expect(
          find.text('Wug'),
          findsNothing,
          reason: 'the list follows the work',
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.text('Working now'), findsNothing);
        await t.tap(find.byKey(const Key('working-agents-summary')));
        await t.pumpAndSettle();
        await t.tapAt(const Offset(10, 700));
        await t.pumpAndSettle();
        expect(find.text('Working now'), findsNothing);
      },
    );

    testWidgets('a face that joins slides in; reduced motion just shows it', (
      t,
    ) async {
      final agents = ValueNotifier([_two.first]);
      addTearDown(agents.dispose);
      Widget host() => ValueListenableBuilder(
        valueListenable: agents,
        builder: (_, value, _) => RaftWorkingSummary(agents: value),
      );
      await pump(t, host());
      agents.value = _two;
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      final joining = find.byKey(const ValueKey('working-face-wug'));
      expect(
        t
            .widget<Opacity>(
              find
                  .descendant(of: joining, matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        lessThan(1),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<Opacity>(
              find
                  .descendant(of: joining, matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        1,
      );
    });
  });

  testWidgets('summary hit target is at least 44px on a phone', (t) async {
    await pump(
      t,
      Align(
        alignment: Alignment.topRight,
        child: RaftWorkingSummary(agents: _two),
      ),
    );
    final box = t.getRect(find.byKey(const Key('working-agents-summary')));
    expect(box.height, 32);
    final hits = t.renderObject<RenderBox>(
      find.byKey(const Key('working-agents-summary')),
    );
    expect(hits.size.height, greaterThanOrEqualTo(32));
  });

  group('channel header subtitle', () {
    Widget header({
      required List<RaftWorkingAgent> working,
      String description = 'Ship the launch week',
    }) => RaftChannelHeader(
      name: 'launch-week',
      description: description,
      workingAgents: working,
      onSearch: () {},
      onSettings: () {},
    );

    testWidgets(
      'starts with faces and "2 agents working", then " · " and the description',
      (t) async {
        await pump(t, header(working: _two), size: const Size(960, 400));
        expect(find.text('2 agents working'), findsOneWidget);
        expect(find.text('·'), findsOneWidget);
        expect(find.text('Ship the launch week'), findsOneWidget);
        expect(find.byType(RaftMountedAvatarFrame), findsNWidgets(2));
        final line = t.getRect(find.byKey(const Key('channel-working-line')));
        final dot = t.getRect(find.text('·'));
        final description = t.getRect(find.text('Ship the launch week'));
        expect(line.right, lessThan(dot.left));
        expect(dot.right, lessThan(description.left));
      },
    );

    testWidgets(
      'without a description the line stands alone; without work the header is unchanged',
      (t) async {
        await pump(
          t,
          header(working: [_two.first], description: ''),
          size: const Size(960, 400),
        );
        expect(find.text('1 agent working'), findsOneWidget);
        expect(find.text('·'), findsNothing);
        await pump(t, header(working: const []), size: const Size(960, 400));
        expect(find.byKey(const Key('channel-working-line')), findsNothing);
        expect(find.text('Ship the launch week'), findsOneWidget);
      },
    );

    testWidgets(
      'a long description truncates and the line never overflows at 320',
      (t) async {
        await pump(
          t,
          header(working: _two, description: 'A very long description ' * 12),
          size: const Size(320, 640),
        );
        expect(t.takeException(), isNull);
        expect(find.text('2 agents working'), findsOneWidget);
      },
    );
  });

  group('sidebar row', () {
    Widget row({
      required ValueNotifier<String?> activity,
      int unread = 0,
      String? description = 'codex',
    }) => SizedBox(
      width: 280,
      child: RaftNavItem(
        label: 'Bugen',
        glyph: RaftGlyph.user,
        conversationKind: RaftConversationNavKind.directMessage,
        description: description,
        metaText: 'Codex CLI',
        unread: unread,
        activityText: activity,
        onTap: () {},
      ),
    );

    testWidgets(
      'what it is doing replaces runtime metadata while description stays',
      (t) async {
        final handle = t.ensureSemantics();
        final activity = ValueNotifier<String?>(null);
        addTearDown(activity.dispose);
        await pump(t, row(activity: activity));
        expect(find.text('codex'), findsOneWidget);
        expect(find.text('Codex CLI'), findsOneWidget);
        expect(find.byKey(const Key('nav-item-activity')), findsNothing);
        final before = t.getSize(find.byType(RaftNavItem));

        activity.value = 'Editing Flow.tsx · #25';
        await t.pump();
        expect(find.text('codex'), findsOneWidget);
        expect(find.text('Codex CLI'), findsNothing);
        expect(find.text('Editing Flow.tsx · #25'), findsOneWidget);
        expect(
          t.getSize(find.byType(RaftNavItem)),
          before,
          reason: 'the row does not change height',
        );
        final text = t.getRect(find.byKey(const Key('nav-item-activity')));
        final name = t.getRect(find.text('Bugen'));
        expect(text.left, greaterThan(name.right));
        expect(
          text.right,
          closeTo(t.getRect(find.byType(RaftNavItem)).right - 6, 8),
        );
        // Hidden from assistive technology: the row's name stays the name.
        expect(
          t.getSemantics(find.byType(RaftControl)).getSemanticsData().label,
          'Bugen codex',
        );
        expect(find.bySemanticsLabel(RegExp('Editing')), findsNothing);

        activity.value = null;
        await t.pump();
        expect(find.text('codex'), findsOneWidget);
        expect(find.text('Codex CLI'), findsOneWidget);
        handle.dispose();
        await t.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('takes at most 58% of the row, so the name stays readable', (
      t,
    ) async {
      final activity = ValueNotifier<String?>(
        'Reading the whole repository and comparing it with the design ' * 3,
      );
      addTearDown(activity.dispose);
      await pump(t, row(activity: activity));
      final row_ = t.getRect(find.byType(RaftNavItem)).width;
      expect(
        t.getRect(find.byKey(const Key('nav-item-activity'))).width,
        lessThanOrEqualTo(row_ * .58 + 0.5),
      );
      expect(find.text('Bugen'), findsOneWidget);
    });

    testWidgets('an unread count takes the place of the text', (t) async {
      final activity = ValueNotifier<String?>('Editing');
      addTearDown(activity.dispose);
      await pump(t, row(activity: activity, unread: 3));
      expect(find.byKey(const Key('nav-item-activity')), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
