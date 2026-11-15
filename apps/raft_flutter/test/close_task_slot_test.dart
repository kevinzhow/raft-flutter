import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';

import 'support/close_registry_task_slot.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'task_content_slot_test.dart' show card, mountTasks, settle;

/// Task v2 beside the Tasks list (Web TaskContentSlot): × and Escape beside
/// the list, Back and the system back on a phone, where it is a page.
void main() {
  registerCloseTests(taskSlotSurfaces, <String, OpenSurface>{
    'task-slot-tasks-route': (t, size) async {
      await mountTasks(t, size);
      await t.tap(card);
      await settle(t);
      return SurfaceProbe(
        isOpen: () => find.byType(SourceTaskSurface).evaluate().isNotEmpty,
        x: find.byKey(const ValueKey('task-modal-close')),
        back: find.byKey(const ValueKey('task-modal-mobile-back')),
      );
    },
  });
}
