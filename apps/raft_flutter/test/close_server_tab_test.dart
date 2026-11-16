import 'package:flutter_test/flutter_test.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/close_registry_server_tab.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'support/server_tab.dart';

/// The server tab's popover inside the real workspace shell at phone width:
/// Escape, a press outside and the Android back gesture close it, and the last
/// one closes the popover before it leaves the page.
void main() {
  RootFixture? last;
  OpenSurface open() => (t, size) async {
    final previous = last;
    if (previous != null) await previous.close(t);
    final f = last = RootFixture();
    await f.mount(t, 'light', size.width, uri: Uri.parse('/s/alpha'));
    await openServerPopover(t, flush: f.flush);
    return SurfaceProbe(
      isOpen: () => find.byKey(serverPopoverKey).evaluate().isNotEmpty,
      scrim: const Offset(4, 4),
    );
  };

  registerCloseTests(serverTabSurfaces, {'mobile-server-tab-popover': open()});

  tearDown(() => last = null);
}
