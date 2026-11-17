import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/web_link_open.dart';

import 'close_dialogs_test.dart' show anyX, openFromButton;
import 'support/close_registry_web_link_choice.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The web-link choice dialog (Web WebLinkChoiceDialog: X, Esc and an outside
/// press all dismiss it). It has its own file so the six `close_dialogs`
/// parts keep their deal.
void main() {
  final harness = <String, OpenSurface>{
    'web-link-choice': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(showWebLinkChoiceDialog(context)),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('web-link-choice-dialog'))
            .evaluate()
            .isNotEmpty,
        x: anyX,
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(webLinkChoiceSurfaces, harness);
}
