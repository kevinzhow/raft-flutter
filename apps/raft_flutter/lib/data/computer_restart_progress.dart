// A Computer's remote Restart, shared per machine (Web v1.24
// machineStore.computerOperationProgress, setComputerOperation,
// useComputerUpgradeCard.ts useComputerRestart, machineEvents applyRestartDone):
// the rack row and the Computer page read the same entry, so a restart from
// either shows on both. Client-only; never persisted.
import 'dart:async';

/// One restart in flight / just ended. [error] is English source copy (or a
/// server text), localized where it is shown.
class ComputerRestartProgress {
  const ComputerRestartProgress({
    this.requestId,
    this.done = false,
    this.error,
  });
  final String? requestId;
  final bool done;
  final String? error;
}

class ComputerRestartProgressStore {
  ComputerRestartProgressStore({required this.onChange});

  /// Called after every change (the directory bumps its revision and notifies).
  final void Function() onChange;
  final _entries = <String, ComputerRestartProgress>{};
  final _timers = <String, Timer>{};

  static const timeout = Duration(seconds: 60);
  static const doneLinger = Duration(seconds: 3);
  static const errorLinger = Duration(seconds: 4);

  ComputerRestartProgress? progress(String machineId) => _entries[machineId];

  /// setComputerOperation(id, {operation: "restart"}), before the POST.
  void begin(String machineId) {
    _set(machineId, const ComputerRestartProgress());
    _arm(machineId, timeout, () {
      _set(
        machineId,
        ComputerRestartProgress(
          requestId: _entries[machineId]?.requestId,
          done: true,
          error:
              'Restart timed out. Check that the Computer is online and retry.',
        ),
      );
      _arm(machineId, doneLinger, () => _set(machineId, null));
    });
  }

  /// The POST's answer: the id `computer:restart:done` will carry.
  void accept(String machineId, String requestId) {
    final current = _entries[machineId];
    if (current == null || current.done) return;
    // The 60s safety timer keeps running from the click, as in Web.
    _entries[machineId] = ComputerRestartProgress(requestId: requestId);
    onChange();
  }

  /// The POST failed: the error stays 4s, then the action comes back.
  void fail(String machineId, String error) {
    _set(machineId, ComputerRestartProgress(done: true, error: error));
    _arm(machineId, errorLinger, () => _set(machineId, null));
  }

  /// `computer:restart:done` {machineId, requestId, ok, error}: only the entry
  /// whose request id matches ends; a failure without text says restart_failed.
  void complete(String machineId, String? requestId, bool ok, String? error) {
    final current = _entries[machineId];
    if (current == null || current.requestId != requestId) return;
    _set(
      machineId,
      ComputerRestartProgress(
        requestId: requestId,
        done: true,
        error: ok
            ? null
            : (error == null || error.isEmpty ? 'Restart failed.' : error),
      ),
    );
    _arm(machineId, doneLinger, () => _set(machineId, null));
  }

  void clearAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _entries.clear();
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  void _arm(String id, Duration after, void Function() run) {
    _timers[id]?.cancel();
    _timers[id] = Timer(after, run);
  }

  void _set(String id, ComputerRestartProgress? value) {
    if (value == null) {
      _timers.remove(id)?.cancel();
      if (_entries.remove(id) == null) return;
    } else {
      _entries[id] = value;
    }
    onChange();
  }
}
