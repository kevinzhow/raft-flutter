import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'close_popups_test.dart' show farPoint, mountHost, openWhile;
import 'support/close_registry_popups.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

/// The in-field combobox (Web `RuntimeChoiceCombobox`): Escape, a tap outside
/// and the Android back gesture close its list.
void main() {
  registerCloseTests(
    [
      for (final surface in popupSurfaces)
        if (surface.id == 'agent-combobox') surface,
    ],
    {
      'agent-combobox': (t, size) async {
        await mountHost(
          t,
          size,
          (_) => SizedBox(
            width: 220,
            child: RaftAgentCombobox(
              label: 'Runtime',
              value: 'a',
              items: const [
                RaftComboboxItem('a', 'Claude'),
                RaftComboboxItem('b', 'Codex option'),
              ],
              onSelected: (_) {},
            ),
          ),
        );
        // The field is the search input: a tap on it focuses it and opens the list.
        await t.tap(find.byType(TextField));
        await frames(t, 15);
        return SurfaceProbe(
          isOpen: openWhile(find.text('Codex option')),
          scrim: farPoint(size),
        );
      },
    },
  );
}
