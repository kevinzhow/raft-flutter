import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/search_sections.dart';

import 'close_popups_test.dart' show guarded, hostAlive, mountHost;
import 'support/close_registry_panels.dart';
import 'support/close_registry_popups.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  registerCloseTests(
    [
      panelSurfaces.singleWhere(
        (surface) => surface.id == 'conversation-search',
      ),
      popupSurfaces.singleWhere(
        (surface) => surface.id == 'search-channel-result-menu',
      ),
    ],
    {
      'conversation-search': (tester, size) async {
        final (workspace, _) = await mountWorkspace(tester, size);
        final channel = workspace.channel!.id;
        await tester.tap(
          find.bySemanticsLabel('Search This Channel').hitTestable(),
        );
        await frames(tester, 25);
        final back = find.byKey(const Key('scoped-search-back'));
        expect(workspace.location.query('channelId'), channel);
        return SurfaceProbe(
          back: back,
          isOpen: () {
            if (back.hitTestable().evaluate().isNotEmpty) return true;
            expect(workspace.location.route, RaftRoute.channel);
            expect(workspace.location.entityId, channel);
            return false;
          },
        );
      },
      'search-channel-result-menu': (tester, size) async {
        late BuildContext host;
        await mountHost(tester, size, (context) {
          host = context;
          return const Text('Search result');
        });
        unawaited(
          showSearchChannelMenu(
            host,
            at: const Offset(40, 100),
            onOpen: () => fail('Dismissing the menu opened the result'),
          ),
        );
        await frames(tester, 5);
        return SurfaceProbe(
          isOpen: guarded(
            () => find
                .byKey(const Key('quick-switcher-open'))
                .evaluate()
                .isNotEmpty,
            hostAlive,
          ),
          scrim: Offset(size.width - 10, size.height - 10),
        );
      },
    },
  );
}
