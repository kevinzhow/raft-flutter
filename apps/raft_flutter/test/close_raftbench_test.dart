// The RaftBench start-date picker closes with Escape, a tap outside and the
// system Back at every width (docs/close-affordances.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_registry_raftbench.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

const _hostKey = Key('raftbench-close-host');

void main() {
  final harness = <String, OpenSurface>{
    'raftbench-date-picker': (t, size) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: raftTheme().copyWith(
            platform: size.width >= 768
                ? TargetPlatform.macOS
                : TargetPlatform.android,
          ),
          home: const Scaffold(body: Text('root-page')),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            key: _hostKey,
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: SizedBox(
                width: 200,
                child: RaftbenchDateField(
                  value: '2026-10-17',
                  max: '2026-10-24',
                  semanticLabel: 'Analyze messages since (UTC)',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await frames(t, 20);
      await t.tap(find.byKey(const ValueKey('raftbench-history-from')));
      await frames(t, 15);
      return SurfaceProbe(
        isOpen: () {
          if (find.byKey(_hostKey).evaluate().isEmpty) {
            fail('the host page closed together with the picker');
          }
          return find.byType(DatePickerDialog).evaluate().isNotEmpty;
        },
        scrim: Offset(size.width - 10, size.height - 10),
      );
    },
  };
  registerCloseTests(raftbenchSurfaces, harness);
}
