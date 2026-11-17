import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/message_select_text_sheet.dart';

import 'close_dialogs_test.dart' show anyX, openFromButton;
import 'support/close_registry_dialogs.dart';
import 'support/close_runner.dart';
import 'support/close_surface.dart';

/// The Select text bottom sheet (Web `MessageSelectTextDrawer`): a sheet at
/// every width. Its own file so the `close_dialogs` parts keep their deal.
void main() {
  final surfaces = [
    for (final surface in dialogSurfaces)
      if (surface.id == 'message-select-text') surface,
  ];
  final harness = <String, OpenSurface>{
    'message-select-text': (t, size) async {
      await openFromButton(
        t,
        size,
        (context) => unawaited(
          showMessageSelectTextSheet(
            context,
            senderName: 'Ada',
            time: '10:30',
            markdown: 'Hello **world**',
            onQuote: (_) {},
          ),
        ),
      );
      final sheet = find.byKey(const ValueKey('message-select-text'));
      return SurfaceProbe(
        isOpen: () => sheet.evaluate().isNotEmpty,
        x: find.descendant(of: sheet, matching: anyX),
        scrim: const Offset(6, 6),
        dragHandle: find.byKey(const ValueKey('raft-sheet-handle')),
      );
    },
  };
  registerCloseTests(surfaces, harness);
}
