import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/system_notification_center.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_popups.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

const hostKey = Key('popup-host-page');

/// Wide layouts run with a pointer (hover toolbars, desktop density); a phone
/// runs Android.
TargetPlatform platformFor(Size size) =>
    size.width >= 768 ? TargetPlatform.macOS : TargetPlatform.android;

/// A small app: a root page, and on top of it a host page holding [body], so a
/// wrongly popped page (system Back) is observable: [hostAlive].
Future<void> mountHost(
  WidgetTester t,
  Size size,
  Widget Function(BuildContext) body,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final nav = GlobalKey<NavigatorState>();
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    MaterialApp(
      navigatorKey: nav,
      theme: raftTheme(
        RaftFamily.elegant,
      ).copyWith(platform: platformFor(size)),
      home: const Scaffold(body: Text('root-page')),
    ),
  );
  nav.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        key: hostKey,
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Builder(builder: body),
          ),
        ),
      ),
    ),
  );
  await frames(t, 20);
}

bool hostAlive() => find.byKey(hostKey).evaluate().isNotEmpty;

/// True while [open] holds. The closing popup must not take its host down with
/// it (Escape or system Back reaching the page under a popup): once [alive]
/// fails the probe throws instead of reporting "closed".
bool Function() guarded(bool Function() open, bool Function() alive) => () {
  if (!alive()) fail('the host page closed together with the popup');
  return open();
};

/// Open while [popup] is on screen; the host page must survive.
bool Function() openWhile(Finder popup) =>
    guarded(() => popup.evaluate().isNotEmpty, hostAlive);

/// A point well away from the popup, on the host page.
Offset farPoint(Size size) => Offset(size.width - 10, size.height - 10);

/// The workspace shell: the Home list on a phone, the sidebar layout otherwise.
///
/// [chat] mounts the open channel (c1) on a phone too.
Future<WorkspaceController> mountShell(
  WidgetTester t,
  Size size, {
  bool chat = false,
}) async {
  // Each affordance reopens the surface fresh: drop the previous tree first.
  await t.pumpWidget(const SizedBox.shrink());
  final (w, _) = await mountWorkspace(
    t,
    size,
    section: size.width < 768 && !chat ? 'home' : 'chat',
    platform: platformFor(size),
  );
  return w;
}

Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));

/// Long press on a phone, right click with a pointer.
Future<void> openRowMenu(WidgetTester t, Size size, Finder target) async {
  if (size.width < 768) {
    await t.longPress(target);
  } else {
    await t.tapAt(
      t.getCenter(target),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
  }
  await frames(t, 20);
}

Offset corner(Size size) => Offset(size.width - 6, size.height - 6);

Future<void> openThreadPanel(WidgetTester t, WorkspaceController w) async {
  await t.runAsync(
    () => w.messageDomain.threads.openThread(
      RaftMessage(closeRows().firstWhere((r) => r['id'] == 'mt')),
    ),
  );
  await frames(t, 30);
}

Widget runtimeUsageChip(BuildContext context) => RaftRuntimeUsageChip(
  label: 'Claude usage',
  chip: const Text('Claude'),
  data: const RaftRuntimeUsageData(
    provider: 'Claude',
    state: 'fresh',
    footer: 'Cached snapshot only',
  ),
  onOpen: () {},
  onRefresh: () {},
  onOpenSheet: (chipContext) => showRaftRuntimeUsageSheet(
    chipContext,
    listenable: ValueNotifier(0),
    data: (_) => const RaftRuntimeUsageData(
      provider: 'Claude',
      state: 'fresh',
      footer: 'Cached snapshot only',
    ),
    onRefresh: () {},
  ),
);

TestGesture? pointer;

/// Rests the mouse pointer on [target] and lets the hover delay pass.
Future<void> hover(WidgetTester t, Finder target) async {
  final mouse = pointer ??= await t.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  if (!pointerAdded) await mouse.addPointer(location: Offset.zero);
  pointerAdded = true;
  await mouse.moveTo(Offset.zero);
  await t.pump();
  await mouse.moveTo(t.getCenter(target));
  await frames(t, 30);
}

bool pointerAdded = false;

void main() {
  setUp(() {
    pointer = null;
    pointerAdded = false;
  });
  final harness = <String, OpenSurface>{
    'select-field': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => SizedBox(
          width: 200,
          child: RaftSelectField<String>(
            value: 'a',
            label: 'Pick one',
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Alpha')),
              DropdownMenuItem(value: 'b', child: Text('Beta option')),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Alpha'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Beta option')),
        scrim: farPoint(size),
      );
    },
    'dropdown-menu': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftDropdownMenu(
          label: 'Actions',
          entries: [
            RaftMenuEntry(label: 'Copy thing', onPressed: () {}),
            RaftMenuEntry(label: 'Delete thing', onPressed: () {}),
          ],
        ),
      );
      await t.tap(find.text('Actions'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Delete thing')),
        scrim: farPoint(size),
      );
    },
    'sidebar-context-menu': (t, size) async {
      await mountShell(t, size);
      await openRowMenu(t, size, row('c1'));
      return SurfaceProbe(
        isOpen: () => find.byType(RaftSidebarContextMenu).evaluate().isNotEmpty,
        scrim: Offset(size.width - 6, size.height - 6),
      );
    },
    'sidebar-sort-menu': (t, size) async {
      await mountShell(t, size);
      await t.tap(
        find.byKey(const ValueKey('sidebar-sort-system:channels')).first,
      );
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () =>
            find.byKey(const Key('sidebar-sort-popover')).evaluate().isNotEmpty,
        scrim: Offset(size.width - 6, size.height - 6),
      );
    },
    'server-switcher': (t, size) async {
      await mountShell(t, size);
      await t.tap(
        find
            .byKey(
              size.width < 768
                  ? const Key('mobile-server-selector')
                  : const Key('rail-workspace'),
            )
            .first,
      );
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () => find.byType(RaftServerMenuPanel).evaluate().isNotEmpty,
        scrim: Offset(size.width - 6, size.height - 6),
      );
    },
    'notification-center': (t, size) async {
      await mountShell(t, size);
      await t.tap(
        size.width < 768
            ? find.byType(RaftMobileNotificationButton).first
            : find.byType(SystemNotificationBell).first,
      );
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () => find.byType(RaftNotificationCenter).evaluate().isNotEmpty,
        scrim: Offset(size.width / 2, size.height - 6),
      );
    },
    'thread-menu': (t, size) async {
      final w = await mountShell(t, size, chat: true);
      await openThreadPanel(t, w);
      await t.tap(find.byKey(const Key('thread-options')).first);
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: guarded(
          () => find
              .byKey(const Key('thread-follow-menu-item'))
              .evaluate()
              .isNotEmpty,
          () => w.location.thread != null,
        ),
        scrim: Offset(6, size.height - 6),
      );
    },
    'message-context-menu': (t, size) async {
      await mountShell(t, size, chat: true);
      final target = find.byKey(const ValueKey('message-mh')).first;
      await openRowMenu(t, size, target);
      return SurfaceProbe(
        isOpen: () => find.byType(RaftMessageContextMenu).evaluate().isNotEmpty,
        scrim: Offset(6, size.height - 6),
      );
    },
    'toast': (t, size) async {
      final toast = RaftToastController();
      addTearDown(toast.dispose);
      await mountHost(
        t,
        size,
        (_) => Column(
          children: [
            RaftToastPortal(controller: toast),
            RaftButton(
              label: 'Show toast',
              onPressed: () => toast.show('Saved the thing'),
            ),
          ],
        ),
      );
      await t.tap(find.text('Show toast'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Saved the thing')),
        x: find.byKey(const Key('toast-close')),
      );
    },
    'snackbar': (t, size) async {
      await mountHost(
        t,
        size,
        (context) => RaftButton(
          label: 'Show snack',
          onPressed: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Download failed'))),
        ),
      );
      await t.tap(find.text('Show snack'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Download failed')),
        x: find.byTooltip('Close'),
      );
    },
    'reaction-picker': (t, size) async {
      final w = await mountShell(t, size, chat: true);
      final rows = [
        chatRow('mr', 3, {
          'senderId': 'bob',
          'senderType': 'user',
          'senderName': 'Bob',
          'content': 'reacted row',
          'reactions': [
            {
              'emoji': '\u{1F44D}',
              'count': 1,
              'reactorIds': ['u2'],
              'reactorNames': ['Dana'],
            },
          ],
        }),
      ];
      w.messageDomain.ledger.ingest(rows, expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {...?w.messageDomain.visibleIds['c1'], 'mr'};
      w.notifyListeners();
      await frames(t, 20);
      if (size.width < 768) {
        await t.tap(find.byKey(const ValueKey('message-reaction-add')).first);
      } else {
        // The hover toolbar's Add reaction button.
        final mouse = pointer ??= await t.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        if (!pointerAdded) await mouse.addPointer(location: Offset.zero);
        pointerAdded = true;
        await mouse.moveTo(
          t.getCenter(find.byKey(const ValueKey('message-mr'))),
        );
        await frames(t, 10);
        await t.tap(find.byKey(const ValueKey('message-react-mr')));
      }
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: () =>
            find.byType(RaftQuickReactionPicker).evaluate().isNotEmpty,
        scrim: Offset(6, size.height - 6),
      );
    },
    'thread-followers': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftThreadFollowers(
          triggerLabel: '1 Agent following',
          avatars: const [SizedBox.square(dimension: 20)],
          count: 1,
          error: false,
          body: RaftFollowersBody.list,
          rows: const [
            RaftFollowerRow(
              id: 'a1',
              label: 'Cindy',
              avatar: SizedBox.square(dimension: 20),
              secondary: 'idle',
            ),
          ],
          onRetry: () {},
        ),
      );
      await t.tap(find.byKey(const Key('thread-followers-header-trigger')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.byKey(const Key('thread-followers-popover'))),
        scrim: farPoint(size),
      );
    },
    'inline-badge-editor': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftInlineBadgeEditor(
          label: 'Open',
          selectedId: 'open',
          options: const [
            RaftInlineBadgeOption(id: 'open', label: 'Open'),
            RaftInlineBadgeOption(id: 'done', label: 'Finished'),
          ],
          onSelect: (_) {},
          background: Colors.blue.shade100,
          foreground: Colors.blue.shade900,
        ),
      );
      await t.tap(find.text('Open'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Finished')),
        scrim: farPoint(size),
      );
    },
    'agent-overflow-menu': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftOverflowMenuButton(
          tooltip: 'More actions',
          entries: [
            RaftMenuEntry(label: 'Rename agent', onPressed: () {}),
            RaftMenuEntry(label: 'Delete agent', onPressed: () {}),
          ],
        ),
      );
      await t.tap(find.byType(RaftOverflowMenuButton));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Delete agent')),
        scrim: farPoint(size),
      );
    },
    'admin-principal-picker': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => SizedBox(
          width: 260,
          child: RaftAdminPrincipalPicker(
            candidates: const [
              RaftAdminPrincipal(key: 'human:bob', label: 'Bob', agent: false),
              RaftAdminPrincipal(key: 'agent:a1', label: 'Cindy', agent: true),
            ],
            selectedKey: null,
            onSelect: (_) {},
          ),
        ),
      );
      await t.tap(find.byType(RaftAdminPrincipalPicker));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(
          find.byKey(const ValueKey('admin-principal-popover')),
        ),
        scrim: farPoint(size),
      );
    },
    'agent-select': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => SizedBox(
          width: 220,
          child: RaftAgentSelect<String>(
            value: 'a',
            semanticLabel: 'Runtime',
            options: const [
              RaftAgentSelectOption('a', 'Claude'),
              RaftAgentSelectOption('b', 'Codex option'),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      await t.tap(find.text('Claude'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Codex option')),
        scrim: farPoint(size),
      );
    },
    'feedback-close-menu': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftFeedbackCloseSplit(
          defaultReason: RaftFeedbackCloseReason.completed,
          onChoose: (_) {},
        ),
      );
      await t.tap(find.byKey(const Key('feedback-close-caret')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.byType(RaftFeedbackCloseMenu)),
        scrim: farPoint(size),
      );
    },
    'runtime-usage-card': (t, size) async {
      await mountHost(t, size, runtimeUsageChip);
      await t.tap(find.text('Claude'));
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: openWhile(find.byKey(const ValueKey('runtime-usage-card'))),
        x: find.byType(RaftCloseButton),
        scrim: farPoint(size),
      );
    },
    'section-emoji-picker': (t, size) async {
      await mountHost(
        t,
        size,
        (context) => RaftButton(
          label: 'New section',
          onPressed: () => showRaftSidebarSectionDialog(
            context,
            title: 'New section',
            submitLabel: 'Create',
            onSubmit: (_, _) {},
          ),
        ),
      );
      await t.tap(find.text('New section'));
      await frames(t, 15);
      await t.tap(find.byKey(sectionEmojiButtonKey));
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: guarded(
          () => find.byType(RaftEmojiPicker).evaluate().isNotEmpty,
          () => find.byType(RaftSidebarSectionDialog).evaluate().isNotEmpty,
        ),
        scrim: Offset(6, size.height - 6),
      );
    },
    'composer-suggestions': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => SizedBox(
          width: size.width - 80,
          child: RaftComposer(
            suggestions: const [
              RaftComposerSuggestion(
                type: 'channel',
                id: 'design',
                name: 'design',
                detail: 'Product and UI decisions',
              ),
            ],
            onSend: (_) async => true,
          ),
        ),
      );
      await t.enterText(find.byType(EditableText), '#des');
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Product and UI decisions')),
        scrim: farPoint(size),
      );
    },
    'rail-help-menu': (t, size) async {
      await mountShell(t, size);
      await t.tap(find.byKey(const Key('rail-help')));
      await frames(t, 20);
      return SurfaceProbe(
        isOpen: guarded(
          () => find.byType(RaftMenuPanel).evaluate().isNotEmpty,
          () => find.byType(WorkspaceView).evaluate().isNotEmpty,
        ),
        scrim: corner(size),
      );
    },
    'tooltip': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => const RaftTooltip(
          message: 'Explains the thing',
          child: SizedBox(width: 80, height: 32, child: Text('Hover me')),
        ),
      );
      await hover(t, find.text('Hover me'));
      return SurfaceProbe(isOpen: openWhile(find.text('Explains the thing')));
    },
    'hover-card': (t, size) async {
      await mountHost(
        t,
        size,
        (_) => RaftHoverCard(
          delay: Duration.zero,
          card: (_) => const Text('Card detail'),
          child: const SizedBox(
            width: 80,
            height: 32,
            child: Text('Hover card'),
          ),
        ),
      );
      await hover(t, find.text('Hover card'));
      return SurfaceProbe(
        isOpen: openWhile(find.text('Card detail')),
        scrim: farPoint(size),
      );
    },
  };
  registerCloseTests(popupSurfaces, harness);
}
