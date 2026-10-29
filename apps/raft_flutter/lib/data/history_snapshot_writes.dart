import 'dart:async';

import 'package:raft_ui/raft_ui.dart' show RaftIdleTimer;

/// Coalesces compatibility snapshots without making them a message authority.
/// Registration captures the receiver's outer zone before any database work.
class HistorySnapshotWrites {
  static final _owners = Expando<_SnapshotWrites>();
  static void attach(Object owner) =>
      _owners[owner] ??= _SnapshotWrites(Zone.current);
  static Future<void> schedule(
    Object owner,
    Object key,
    Future<void> Function() write,
  ) => _owners[owner]?.schedule(key, write) ?? write();
  static Future<void> writeNow(
    Object owner,
    Object key,
    Future<void> Function() write,
  ) => _owners[owner]?.writeNow(key, write) ?? write();
  static Future<void> flush(Object owner) =>
      _owners[owner]?.flush() ?? Future<void>.value();
  static void cancel(Object owner) {
    _owners[owner]?.close();
    _owners[owner] = null;
  }
}

class _SnapshotJob {
  _SnapshotJob(this.write) {
    done.future.ignore();
  }
  Future<void> Function() write;
  final done = Completer<void>();
}

class _SnapshotWrites {
  _SnapshotWrites(this.zone);
  final Zone zone;
  final timer = RaftIdleTimer(yieldToAnimation: false);
  final jobs = <Object, _SnapshotJob>{};
  Future<void> tail = Future<void>.value();
  bool closed = false;

  Future<void> schedule(Object key, Future<void> Function() write) {
    if (closed) return Future<void>.value();
    final job = jobs.putIfAbsent(key, () => _SnapshotJob(write));
    job.write = write;
    if (!timer.isActive) {
      zone.run(
        () => timer.start(
          const Duration(milliseconds: 60),
          () => unawaited(flush()),
        ),
      );
    }
    return job.done.future;
  }

  Future<void> flush() {
    timer.cancel();
    final batch = jobs.values.toList();
    jobs.clear();
    return _submit(batch);
  }

  Future<void> writeNow(Object key, Future<void> Function() write) {
    if (closed) return Future<void>.value();
    // A normal snapshot supersedes an older queued edit snapshot. Serialize
    // it after any snapshot already writing, so old content cannot land last.
    final job = jobs.remove(key) ?? _SnapshotJob(write);
    job.write = write;
    if (jobs.isEmpty) timer.cancel();
    unawaited(_submit([job]));
    return job.done.future;
  }

  Future<void> _submit(List<_SnapshotJob> batch) {
    if (batch.isEmpty) return tail;
    return tail = tail.then((_) async {
      for (final job in batch) {
        try {
          if (!closed) await job.write();
          job.done.complete();
        } catch (cause, stack) {
          job.done.completeError(cause, stack);
        }
      }
    });
  }

  void close() {
    closed = true;
    timer.cancel();
    for (final job in jobs.values) {
      job.done.complete();
    }
    jobs.clear();
  }
}
