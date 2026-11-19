import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/external_invite_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX, openFromButton;
import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;
import 'support/close_registry_sidebar_v124.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  registerCloseTests(sidebarV124Surfaces, {
    for (final surface in sidebarV124Surfaces)
      surface.id: (tester, size) async {
        if (surface.id == 'sidebar-channel-leave-confirmation') {
          final (workspace, _) = await pageFixture(tester);
          workspace
            ..mobileNavigation = size.width < 600
            ..channel = null
            ..section = 'home'
            ..channels = [
              RaftChannel({
                'id': 'planning',
                'name': 'Planning',
                'joined': true,
              }),
            ];
          await mountPage(
            tester,
            workspace,
            false,
            width: size.width,
            height: size.height,
          );
          final row = find.byKey(const ValueKey('sidebar-channel-planning'));
          await tester.tapAt(
            tester.getCenter(row),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('sidebar-menu-leave')));
          await tester.pumpAndSettle();
          final dialog = find.byKey(ValueKey(surface.id));
          return SurfaceProbe(
            isOpen: () => dialog.evaluate().isNotEmpty,
            x: anyX,
            scrim: const Offset(6, 6),
          );
        }
        final add = surface.id == 'sidebar-section-add-conversations';
        final (workspace, api) = (await tester.runAsync(fixture))!;
        addTearDown(workspace.dispose);
        api.routes['GET /channels/external-connect-servers'] = (_) => {
          'servers': [],
        };
        await openFromButton(tester, size, (context) {
          if (add) {
            unawaited(
              showRaftSidebarAddConversations(
                context,
                name: 'Delivery',
                candidates: const {'planning': 'Planning'},
                initial: const {},
              ),
            );
          } else {
            unawaited(
              showNewExternalChannelInvites(
                context,
                workspace,
                () async =>
                    throw StateError('Dismissal must not create a channel'),
              ),
            );
          }
        });
        final dialog = find.byKey(ValueKey(surface.id));
        return SurfaceProbe(
          isOpen: () => dialog.evaluate().isNotEmpty,
          x: anyX,
          scrim: const Offset(6, 6),
          dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
        );
      },
  });
}
