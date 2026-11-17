// The dropdown-menu surface's close cases (Escape, outside press, system Back
// at phone, foldable and desktop widths) run against the Activity page's own
// Filter menu (lib/features/activity_toolbar_mount.dart), the file the
// registry lists for it. The generic RaftDropdownMenu runs in
// close_popups_test.dart.
import 'package:flutter/material.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/features/activity_toolbar_mount.dart';

import 'close_popups_test.dart' show farPoint, mountHost, openWhile;
import 'support/close_registry_popups.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final surface = popupSurfaces.firstWhere((s) => s.id == 'dropdown-menu');
  registerCloseTests([
    surface,
  ], {
    'dropdown-menu': (t, size) async {
      await mountHost(
        t,
        size,
        (context) => SizedBox(
          width: 360,
          child: activityFilterBar(
            context,
            choice: ActivityFilterChoice.all,
            onChoice: (_) {},
            showMarkAllRead: false,
            onMarkAllRead: () {},
          ),
        ),
      );
      await t.tap(find.text('Filter'));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: openWhile(find.text('Artifacts')),
        scrim: farPoint(size),
      );
    },
  });
}
