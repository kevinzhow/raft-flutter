import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/close_bulk_agent_model.dart';
import 'support/close_registry_dialogs.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  final surface = dialogSurfaces.singleWhere(
    (surface) => surface.id == 'computer-bulk-model',
  );
  for (final (name, size) in closeSizes) {
    testWidgets('bulk model @ $name ignores scrim on choose and review', (
      t,
    ) async {
      for (final review in [false, true]) {
        final harness = await openBulkModelClose(t, size, review: review);
        await t.tapAt(harness.probe.scrim!);
        await frames(t, 20);
        expect(harness.probe.isOpen(), isTrue);
        expect(harness.writes, isEmpty);
      }
    });

    testWidgets('bulk model @ $name review supports its registered exits', (
      t,
    ) async {
      for (final exit in surface.at(widthKey(name))) {
        final harness = await openBulkModelClose(t, size, review: true);
        await expectCloses(t, surface, name, exit, harness.probe);
        expect(harness.writes, isEmpty);
      }
    });

    testWidgets('bulk model @ $name Cancel dismisses and review Back stays', (
      t,
    ) async {
      for (final review in [false, true]) {
        final harness = await openBulkModelClose(t, size, review: review);
        if (review) {
          await t.tap(find.text('Back'));
          await frames(t, 20);
          expect(harness.probe.isOpen(), isTrue);
          expect(find.byKey(const ValueKey('bulk-model-next')), findsOneWidget);
        }
        await t.tap(find.text('Cancel'));
        await frames(t, 20);
        expect(harness.probe.isOpen(), isFalse);
        expect(harness.writes, isEmpty);
      }
    });

    testWidgets('bulk model @ $name applying blocks every registered exit', (
      t,
    ) async {
      final harness = await openBulkModelClose(t, size, review: true);
      final saving = Completer<void>();
      harness.client.writeGate = saving;
      await t.tap(find.byKey(const ValueKey('bulk-model-apply')));
      await frames(t, 2);
      expect(find.text('Saving…'), findsOneWidget);
      expect(harness.probe.x, findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Back'), findsNothing);
      await pressEscape(t);
      expect(harness.probe.isOpen(), isTrue);
      await systemBack(t);
      expect(harness.probe.isOpen(), isTrue);
      await t.tapAt(harness.probe.scrim!);
      await frames(t, 20);
      expect(harness.probe.isOpen(), isTrue);
      if (surface.at(widthKey(name)).contains(Affordance.drag)) {
        await t.fling(harness.probe.dragHandle!, const Offset(0, 500), 2000);
        await frames(t, 20);
        expect(harness.probe.isOpen(), isTrue);
      }
      saving.complete();
      await frames(t, 30);
      expect(harness.probe.isOpen(), isFalse);
      expect(harness.writes, hasLength(1));
    });
  }
}
