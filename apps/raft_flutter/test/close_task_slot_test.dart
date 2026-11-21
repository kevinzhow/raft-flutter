import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/task_surface.dart';

import 'message_context_transition_test.dart' show row;
import 'support/close_registry_task_slot.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'task_content_slot_test.dart' show card, mountTasks, settle;

/// Task v2 beside the Tasks list (Web TaskContentSlot): × and Escape beside
/// the list, Back and the system back on a phone, where it is a page.
void main() {
  testWidgets(
    'phone system Back dismisses task details before leaving the task',
    (t) async {
      await mountTasks(
        t,
        const Size(390, 844),
        platform: TargetPlatform.android,
        discussionMessages: [
          for (var i = 1; i <= 40; i++) row('reply-$i', 'task-conv', i),
        ],
      );
      await t.tap(card);
      await settle(t);
      final surface = find.byType(SourceTaskSurface);
      final toggle = find.byKey(const ValueKey('task-modal-bar-summary'));
      final title = find.byKey(const ValueKey('task-modal-title'));
      final timeline = find.byKey(const ValueKey('timeline-focus'));
      final position = Scrollable.of(t.element(timeline)).position;
      position.jumpTo(position.minScrollExtent);
      await settle(t);
      expect(title.hitTestable(), findsOneWidget);
      expect(toggle, findsNothing);
      final start = position.pixels;
      for (var swipe = 0; swipe < 3 && toggle.evaluate().isEmpty; swipe++) {
        await t.dragFrom(t.getCenter(timeline), const Offset(0, -260));
        await settle(t);
      }
      expect(position.pixels - start, greaterThan(100));
      expect(toggle, findsOneWidget);
      expect(title.hitTestable(), findsNothing);
      final readingPosition = position.pixels;
      final drawer = find.byKey(const ValueKey('task-head-pull-down'));
      final task = surface.evaluate().single;
      expect(drawer, findsNothing);
      await t.tap(toggle.hitTestable());
      await settle(t);
      expect(drawer.hitTestable(), findsOneWidget);
      expect(position.pixels, readingPosition);

      await t.binding.handlePopRoute();
      await settle(t);
      expect(drawer, findsNothing);
      expect(surface.evaluate().single, same(task));
      expect(position.pixels, readingPosition);

      await t.binding.handlePopRoute();
      await settle(t);
      expect(surface, findsNothing);
      expect(card, findsOneWidget);
    },
  );

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
