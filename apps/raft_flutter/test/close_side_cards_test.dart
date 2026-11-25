import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/workspace_channel_header.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show fixture;
import 'support/close_registry_side_cards.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// A Tasks card beside the chat: its X on a wide layout; covering the chat on a
/// phone, the channel header's Back and the system Back close it. Escape does
/// not (Web passes no closeOnEscape).
void main() {
  leakDebt(const []);
  registerCloseTests(sideCardSurfaces, <String, OpenSurface>{
    'channel-side-card': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      DevicePreferences.reset();
      SharedPreferences.setMockInitialValues({});
      await t.runAsync(() async {
        DevicePreferences.adopt(await SharedPreferences.getInstance());
      });
      addTearDown(DevicePreferences.reset);
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.navigation.bind(
        'close-side-cards',
        RaftLocation.at(
          serverSlug: 's1',
          route: RaftRoute.channel,
          entityId: 'c1',
        ),
      );
      await t.runAsync(() async {
        ChannelSideFlags.of(w);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      TaskV2ConversationsFlag.of(w).markEnabled();
      final phone = size.width < 768;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Column(
              children: [
                WorkspaceChannelHeader(
                  headerKey: const Key('header'),
                  controller: w,
                  channel: w.channel!,
                  backLabel: 'Back',
                  backKey: const Key('side-back'),
                  onBack: phone ? () {} : null,
                  onSearch: () {},
                  onSettings: () {},
                ),
                Expanded(
                  child: ChannelSideArea(
                    controller: w,
                    bodyOf: (context, section) => const SizedBox.expand(),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      ChannelSideStore.of(w).setCardOpen(ChannelSideCard.tasks, true);
      await t.pump();
      await t.pump();
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const Key('channel-side-card-tasks'))
            .evaluate()
            .isNotEmpty,
        x: find.byKey(const Key('channel-side-card-tasks-close')),
        // On a phone the channel header's Back closes the covering card; off
        // it, the card draws its own.
        back: find.byKey(
          Key(phone ? 'side-back' : 'channel-side-card-tasks-back'),
        ),
      );
    },
    'channel-profile-column-move': (t, size) async {
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(
        t,
        size,
        platform: closePlatform(size),
      );
      TaskV2ConversationsFlag.of(w).markEnabled();
      ChannelSideCards.toggle(w, ChannelSideCard.tasks);
      w.openProfile(RaftProfileKind.human, 'bob');
      await frames(t, 25);
      await tapAndSettle(t, find.byKey(const Key('channel-profile-move')));
      final move = find.text('Move left');
      return SurfaceProbe(
        isOpen: () => move.evaluate().isNotEmpty,
        scrim: Offset(size.width * .4, size.height * .8),
      );
    },
    'channel-thread-column-move': (t, size) async {
      await t.pumpWidget(const SizedBox.shrink());
      final (w, _) = await mountWorkspace(
        t,
        size,
        platform: closePlatform(size),
      );
      final sidebarSeam = find.byKey(const Key('sidebar-resize-handle'));
      await t.drag(sidebarSeam, const Offset(-85, 0));
      await frames(t);
      ChannelDetailsStore.of(w).open(w.channel!);
      await t.runAsync(
        () => w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'mt',
          initialThreadChannelId: 't1',
        ),
      );
      await frames(t, 25);
      await tapAndSettle(t, find.byKey(const Key('channel-thread-move')));
      final move = find.text('Move right');
      return SurfaceProbe(
        isOpen: () => move.evaluate().isNotEmpty,
        scrim: Offset(size.width * .4, size.height * .8),
      );
    },
  });
}
