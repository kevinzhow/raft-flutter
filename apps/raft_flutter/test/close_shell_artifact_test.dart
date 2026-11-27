// The shell's Artifact column (Web ShellArtifactHost): × and Escape close it
// beside a thread Activity opened at 1280 and over it at the foldable's 816,
// where it covers the main area; Android's Back closes it before the thread.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shell_artifact_place_test.dart' show card, mountArtifactThread, viewer;
import 'support/close_registry_artifacts.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'task_surface_test.dart' show flush;

void main() {
  registerCloseTests(
    shellArtifactSurfaces,
    {
      'shell-artifact-column': (t, size) async {
        await t.pumpWidget(const SizedBox.shrink());
        final c = await mountArtifactThread(
          t,
          size.width < 1000 ? 'activity-thread-816' : 'activity-thread-1280',
        );
        await t.tap(card);
        await flush(t);
        await t.pumpAndSettle();
        final column = find.byKey(const ValueKey('shell-artifact-column'));
        return SurfaceProbe(
          isOpen: () =>
              find
                  .descendant(of: column, matching: viewer)
                  .evaluate()
                  .isNotEmpty &&
              c.w.location.query('artifact') != null,
          x: find.descendant(
            of: column,
            matching: find.byKey(const ValueKey('artifact-viewer-close')),
          ),
        );
      },
    },
  );
}
