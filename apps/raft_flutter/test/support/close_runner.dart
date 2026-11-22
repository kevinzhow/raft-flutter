import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'close_support.dart';
import 'close_surface.dart';

/// A dialog that does not list a pointer close keeps it: a press on the
/// scrim, and a drag down where the dialog is a sheet (its handle is shown),
/// each leave it open (Web `disablePointerDismissal`: a stray touch must not
/// lose what was typed or shown once). Checked inside the surface's close
/// test, on a freshly opened surface per pointer.
Future<void> expectPointerKeepsOpen(
  WidgetTester t,
  CloseSurface surface,
  String name,
  Size size,
  OpenSurface open,
) async {
  final listed = surface.at(widthKey(name));
  // Each check leaves the dialog open: close it through a listed exit so its
  // route completes and what the opener holds is released.
  Future<void> closeAgain(SurfaceProbe probe) async {
    if (!probe.isOpen()) return;
    if (listed.contains(Affordance.systemBack)) {
      await t.binding.handlePopRoute();
    } else if (listed.contains(Affordance.esc)) {
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
    } else if (listed.contains(Affordance.x) && probe.x != null) {
      await t.tap(probe.x!.hitTestable().first);
    }
    await frames(t, 20);
  }

  // Every harness expects a fresh tree (no page state left by the last open).
  Future<SurfaceProbe> fresh() async {
    await t.pumpWidget(const SizedBox.shrink());
    await frames(t, 2);
    return open(t, size);
  }

  if (!listed.contains(Affordance.scrim)) {
    final probe = await fresh();
    if (probe.scrim != null && probe.isOpen()) {
      await t.tapAt(probe.scrim!);
      await frames(t, 20);
      expect(
        probe.isOpen(),
        isTrue,
        reason:
            '${surface.id} @ $name closed on a scrim press it does not list '
            '(Web: ${surface.webOutside?.name})',
      );
    }
    await closeAgain(probe);
  }
  if (!listed.contains(Affordance.drag)) {
    final probe = await fresh();
    final handle = probe.dragHandle?.hitTestable();
    if (handle != null && handle.evaluate().isNotEmpty && probe.isOpen()) {
      await t.fling(handle.first, const Offset(0, 500), 2000);
      await frames(t, 20);
      expect(
        probe.isOpen(),
        isTrue,
        reason:
            '${surface.id} @ $name closed on a drag down it does not list '
            '(Web has no drag to close)',
      );
    }
    await closeAgain(probe);
  }
}

/// Registers one test per (surface, width): every affordance the registry
/// lists for that width exists and closes the surface (each one on a freshly
/// opened surface). A width without affordances must say why in `none`.
void registerCloseTests(
  List<CloseSurface> surfaces,
  Map<String, OpenSurface> harness, {
  TestVariant<Object?> variant = const DefaultTestVariant(),
}) {
  for (final surface in surfaces) {
    final open = harness[surface.id];
    for (final (name, size) in closeSizes) {
      final width = widthKey(name);
      final affordances = surface.at(width);
      if (affordances.isEmpty) {
        test('${surface.id} @ $name has a recorded reason for no close', () {
          expect(
            surface.none[width],
            isNotNull,
            reason:
                '${surface.id} lists no close affordance at $name and gives '
                'no reason (CloseSurface.none)',
          );
        });
        continue;
      }
      testWidgets('${surface.id} @ $name closes via '
          '${(affordances.map((a) => a.name).toList()..sort()).join(', ')}', (
        t,
      ) async {
        expect(
          open,
          isNotNull,
          reason: '${surface.id} has no harness in the family test',
        );
        for (final a in affordances) {
          final probe = await open!(t, size);
          await expectCloses(t, surface, name, a, probe);
        }
        if (surface.kind == SurfaceKind.dialog) {
          await expectPointerKeepsOpen(t, surface, name, size, open!);
        }
      }, variant: variant);
    }
  }
}
