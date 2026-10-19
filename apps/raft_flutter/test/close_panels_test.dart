import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_panels.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

Finder inPanel(Finder panel, String tooltip) =>
    find.descendant(of: panel, matching: find.byTooltip(tooltip));

Future<WorkspaceController> mountAt(
  WidgetTester t,
  Size size, [
  String? uri,
]) async {
  final (w, _) = await mountWorkspace(t, size);
  if (uri != null) {
    w.navigation.navigate(RaftLocation.parse(uri));
    w.notifyListeners();
    await frames(t, 25);
  }
  return w;
}

Offset outsideProfile(WidgetTester t, Size size) {
  final panel = t.getRect(find.byKey(const Key('profile-panel')));
  return Offset(panel.left / 2 + size.width * .15, size.height * .55);
}

void main() {
  final harness = <String, OpenSurface>{
    'profile-human': (t, size) async {
      final w = await mountAt(t, size);
      w.openProfile(RaftProfileKind.human, 'bob');
      await frames(t, 25);
      final panel = find.byKey(const Key('profile-panel'));
      return SurfaceProbe(
        isOpen: () => panel.evaluate().isNotEmpty,
        x: inPanel(panel, 'Close profile'),
        back: inPanel(panel, 'Back'),
        scrim: size.width >= 768 ? outsideProfile(t, size) : null,
      );
    },
    'profile-agent': (t, size) async {
      final w = await mountAt(t, size);
      w.openProfile(RaftProfileKind.agent, 'a1');
      await frames(t, 25);
      final panel = find.byKey(const Key('profile-panel'));
      return SurfaceProbe(
        isOpen: () => panel.evaluate().isNotEmpty,
        x: inPanel(panel, 'Close profile'),
        back: inPanel(panel, 'Back'),
        scrim: size.width >= 768 ? outsideProfile(t, size) : null,
      );
    },
    'profile-external': (t, size) async {
      final w = await mountAt(t, size);
      w.openProfile(
        RaftProfileKind.external,
        'mh',
        channelId: 'c1',
        externalAuthor: {
          'displayName': 'Ada Lovelace',
          'provider': 'slack',
          'actorKind': 'human',
          'workspaceName': 'Acme',
        },
      );
      await frames(t, 25);
      final panel = find.byKey(const Key('profile-panel'));
      return SurfaceProbe(
        isOpen: () => panel.evaluate().isNotEmpty,
        x: inPanel(panel, 'Close'),
        back: inPanel(panel, 'Back'),
        scrim: size.width >= 768 ? outsideProfile(t, size) : null,
      );
    },
    'thread-panel': (t, size) async {
      final w = await mountAt(t, size);
      await t.runAsync(
        () => w.messageDomain.threads.openThread(
          RaftMessage(closeRows().firstWhere((r) => r['id'] == 'mt')),
        ),
      );
      await frames(t, 30);
      return SurfaceProbe(
        isOpen: () => w.location.thread != null,
        x: find.byKey(const Key('thread-close')),
        back: find.byKey(
          size.width < 768
              ? const Key('mobile-detail-back')
              : const Key('thread-back'),
        ),
      );
    },
    'channel-settings': (t, size) async {
      final w = await mountAt(
        t,
        size,
        size.width < 768 ? '/s/demo/channel/c1?channelPage=settings:c1' : null,
      );
      if (size.width >= 768) {
        // Wide layouts open the drawer route (ChannelSettings.show).
        unawaited(
          ChannelSettings.show(
            t.element(find.byType(WorkspaceView)),
            controller: w,
            channel: w.channels.first,
          ),
        );
        await frames(t, 25);
      }
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const Key('channel-overflow-sheet'))
            .evaluate()
            .isNotEmpty,
        back: find.byKey(const Key('channel-overflow-back')),
        scrim: const Offset(20, 400),
      );
    },
    'channel-members-page': (t, size) async {
      await mountAt(t, size, '/s/demo/channel/c1?channelPage=members:c1');
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const Key('channel-overflow-sheet'))
            .evaluate()
            .isNotEmpty,
        back: find.byKey(const Key('member-page-back')),
      );
    },
    'channel-members-dialog': (t, size) async {
      final w = await mountAt(t, size);
      unawaited(
        ChannelMembers.show(
          t.element(find.byType(WorkspaceView)),
          controller: w,
          channel: w.channels.first,
        ),
      );
      await frames(t, 25);
      return SurfaceProbe(
        isOpen: () => find.byType(ChannelMembers).evaluate().isNotEmpty,
        x: find.byType(RaftCloseButton),
      );
    },
    'directory-human-detail': (t, size) async {
      final w = await mountAt(t, size, '/s/demo/human/bob');
      return SurfaceProbe(
        isOpen: () => w.location.route == RaftRoute.human,
        back: find.byTooltip('Back'),
      );
    },
    'member-graph-page': (t, size) async {
      final w = await mountAt(t, size, '/s/demo/members/graph');
      return SurfaceProbe(
        isOpen: () => w.location.route == RaftRoute.memberGraph,
        back: find.byKey(const ValueKey('member-graph-mobile-back')),
      );
    },
    'search-agent-slot': (t, size) async {
      final w = await mountAt(t, size, '/s/demo/search?open=agent:a1');
      return SurfaceProbe(
        isOpen: () => w.location.content != null,
        back: find.byTooltip('Back'),
      );
    },
    'search-human-slot': (t, size) async {
      final w = await mountAt(t, size, '/s/demo/search?open=human:bob');
      return SurfaceProbe(
        isOpen: () => w.location.content != null,
        back: find.byTooltip('Back'),
      );
    },
  };
  registerCloseTests(panelSurfaces, harness);

  // Web OverflowSheet `swipeDirection="right"`: a fling to the right closes
  // the wide channel drawer (touch).
  for (final (name, size) in closeSizes.skip(1)) {
    testWidgets('channel-settings @ $name closes on a swipe to the right', (
      t,
    ) async {
      final probe = await harness['channel-settings']!(t, size);
      expect(probe.isOpen(), isTrue);
      // From the header row: the body holds horizontally scrolling strips.
      final sheet = find.byKey(const Key('channel-overflow-sheet'));
      await t.flingFrom(
        t.getTopLeft(sheet) + const Offset(120, 30),
        const Offset(200, 0),
        3000,
      );
      await frames(t, 20);
      expect(probe.isOpen(), isFalse);
    });
  }
}
