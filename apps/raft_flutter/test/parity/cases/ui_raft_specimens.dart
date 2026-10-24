// components.raft-ui.<specimen>.<light|dark>: the Flutter side of tool/parity-ui. Every builder lays out the same
// region as tool/parity-ui/host/src/specimens.tsx (same ids, rows, gaps and labels) from the real raft_ui widgets;
// nothing here paints a component by hand. Run `tool/parity-ui/run flutter` then `tool/parity-ui/run diff`.
// Builders live in ui_raft_specimens/<group>.dart, keyed by specimen id (specimens.json).
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'ui_raft_specimens/actions.dart';
import 'ui_raft_specimens/forms.dart';
import 'ui_raft_specimens/indicators.dart';
import 'ui_raft_specimens/navigation.dart';
import 'ui_raft_specimens/support.dart';

final Map<String, RaftSpecimenBuilder> _specimens = {
  ...raftActionSpecimens,
  ...raftFormSpecimens,
  ...raftNavigationSpecimens,
  ...raftIndicatorSpecimens,
};

final Map<String, ParityCase> uiRaftSpecimenCases = {
  for (final entry in _specimens.entries)
    for (final mode in const ['light', 'dark'])
      'components.raft-ui.${entry.key}.$mode': ParityCase(
        widgets: const ['raft_ui:raft-ui 0.7.1 specimens'],
        build: (ctx) => _specimenFrame(ctx, entry.key, entry.value),
        notes: 'tool/parity-ui/host/src/specimens.tsx ${entry.key}',
      ),
};

/// `<div data-specimen class="box-content bg-layer-canvas p-4 text-foreground" style="width: 358px">`: the capture
/// target. 358 content + 2 x 16 padding; the height is the content's.
Widget _specimenFrame(ParityContext ctx, String id, RaftSpecimenBuilder body) {
  return Align(
    alignment: Alignment.topLeft,
    child: ctx.target(
      Builder(
        builder: (context) {
          final t = RaftTokens.of(context);
          return Material(
            key: ValueKey('raft-ui-specimen-$id'),
            type: MaterialType.transparency,
            child: Container(
              width: 390,
              padding: const EdgeInsets.all(16),
              color: t.ui.layerCanvas,
              child: DefaultTextStyle(
                style: t.scale(RaftTypeScale.body),
                child: body(context, t),
              ),
            ),
          );
        },
      ),
    ),
  );
}
