// What a covering pane covers. The medium class (768-1023: a foldable inner
// screen, a narrow desktop window) puts the pane over the conversation, and
// the pane carries the only Back on screen:
//   - it covers the whole conversation column, the channel header included,
//     so no strip of header buttons shows above it (they would be dead: the
//     conversation is inert under a cover);
//   - a folded thread stands in the chat's place, so it goes away with the
//     chat: one Back, nothing of the thread to click, nothing of it in the
//     Tab order, and its rows know they are covered.
//
// Before PR #733's review round the cover started at `headerExtent` (56), so
// `# test` and its lit Tasks/Files toggles showed above `← Details`, and a
// folded thread kept its own live `← Thread` head above it (two Backs).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show frames, mountWorkspace;

/// The two foldable inner screens the screen-class rule names (AGENTS.md,
/// Kevin 2026-11-25). Both are medium, both are touched.
const _sizes = <String, Size>{
  '841x701': Size(841, 701),
  '884x1104': Size(884, 1104),
};

/// Every Back control on screen, by the key every head gives its own
/// (`*-back`). The same predicate the geometry renderer counts `backArrows`
/// with, so a count here is the count in the evidence table.
final _backs = find.byWidgetPredicate(
  (widget) => widget.key is Key && '${widget.key}'.contains('-back'),
  description: 'a Back control',
);

/// The covering pane is the whole conversation column, so nothing of the
/// column shows above it whatever the column has at its top.
Rect _coversTheColumn(WidgetTester t) {
  final cover = find.byKey(const Key('channel-side-overlay'));
  expect(cover, findsOneWidget);
  final box = t.getRect(cover);
  expect(
    box,
    t.getRect(find.byKey(const ValueKey('channel-side-conversation'))),
  );
  return box;
}

/// The channel header is still mounted under the cover (the chat is not
/// rebuilt) and entirely behind it, so no button of it is on screen to press.
void _headerIsBehind(WidgetTester t, Rect cover) {
  final header = find.byKey(const Key('workspace-channel-header'));
  expect(header, findsOneWidget);
  expect(t.getRect(header).top, greaterThanOrEqualTo(cover.top));
}

/// Whether [context] is inside [ancestor].
bool _under(Element ancestor, BuildContext? context) {
  if (context == null) return false;
  var found = false;
  context.visitAncestorElements((element) {
    if (element != ancestor) return true;
    found = true;
    return false;
  });
  return found;
}

Future<WorkspaceController> _open(WidgetTester t, Size size) async {
  final (w, api) = await mountWorkspace(
    t,
    size,
    platform: TargetPlatform.android,
  );
  api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
  api.routes['GET /channels/c1/announcement'] = (_) => {'announcement': null};
  api.routes['GET /announcements/active'] = (_) => {'announcements': []};
  api.routes['GET /channels/c1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {};
  api.routes['GET /channels/c1/notification-settings'] = (_) => {};
  TaskV2ConversationsFlag.of(w).markEnabled();
  await frames(t, 12);
  return w;
}

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('$name: the cover takes the channel header with it', (t) async {
      final w = await _open(t, size);
      ChannelDetailsStore.of(w).open(w.channel!);
      await frames(t, 12);
      _headerIsBehind(t, _coversTheColumn(t));
      // Why it must not show: the conversation is inert under a cover, so a
      // strip of header buttons above it reads as live and answers nothing.
      expect(
        find.byKey(const Key('channel-tasks-toggle')).hitTestable(),
        findsNothing,
      );
      // One Back: the pane's own.
      expect(_backs.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('channel-overflow-back')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('$name: a card over Details still leaves one Back', (t) async {
      final w = await _open(t, size);
      ChannelDetailsStore.of(w).open(w.channel!);
      await frames(t, 8);
      ChannelSideCards.toggle(w, ChannelSideCard.tasks);
      await frames(t, 12);
      expect(find.byKey(const Key('channel-side-card-tasks')), findsOneWidget);
      _headerIsBehind(t, _coversTheColumn(t));
      expect(_backs.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('channel-side-card-tasks-back')).hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('$name: a folded thread under the cover answers nothing', (
      t,
    ) async {
      final w = await _open(t, size);
      ChannelDetailsStore.of(w).open(w.channel!);
      await frames(t, 8);
      await t.runAsync(
        () => w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'mt',
          initialThreadChannelId: 't1',
        ),
      );
      await frames(t, 20);
      // The thread folded into the conversation slot and Details covers it.
      final thread = find.byType(RaftThreadPlacement);
      expect(thread, findsOneWidget);
      // One Back on screen, the covering pane's: not the thread's as well.
      expect(_backs.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('channel-overflow-back')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread-back')).hitTestable(),
        findsNothing,
        reason: 'the thread kept a live Back of its own above the cover',
      );
      expect(
        find.byKey(const Key('thread-header-channel-link')).hitTestable(),
        findsNothing,
      );
      // Nothing of it is in the Tab order.
      final slot = t.element(thread);
      expect(
        FocusManager.instance.rootScope.traversalDescendants
            .where((node) => _under(slot, node.context))
            .toList(),
        isEmpty,
        reason: 'a covered pane must not be reachable by Tab',
      );
      // And its rows know they are covered, so an open hover toolbar (it
      // floats in the route overlay, above the cover) puts itself away.
      expect(
        RaftCoveredPane.of(
          t.element(find.byKey(const Key('workspace-thread-header'))),
        ),
        isTrue,
      );
      // The chat is not built while the thread stands in its place, so the
      // channel header is not on screen either way; what matters here is that
      // the cover is still the whole column.
      _coversTheColumn(t);
    });
  }
}
