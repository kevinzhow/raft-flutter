import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_mobile_nav_server.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// The server tab's popover over the phone tab bar: Esc, an outside press and
/// the Android back gesture close it.
void main() {
  OpenSurface open() => (t, size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: closePlatform(size)),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: RaftMobileNav(
              items: const [
                RaftMobileNavItem(
                  id: 'chat',
                  label: 'Home',
                  glyph: RaftGlyph.home,
                ),
              ],
              selectedId: 'chat',
              onSelected: (_) {},
              trailing: RaftMobileNavServerTab(
                label: 'Server',
                avatar: const SizedBox.expand(),
                popoverKey: const ValueKey('mobile-nav-server-popover'),
                contentBuilder: (context, close) =>
                    RaftMobileNavServerPopoverGroup(
                      children: [
                        RaftMobileNavServerPopoverRow(
                          label: 'Row',
                          onPressed: close,
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await frames(t, 4);
    await t.tap(find.byType(RaftMobileNavServerTab));
    await frames(t, 8);
    return SurfaceProbe(
      isOpen: () => find
          .byKey(const ValueKey('mobile-nav-server-popover'))
          .evaluate()
          .isNotEmpty,
      scrim: const Offset(4, 4),
    );
  };

  registerCloseTests(mobileNavServerSurfaces, {
    'mobile-nav-server-popover': open(),
  });
}
