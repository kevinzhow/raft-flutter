// Settings that apply the moment they are chosen (Web v1.24.0
// components/settings/ImmediateSetting.tsx `useImmediateSave`, and
// features/settings/administration/showUndoToast.ts).
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

/// `useImmediateSave`: runs one save for one setting and tracks its result.
/// Only the latest save reports: a slower earlier request cannot overwrite what
/// the latest one said. [run] resolves to whether the save went through, so the
/// caller can put the control back when it did not.
class ImmediateSave {
  ImmediateSave(this._changed);

  /// Rebuilds the owner (a `setState` that ignores an unmounted state).
  final VoidCallback _changed;
  int _sequence = 0;

  /// The failure line under the control; null when there is none.
  String? failure;
  bool saving = false;

  Future<bool> run(
    Future<void> Function() apply,
    String Function(Object error) failureMessage,
  ) async {
    final id = ++_sequence;
    saving = true;
    failure = null;
    _changed();
    try {
      await apply();
      if (id == _sequence) {
        saving = false;
        _changed();
      }
      return true;
    } catch (error) {
      if (id == _sequence) {
        saving = false;
        failure = failureMessage(error);
        _changed();
      }
      return false;
    }
  }
}

/// `showUndoToast`: a server setting that affects others, applied at once; the
/// toast offers Undo, which puts the previous value back through the same save.
/// Undo works once, and only on the server it was changed on; after a switch to
/// another server it says so instead.
void showUndoToast(
  BuildContext context,
  WorkspaceController w, {
  required String title,
  required String serverId,
  required VoidCallback undo,
}) {
  final host = RaftToastHost.maybeOf(context);
  if (host == null) return;
  final wrongServer = raftText(
    context,
    "Not undone: you've switched to another server",
  );
  var used = false;
  host.show(
    raftText(context, title),
    tone: RaftToastRecipeTone.success,
    actionLabel: raftText(context, 'Undo'),
    onAction: () {
      if (used) return;
      used = true;
      if (w.server?.id != serverId) {
        host.show(wrongServer, tone: RaftToastRecipeTone.error);
        return;
      }
      undo();
    },
  );
}
