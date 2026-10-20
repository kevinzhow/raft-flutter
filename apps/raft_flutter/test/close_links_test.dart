import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';

import 'close_dialogs_test.dart' show openFromButton, registerNoScrimTests;
import 'support/close_registry_links.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

void main() {
  final harness = <String, OpenSurface>{
    'custom-protocol-link-confirm': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          confirmCustomProtocolLink(
            context,
            Uri.parse('obsidian://open?vault=a'),
          ),
        ),
      );
      return SurfaceProbe(
        isOpen: () => find
            .byKey(const ValueKey('custom-protocol-link-confirm'))
            .evaluate()
            .isNotEmpty,
        scrim: const Offset(6, 6),
      );
    },
  };
  registerCloseTests(linkSurfaces, harness);
  registerNoScrimTests(linkSurfaces, harness);
}
