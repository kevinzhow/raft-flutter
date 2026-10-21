import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart' show anyX, openFromButton;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The Computer page's "What's new" dialog (Web `ComputerReleaseNotesAffordance`,
/// a `DialogCard closeOnBackdrop`): the X, Escape, a press on the backdrop and
/// the Android back gesture each close it.
void main() {
  registerCloseTests(
    [
      for (final surface in dialogSurfaces)
        if (surface.id == 'computer-release-notes') surface,
    ],
    {
      'computer-release-notes': (t, size) async {
        await openFromButton(
          t,
          size,
          (context) => unawaited(
            showRaftComputerReleaseNotes(
              context,
              const RaftComputerReleaseNotes(
                version: '1.5.0',
                text: '- Faster startup',
              ),
            ),
          ),
        );
        return SurfaceProbe(
          isOpen: () => find
              .byKey(const ValueKey('computer-release-notes-dialog'))
              .evaluate()
              .isNotEmpty,
          x: anyX,
          scrim: const Offset(6, 6),
        );
      },
    },
  );
}
