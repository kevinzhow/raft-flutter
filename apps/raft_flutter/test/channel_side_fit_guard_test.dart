// The side-pane rule, at every screen class: a pane never stands beside the
// conversation below its own minimum width (channelSideColumnMinWidth), the
// chat never below 360 and never clipped, and the medium class (a foldable
// inner screen, a narrow desktop window) covers the conversation with exactly
// one pane whose head has a back control.
//
// New entries are meant to be obvious to add: [_openers] says how each
// ChannelSideSection opens, and `every side section is registered` fails when
// a section is added to the enum without one.
//
// Three layers, because exhaustiveness is cheap in one and rendering matters
// in another:
//   1. every section, on its own and in every ordered pair, at every window
//      size, through `placeChannelSide` (the widths it returns are the widths
//      the area gives its columns);
//   2. the same states rendered at each size, measured off the render tree;
//   3. the whole workspace, for the panes whose open-ness only exists there
//      (the docked and the folded thread) and for the real Details and
//      Profile heads.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_card.dart'
    show ChannelSideMode;
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_column.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_layout.dart';
import 'package:raft_flutter/features/channel_side_stack.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/channel_side_web_preview.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show fixture;
import 'support/close_support.dart' show frames, mountWorkspace;

/// The windows this rule is checked at. The foldable inner screens and the
/// tablet are touched, the desktop window has a pointer; 856x944 and 944x856
/// are the Android foldable sizes the repo requires of a new interaction
/// (AGENTS.md), and the back arrow is a new interaction.
const _sizes = <String, (Size, TargetPlatform)>{
  '841x701': (Size(841, 701), TargetPlatform.android),
  '856x944': (Size(856, 944), TargetPlatform.android),
  '884x1104': (Size(884, 1104), TargetPlatform.android),
  '944x856': (Size(944, 856), TargetPlatform.android),
  '1104x884': (Size(1104, 884), TargetPlatform.android),
  '1180x820': (Size(1180, 820), TargetPlatform.android),
  '1440x900': (Size(1440, 900), TargetPlatform.linux),
};

/// What the rail and the channel sidebar take out of the window before the
/// side area sees it (measured on the full workspace at every size above:
/// rail 57, sidebar 240, see /mnt/data/tmp/cindy/fold-layout/before).
const _workspaceChrome = 297.0;

/// How a section opens and closes in the single-area rig. Null where its
/// open-ness does not exist there: [_fullWorkspace] covers those.
typedef _Toggle = void Function(_Rig rig, bool open);

class _Opener {
  const _Opener(this.toggle, {this.why});

  /// Null: the rig cannot open it, and [why].
  final _Toggle? toggle;
  final String? why;
}

final _openers = <ChannelSideSection, _Opener>{
  ChannelSideSection.tasks: _Opener(
    (rig, open) => ChannelSideStore.of(rig.w).setCardOpen(
      ChannelSideCard.tasks,
      open,
    ),
  ),
  ChannelSideSection.files: _Opener(
    (rig, open) => ChannelSideStore.of(rig.w).setCardOpen(
      ChannelSideCard.files,
      open,
    ),
  ),
  ChannelSideSection.details: _Opener((rig, open) {
    final details = ChannelDetailsStore.of(rig.w);
    if (open) {
      details.open(rig.w.channel!);
    } else {
      details.close();
    }
  }),
  ChannelSideSection.artifact: _Opener((rig, open) {
    final preview = WebPreviewStore.of(rig.w);
    if (open) {
      preview.open(
        const WebPreviewPage(
          url: 'https://example.com/a',
          conversationId: 'c1',
        ),
      );
    } else {
      preview.close();
    }
  }),
  ChannelSideSection.profile: _Opener(
    (rig, open) => rig.profile.value = open,
  ),
  ChannelSideSection.thread: const _Opener(
    null,
    why:
        'a thread is a column only where RaftAdaptiveWorkspace docks it in the '
        'side row (wide, pointer); folded it replaces the chat inside the '
        'conversation slot. Both are checked on the whole workspace.',
  ),
  ChannelSideSection.context: const _Opener(
    null,
    why:
        'nothing opens the context view yet: v1.24 has it in the saved layout '
        'only and _openChannelSide never puts it in the open set.',
  ),
};

/// The sections whose head is the real product head in the single-area rig.
/// The profile panel is the workspace's own widget, so its head is checked on
/// the whole workspace instead.
const _headsInRig = {
  ChannelSideSection.tasks,
  ChannelSideSection.files,
  ChannelSideSection.details,
  ChannelSideSection.artifact,
};

final _backArrow = find.byWidgetPredicate(
  (widget) => widget is RaftPanelAction && widget.glyph == RaftGlyph.arrowLeft,
  description: 'a back arrow',
);

class _Rig {
  _Rig(this.w, this.profile);
  final WorkspaceController w;
  final ValueNotifier<bool> profile;
}

/// Stands for the channel column: a header, the messages and the composer. Its
/// header is the width the chat content is actually laid out at, which is less
/// than its slot when the slot is below the chat's floor and the area clips it.
class _Chat extends StatelessWidget {
  const _Chat();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(key: Key('chat-header'), height: 56),
      Expanded(child: Container(key: const Key('chat-body'))),
    ],
  );
}

Future<_Rig> _pumpArea(
  WidgetTester t,
  Size size,
  TargetPlatform platform,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  addTearDown(DevicePreferences.reset);
  final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  transport.routes['PATCH /servers/s1/sidebar-order'] = (_) => {};
  transport.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
  transport.routes['GET /channels/c1/announcement'] = (_) => {
    'announcement': null,
  };
  transport.routes['GET /announcements/active'] = (_) => {'announcements': []};
  transport.routes['GET /channels/c1/members'] = (_) => {
    'humans': [],
    'agents': [],
  };
  transport.routes['GET /channels/c1/message-display-settings'] = (_) => {};
  transport.routes['GET /channels/c1/notification-settings'] = (_) => {};
  w.navigation.bind(
    'side-fit-guard',
    RaftLocation.at(serverSlug: 's1', route: RaftRoute.channel, entityId: 'c1'),
  );
  await t.runAsync(() async {
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  TaskV2ConversationsFlag.of(w).markEnabled();
  final profile = ValueNotifier(false);
  addTearDown(profile.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: Row(
          children: [
            // Stands for the rail and the channel sidebar: the area gets the
            // room the full workspace leaves it, while the layout class still
            // comes from the window.
            const SizedBox(width: _workspaceChrome),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: profile,
                builder: (context, open, _) => ChannelSideArea(
                  controller: w,
                  headerExtent: 56,
                  profile: open
                      ? const SizedBox.expand(key: Key('profile-pane'))
                      : null,
                  child: const _Chat(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await t.pump();
  return _Rig(w, profile);
}

/// Every open set the guard walks: each section on its own, then every ordered
/// pair, with the tick order the stack would have given them.
List<(String, Map<ChannelSideSection, int>)> _states(
  Iterable<ChannelSideSection> sections,
) => [
  for (final one in sections) (one.name, {one: 1}),
  for (final first in sections)
    for (final then in sections)
      if (first != then) ('${first.name} then ${then.name}', {
        first: 1,
        then: 2,
      }),
];

void _checkPlacement(
  ChannelSidePlacement placement, {
  required List<VisibleChannelSideColumn> visible,
  required double width,
  required RaftLayoutClass layout,
  required String where,
}) {
  expect(
    placement.columns.length + placement.stackedBelow,
    visible.length,
    reason: '$where: a pane went missing',
  );
  if (layout == RaftLayoutClass.medium) {
    expect(
      placement.mode,
      ChannelSideMode.overlay,
      reason: '$where: the medium class covers the conversation',
    );
  }
  if (placement.mode == ChannelSideMode.overlay) {
    expect(placement.columns, hasLength(1), reason: '$where: one pane covers');
    expect(
      placement.columns.single.width,
      width,
      reason: '$where: the cover takes the whole area',
    );
    return;
  }
  for (final column in placement.columns) {
    expect(
      column.width,
      greaterThanOrEqualTo(
        channelSideColumnMinWidth(column.sections).toDouble(),
      ),
      reason: '$where: ${column.sections} below its own minimum',
    );
  }
  final chat =
      width - placement.columns.fold(0.0, (sum, c) => sum + c.width);
  expect(
    chat,
    greaterThanOrEqualTo(channelSideChatMinWidth - .01),
    reason: '$where: the chat is below its floor',
  );
}

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking. The files
  // card's store is the debt every test that mounts the real Files body
  // carries (channel_side_drag_test, channel_side_toggles_test and four more).
  leakDebt(const ['SourceChannelFilesStore']);

  test('every side section is registered', () {
    expect(_openers.keys.toSet(), ChannelSideSection.values.toSet());
    for (final entry in _openers.entries) {
      expect(
        entry.value.toggle != null || entry.value.why != null,
        isTrue,
        reason: '${entry.key.name} needs an opener or a reason',
      );
    }
  });

  for (final size in _sizes.entries) {
    final (window, platform) = size.value;
    final layout = raftLayoutClassForWidth(window.width);

    test('${size.key} places every pane and pair inside its minimums', () {
      final complete = ChannelSideLayout.defaults.complete();
      for (final area in [window.width, window.width - _workspaceChrome]) {
        for (final (name, ticks) in _states(ChannelSideSection.values)) {
          for (final folded in [false, true]) {
            final open = ticks.keys.toSet();
            final visible = complete.visible(open);
            final placement = placeChannelSide(
              visible,
              width: area,
              compact: false,
              layout: layout,
              stack: ChannelSideStack(ticks),
              threadFolded: folded,
            );
            _checkPlacement(
              placement,
              visible: visible,
              width: area,
              layout: layout,
              where:
                  '${size.key} ($layout) in $area: $name'
                  '${folded ? ', thread folded' : ''}',
            );
          }
        }
      }
    });

    testWidgets('${size.key} renders every pane and pair inside its minimums', (
      t,
    ) async {
      final rig = await _pumpArea(t, window, platform);
      final openable = [
        for (final entry in _openers.entries)
          if (entry.value.toggle != null) entry.key,
      ];
      for (final (name, ticks) in _states(openable)) {
        final order = ticks.entries.toList()
          ..sort((a, b) => a.value - b.value);
        for (final entry in order) {
          _openers[entry.key]!.toggle!(rig, true);
          await t.pump();
        }
        await frames(t, 3);
        final where = '${size.key} ($layout): $name';
        final columns = find.byType(ChannelSideColumnView);
        final views = [
          for (final element in columns.evaluate())
            element.widget as ChannelSideColumnView,
        ];
        final covered = find.byKey(const Key('channel-side-overlay'));
        if (layout == RaftLayoutClass.medium) {
          expect(covered, findsOneWidget, reason: '$where: it must cover');
        }
        if (covered.evaluate().isNotEmpty) {
          expect(views, hasLength(1), reason: '$where: one pane covers');
          final shown = views.single.sections;
          if (shown.any(_headsInRig.contains)) {
            expect(
              find.descendant(of: covered, matching: _backArrow),
              findsWidgets,
              reason: '$where: the covering pane needs a back control',
            );
          }
        }
        for (final element in columns.evaluate()) {
          final view = element.widget as ChannelSideColumnView;
          final box = element.findRenderObject()! as RenderBox;
          expect(
            box.size.width,
            greaterThanOrEqualTo(
              channelSideColumnMinWidth(view.sections).toDouble() - .01,
            ),
            reason: '$where: ${view.sections} below its own minimum',
          );
        }
        final slot = t
            .getSize(find.byKey(const ValueKey('channel-side-conversation')))
            .width;
        if (covered.evaluate().isEmpty && views.isNotEmpty) {
          expect(
            slot,
            greaterThanOrEqualTo(channelSideChatMinWidth - .01),
            reason: '$where: the conversation slot is below the chat floor',
          );
        }
        expect(
          t.getSize(find.byKey(const Key('chat-header'))).width,
          closeTo(slot, .01),
          reason: '$where: the chat is clipped inside its slot',
        );
        for (final entry in order.reversed) {
          _openers[entry.key]!.toggle!(rig, false);
          await t.pump();
        }
        await frames(t, 2);
      }
    });
  }

  testWidgets(
    'a covering pane pops to the one underneath, then to the chat',
    (t) async {
      final (w, api) = await mountWorkspace(
        t,
        const Size(884, 1104),
        platform: TargetPlatform.android,
      );
      api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
      api.routes['GET /channels/c1/announcement'] = (_) => {
        'announcement': null,
      };
      api.routes['GET /announcements/active'] = (_) => {'announcements': []};
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      TaskV2ConversationsFlag.of(w).markEnabled();
      ChannelDetailsStore.of(w).open(w.channel!);
      await frames(t, 12);
      ChannelSideCards.toggle(w, ChannelSideCard.tasks);
      await frames(t, 12);
      // Tasks was opened last, so it covers; Details waits behind it.
      expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
      expect(find.byKey(const Key('channel-side-card-tasks')), findsOneWidget);
      expect(find.byKey(const Key('channel-details')), findsNothing);
      final tasksBack = find.byKey(const Key('channel-side-card-tasks-back'));
      expect(tasksBack.hitTestable(), findsOneWidget);
      await t.tap(tasksBack);
      await frames(t, 12);
      // Back popped Tasks only: Details, open all along, shows.
      expect(find.byKey(const Key('channel-details')), findsOneWidget);
      expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);
      final detailsBack = find.byKey(const Key('channel-overflow-back'));
      expect(detailsBack.hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('channel-details-close')), findsNothing);
      await t.tap(detailsBack);
      await frames(t, 12);
      expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
      expect(find.byKey(const Key('channel-details')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('a covering profile draws a back arrow, not a close', (t) async {
    final (w, api) = await mountWorkspace(
      t,
      const Size(884, 1104),
      platform: TargetPlatform.android,
    );
    api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
    api.routes['GET /channels/c1/announcement'] = (_) => {
      'announcement': null,
    };
    api.routes['GET /announcements/active'] = (_) => {'announcements': []};
    api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
      'userId': 'bob',
      'name': 'bob',
      'displayName': 'Bob',
      'role': 'member',
    };
    TaskV2ConversationsFlag.of(w).markEnabled();
    w.openProfile(RaftProfileKind.human, 'bob');
    await frames(t, 20);
    final panel = find.byKey(const Key('workspace-profile-panel'));
    expect(panel, findsOneWidget);
    expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
    expect(
      find.descendant(of: panel, matching: _backArrow),
      findsWidgets,
      reason: 'the covering profile needs a back control',
    );
    expect(
      find.descendant(
        of: panel,
        // `RaftPanelIconButton.glyph` defaults to the X, so the close is the
        // one with the close tooltip, not every button drawing an X.
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RaftPanelIconButton &&
              widget.tooltip == 'Close Profile',
        ),
      ),
      findsNothing,
      reason: 'and not its close X as well',
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('a folded thread keeps the whole conversation slot', (t) async {
    final (w, api) = await mountWorkspace(
      t,
      const Size(1104, 884),
      platform: TargetPlatform.android,
    );
    api.routes['GET /channels/c1/announcement'] = (_) => {
      'announcement': null,
    };
    api.routes['GET /announcements/active'] = (_) => {'announcements': []};
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
    };
    ChannelDetailsStore.of(w).open(w.channel!);
    await frames(t, 10);
    await t.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'mt',
        initialThreadChannelId: 't1',
      ),
    );
    await frames(t, 20);
    final slot = t.getRect(
      find.byKey(const ValueKey('channel-side-conversation')),
    );
    // Folded, the thread is laid out inside the conversation slot in place of
    // the chat, so the slot needs one chat of room and not two.
    final thread = t.getRect(find.byType(RaftThreadPlacement));
    expect(slot.width, greaterThanOrEqualTo(channelSideChatMinWidth));
    expect(thread.width, closeTo(slot.width, .01));
    final details = t.getSize(
      find.byKey(const Key('channel-side-column-3')),
    );
    // Details keeps its own saved width instead of giving way to room the
    // folded thread never used (320 before, its bare minimum).
    expect(details.width, 400);
    expect(t.takeException(), isNull);
  });
}
