// Escape on the panes beside a conversation acts on the pane the person can
// see and on no other.
//
// Before PR #733's review round `dismissPanel` read `w.location.profile` and
// `w.location.thread` straight off the location, so with a card opened on top
// of a Profile or a Thread, Escape silently closed the hidden pane underneath
// while the card the person was looking at stayed where it was.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart'
    show frames, mountWorkspace, pressEscape, tapAndSettle;

/// A medium window (the pane covers the conversation) and a wide one (the
/// panes stand beside it). Touch on the foldable, a mouse on the desktop.
const _medium = Size(841, 701);
const _wide = Size(1104, 884);

Future<WorkspaceController> _open(WidgetTester t, Size size) async {
  final (w, api) = await mountWorkspace(
    t,
    size,
    platform: size == _wide ? TargetPlatform.linux : TargetPlatform.android,
  );
  api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
  api.routes['GET /channels/c1/announcement'] = (_) => {'announcement': null};
  api.routes['GET /announcements/active'] = (_) => {'announcements': []};
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
  api.routes['GET /channels/c1/notification-settings'] = (_) => {};
  api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
    'userId': 'bob',
    'name': 'bob',
    'displayName': 'Bob',
    'role': 'member',
  };
  TaskV2ConversationsFlag.of(w).markEnabled();
  await frames(t, 12);
  return w;
}

/// The thread panel is open: its `?thread=` query, which is what the panel
/// slot is derived from (`DesktopNavigationPolicy.sidePanels`).
bool _threadOpen(WorkspaceController w) => w.location.thread != null;

final _tasks = find.byKey(const Key('channel-side-card-tasks'));
final _profile = find.byKey(const Key('workspace-profile-panel'));

void main() {
  for (final (name, size) in [('841x701', _medium), ('1104x884', _wide)]) {
    testWidgets('$name: Escape leaves a Profile under a card where it is', (
      t,
    ) async {
      final w = await _open(t, size);
      w.openProfile(RaftProfileKind.human, 'bob');
      await frames(t, 20);
      expect(_profile, findsOneWidget);
      ChannelSideCards.toggle(w, ChannelSideCard.tasks);
      await frames(t, 20);
      // Tasks opened last, so it is the pane on top and the profile waits
      // behind it: at this width the two do not fit beside the chat together.
      expect(_tasks, findsOneWidget);
      expect(_profile, findsNothing);
      await pressEscape(t);
      expect(
        w.location.profile,
        isNotNull,
        reason: 'Escape closed the profile hidden behind Tasks',
      );
      expect(_tasks, findsOneWidget, reason: 'and left Tasks untouched');
      // Back on Tasks is what pops it, and the profile is still there.
      await tapAndSettle(
        t,
        find.byKey(const Key('channel-side-card-tasks-back')),
      );
      expect(_profile, findsOneWidget);
      // Now that the profile is the pane on top, Escape closes it.
      await pressEscape(t);
      expect(w.location.profile, isNull);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('841x701: Escape closes the pane over a folded Thread, not it', (
    t,
  ) async {
    final w = await _open(t, _medium);
    await t.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'mt',
        initialThreadChannelId: 't1',
      ),
    );
    await frames(t, 20);
    expect(find.byType(RaftThreadPlacement), findsOneWidget);
    expect(_threadOpen(w), isTrue, reason: 'the thread did not open');
    ChannelDetailsStore.of(w).open(w.channel!);
    await frames(t, 20);
    // Details covers the conversation column, the folded thread included.
    expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
    // Details is the pane on screen and it closes on Escape; the thread under
    // it stays.
    await pressEscape(t);
    expect(
      _threadOpen(w),
      isTrue,
      reason: 'Escape closed the thread hidden under the Details pane',
    );
    expect(ChannelDetailsStore.of(w).channel, isNull);
    expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
    // Nothing covers the thread now, so the next Escape closes it.
    await pressEscape(t);
    expect(_threadOpen(w), isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('841x701: Escape leaves a folded Thread under a card alone', (
    t,
  ) async {
    final w = await _open(t, _medium);
    await t.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'mt',
        initialThreadChannelId: 't1',
      ),
    );
    await frames(t, 20);
    ChannelSideCards.toggle(w, ChannelSideCard.tasks);
    await frames(t, 20);
    expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
    // Tasks has no Escape of its own, and Escape does not reach past it.
    await pressEscape(t);
    expect(
      _threadOpen(w),
      isTrue,
      reason: 'Escape closed the thread hidden under the Tasks card',
    );
    expect(_tasks, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('1104x884: Escape closes the Thread it stands beside', (t) async {
    final w = await _open(t, _wide);
    await t.runAsync(
      () => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'mt',
        initialThreadChannelId: 't1',
      ),
    );
    await frames(t, 20);
    ChannelSideCards.toggle(w, ChannelSideCard.tasks);
    await frames(t, 20);
    // Tasks stands beside the conversation and the thread folds into it, so
    // both are on screen; Escape still belongs to the thread panel (Web
    // ThreadPanel Esc) and Tasks keeps its card.
    expect(_tasks, findsOneWidget);
    expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
    await pressEscape(t);
    expect(_threadOpen(w), isFalse);
    expect(_tasks, findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
