import 'package:flutter_test/flutter_test.dart';

import 'close_support.dart';
import 'close_surface.dart';

/// Registers one test per (surface, width): every affordance the registry
/// lists for that width exists and closes the surface (each one on a freshly
/// opened surface). A width without affordances must say why in `none`.
void registerCloseTests(
  List<CloseSurface> surfaces,
  Map<String, OpenSurface> harness,
) {
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
      });
    }
  }
}
