import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/limit_notice.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_limit_notice.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The Free-plan limit notice (Web UpgradeDialog: X and Esc close it, a press
/// outside does not). It has its own file so the six `close_dialogs` parts
/// keep their deal.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      );
}

void main() {
  final harness = <String, OpenSurface>{
    'limit-notice': (t, size) async {
      final w = WorkspaceController(_Client());
      addTearDown(w.dispose);
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showLimitNotice(
            context,
            w,
            gate: 'upload_file_size',
            title: 'Upload larger files',
            hint: 'Free uploads files up to 50 MB each.',
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () =>
            find.byKey(const ValueKey('limit-notice')).evaluate().isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(limitNoticeSurfaces, harness);
  registerNoScrimTests(limitNoticeSurfaces, harness);
}
