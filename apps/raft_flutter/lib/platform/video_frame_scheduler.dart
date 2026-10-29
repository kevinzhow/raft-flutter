import 'dart:async';

import 'package:flutter/foundation.dart';

import 'video_frame_probe.dart';

/// Runs first-frame reads with a hard cap on how many are in flight (a native
/// retriever or a libmpv instance each hold a decoder and a connection), the
/// newest request first: the card that just scrolled into view is the one the
/// reader is looking at. A job whose card is no longer wanted when its turn
/// comes never starts.
class VideoFrameScheduler {
  VideoFrameScheduler({this.limit = 2});

  /// The one scheduler of the app: every card shares its two slots.
  static final VideoFrameScheduler shared = VideoFrameScheduler();

  final int limit;
  final List<VideoFrameJob<Object?>> _queue = [];
  int _running = 0;
  int get running => _running;
  int get queued => _queue.length;

  /// Peak of [running] since the start (tests).
  @visibleForTesting
  int peak = 0;

  /// Queues [run]. [wanted] is asked when the job's turn comes; false drops the
  /// job as cancelled without running it.
  VideoFrameJob<T> submit<T>(
    Future<T> Function(VideoFrameJob<T> job) run, {
    bool Function()? wanted,
  }) {
    final job = VideoFrameJob<T>._(this, run, wanted);
    _queue.add(job as VideoFrameJob<Object?>);
    _pump();
    return job;
  }

  void _pump() {
    while (_running < limit && _queue.isNotEmpty) {
      final job = _queue.removeLast();
      if (job._cancelled) continue;
      if (job._wanted != null && !job._wanted()) {
        job._cancel();
        continue;
      }
      _running++;
      if (_running > peak) peak = _running;
      job._start().whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}

/// One queued or running read. [result] completes with the read's value, or
/// with a [VideoFrameException] of kind `cancelled` when [cancel] ended it first.
class VideoFrameJob<T> {
  VideoFrameJob._(this._owner, this._run, this._wanted) {
    // A job cancelled before anyone awaited it is not an unhandled error.
    _result.future.ignore();
  }
  final VideoFrameScheduler _owner;
  final Future<T> Function(VideoFrameJob<T> job) _run;
  final bool Function()? _wanted;
  final _result = Completer<T>();
  final List<VoidCallback> _onCancel = [];
  bool _cancelled = false, _started = false;

  Future<T> get result => _result.future;
  bool get cancelled => _cancelled;
  bool get started => _started;

  /// Calls [callback] when the job is cancelled while it runs (stop the native
  /// work); never when it finishes by itself.
  void onCancel(VoidCallback callback) => _onCancel.add(callback);

  Future<void> _start() async {
    _started = true;
    try {
      final value = await _run(this);
      if (!_result.isCompleted) _result.complete(value);
    } on Object catch (error, trace) {
      if (!_result.isCompleted) _result.completeError(error, trace);
    }
  }

  /// Ends the job: removed from the queue, or the running read told to stop.
  /// [result] fails as cancelled at once; the slot is given back when the read
  /// really ends.
  void cancel() {
    if (_cancelled) return;
    _cancel();
    _owner._queue.remove(this);
    if (_started) {
      for (final callback in _onCancel) {
        try {
          callback();
        } on Object {
          // best effort
        }
      }
    }
  }

  void _cancel() {
    _cancelled = true;
    if (!_result.isCompleted) {
      _result.completeError(
        const VideoFrameException(VideoFrameFailure.cancelled),
      );
    }
  }
}
