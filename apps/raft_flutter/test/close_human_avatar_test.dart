import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/human_avatar_builder_dialog.dart';

import 'close_dialogs_test.dart'
    show anyX, openFromButton, registerNoScrimTests;
import 'support/close_registry_human_avatar.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The human avatar builder closes by its X, Escape, the Android back
/// gesture, a scrim press and (sheet) a drag down at 390 / 816 / 1280. It has
/// its own file so the six `close_dialogs` parts keep their deal.
void main() {
  final client = RaftClient(
    origin: 'https://fixture.test',
    sessionStore: MemorySessionStore(),
  );
  final harness = <String, OpenSurface>{
    'human-avatar-builder': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showHumanAvatarBuilder(
            context,
            client: client,
            avatarUrl: 'pixel-human:v1:sky.3.curly.brown.grin.none.none',
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () =>
            find.byType(HumanAvatarBuilderDialog).evaluate().isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
  };
  registerCloseTests(humanAvatarSurfaces, harness);
  registerNoScrimTests(humanAvatarSurfaces, harness);
}
