import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/close_registry_tasks_board.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'tasks_board_view_test.dart' show card, column, mountBoard, settle;

/// The Backlog reason a card dropped on the Tasks page board's Backlog column
/// asks for (Web TaskBacklogReasonPopover, anchored at the column heading):
/// Escape, a press outside and the Android back gesture leave the card where
/// it was. Its own file so the popup parts keep their deal.
void main() {
  registerCloseTests(tasksBoardSurfaces, <String, OpenSurface>{
    'tasks-board-backlog-reason': (t, size) async {
      await mountBoard(t, size: size);
      // Backlog is the first column: a drop there needs no scrolling.
      final g = await t.startGesture(
        t.getTopLeft(card('t1')) + const Offset(40, 20),
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(-12, 0));
      await t.pump();
      await g.moveTo(t.getCenter(column('backlog')));
      await t.pump();
      await g.up();
      await settle(t);
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('task-backlog-reason'))
            .evaluate()
            .isNotEmpty,
        scrim: Offset(size.width - 6, size.height - 6),
      );
    },
  });
}
