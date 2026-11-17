// Web raft-ui `SaveStatus` + `SaveStatusError` (components/save-status): the
// line under a setting that applies at once. It holds an alert saying what
// failed and nothing otherwise; empty it takes no room, so a setting with no
// failure is not given one (Web renders it always, `empty:hidden`).
import 'package:flutter/material.dart';

import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/save_status.g.dart';
import 'theme.dart';

/// What one setting that applies at once shows: [saving] while its request is
/// out (the control is disabled) and the [failure] of its last change, which
/// stays until the next change (Web `ImmediateSaveFeedback`).
@immutable
class RaftImmediateSaveState {
  const RaftImmediateSaveState({this.saving = false, this.failure});
  static const idle = RaftImmediateSaveState();
  final bool saving;

  /// The English source text; localised here.
  final String? failure;

  @override
  bool operator ==(Object other) =>
      other is RaftImmediateSaveState &&
      other.saving == saving &&
      other.failure == failure;
  @override
  int get hashCode => Object.hash(saving, failure);
}

/// The failure line of a setting that applies at once: `SaveStatus` holding a
/// `SaveStatusError` (an alert, announced when it appears). Place it right
/// after the control's title or description (`ListRowBody`).
class RaftSaveStatus extends StatelessWidget {
  const RaftSaveStatus(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftSaveStatusRecipe.resolve(
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    );
    final base = DefaultTextStyle.of(context).style;
    final root = style.root.text(t.recipeTokens, base: base);
    final error = style.error.text(t.recipeTokens, base: root);
    // `mt-0.5` under a `ListRowBody` that already gaps its children by 2px.
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Text(raftText(context, message), style: error),
      ),
    );
  }
}
