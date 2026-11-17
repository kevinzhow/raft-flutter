import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web `useImmediateSave` (components/settings/ImmediateSetting.tsx): runs one
/// save for one setting that applies the moment it is chosen and tracks its
/// result. Only the latest save reports, so a slower earlier request cannot
/// overwrite what the latest one said. While it runs the control shows the
/// chosen value ([pending], Web's optimistic store value) and is disabled; on
/// a failure the value goes back to the stored one and the failure shows under
/// the control until the next change. A success says nothing.
class ImmediateSave<T> {
  ImmediateSave(this._changed);
  final VoidCallback _changed;
  RaftImmediateSaveState state = RaftImmediateSaveState.idle;

  /// The value being saved, shown by the control until the save ends.
  T? pending;
  int _sequence = 0;

  /// [apply] throws when the change was not stored; [failure] is the message
  /// for that error. Resolves to whether it was stored.
  Future<bool> run(
    T next,
    Future<void> Function() apply,
    String Function(Object error) failure,
  ) async {
    final id = ++_sequence;
    pending = next;
    state = const RaftImmediateSaveState(saving: true);
    _changed();
    var stored = true;
    try {
      await apply();
      if (id == _sequence) state = RaftImmediateSaveState.idle;
    } catch (error) {
      stored = false;
      if (id == _sequence) {
        state = RaftImmediateSaveState(failure: failure(error));
      }
    }
    if (id == _sequence) {
      pending = null;
      _changed();
    }
    return stored;
  }

  /// Drops the running save's outcome and any failure (another account).
  void reset() {
    _sequence++;
    pending = null;
    state = RaftImmediateSaveState.idle;
  }
}
