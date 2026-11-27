// Where an Artifact opens in place, closed: the shell's column (Web
// ShellArtifactHost) beside a thread Activity opened at 1280 and over it at
// the foldable's 816, and the cover over a task dialog's card (Web
// ArtifactCoverViewer). × and Escape close them; Android's Back closes them
// before the thread or the task.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raft_flutter/data/tap_target_registry.dart';

import 'artifact_dialog_cover_test.dart' show frame, mountTaskDialog;
import 'shell_artifact_place_test.dart' show card, mountArtifactThread, viewer;
import 'support/close_registry_artifacts.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';
import 'task_surface_test.dart' show flush;

void main() {
  registerCloseTests(artifactPlaceSurfaces, {
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
    'artifact-dialog-cover': (t, size) async {
      await t.pumpWidget(const SizedBox.shrink());
      await mountTaskDialog(
        t,
        size.width < 1000
            ? const TapHost('chat-816', TapSurface.chat, 816, 'Chat, 816')
            : TapTargetRegistry.hosts.firstWhere((h) => h.id == 'chat-1280'),
      );
      await t.tap(find.descendant(of: frame, matching: card));
      await flush(t);
      await t.pumpAndSettle();
      final cover = find.byKey(const ValueKey('artifact-dialog-cover'));
      return SurfaceProbe(
        isOpen: () =>
            find.descendant(of: cover, matching: viewer).evaluate().isNotEmpty,
        x: find.descendant(
          of: cover,
          matching: find.byKey(const ValueKey('artifact-viewer-close')),
        ),
      );
    },
  });
}
