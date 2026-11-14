import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The task delete confirmation (Web `TaskDeleteConfirmDialog`, a
/// ConfirmDialog without pointer dismissal): the X, Escape and the Android back
/// gesture close it, a press on the scrim does not. It has its own file so the
/// six `close_dialogs` parts keep their deal.
void main() {
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (surface.id == 'task-delete-confirm') surface,
  ];
  final harness = <String, OpenSurface>{
    'task-delete-confirm': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showRaftDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => RaftTaskDeleteConfirmDialog(
              taskNumber: 7,
              onCancel: () => Navigator.of(dialogContext).pop(),
              onConfirm: () async => null,
            ),
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('task-delete-confirm'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(surfaces, harness);
  registerNoScrimTests(surfaces, harness);
}
