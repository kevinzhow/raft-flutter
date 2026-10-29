import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:raft_ui/raft_ui.dart' show RaftTransferProgress;

import 'incoming_share_inbox.dart';
import 'native_sharing.dart';

enum IncomingShareStagingState { preparing, ready, failed }

/// Where one shared file is in the copy.
enum IncomingShareFileState {
  waiting,
  copying,
  ready,
  failed,

  /// Not copied (or discarded) because another file failed; nothing to show.
  stopped,
}

/// One shared file's copy. [progress] changes per chunk; the page listens to it
/// instead of rebuilding with [IncomingShareStaging].
class IncomingShareFileProgress {
  IncomingShareFileProgress(this.file);
  final IncomingSharedFile file;
  IncomingShareFileState state = IncomingShareFileState.waiting;
  IncomingShareFailureReason? failure;
  // ignore: raft_lints/avoid_unreleased_resource -- Value notifiers of one staging run; collected with the run.
  final progress = ValueNotifier<RaftTransferProgress?>(null);
}

/// One incoming share whose attachments are copied into the private inbox in
/// the background. The target picker is presented as soon as the intent
/// arrives; this object carries the per-file progress it shows and the copy's
/// outcome that the hand-off awaits. Nothing is sent or drafted until then.
class IncomingShareStaging extends ChangeNotifier {
  IncomingShareStaging(this.raw)
    : state = raw.token == null
          ? IncomingShareStagingState.preparing
          : IncomingShareStagingState.ready,
      staged = raw.token == null ? null : raw,
      files = [for (final file in raw.files) IncomingShareFileProgress(file)] {
    final known = raw.files.every((f) => (f.sizeBytes ?? 0) > 0);
    totalBytes = known
        ? raw.files.fold<int>(0, (sum, f) => sum + f.sizeBytes!)
        : null;
    if (raw.token != null) {
      for (final file in files) {
        file.state = IncomingShareFileState.ready;
      }
    }
    overall.value = RaftTransferProgress(
      received: raw.token == null ? 0 : totalBytes ?? 0,
      total: totalBytes,
    );
  }
  final IncomingShare raw;
  IncomingShareStagingState state;
  IncomingShare? staged;
  final List<IncomingShareFileProgress> files;

  /// Bytes copied across all files, against the sizes the providers declared
  /// (null total when one is unknown). Per-chunk; listen instead of rebuilding.
  // ignore: raft_lints/avoid_unreleased_resource -- Value notifiers of one staging run; collected with the run.
  final overall = ValueNotifier<RaftTransferProgress?>(null);
  int? totalBytes;
  int copied = 0;
  bool cancelled = false;

  /// Why the copy failed (set with [failed]); the file to blame is marked in
  /// [files].
  IncomingShareFailure? failure;
  final _outcome = Completer<IncomingShare>();
  late final Future<IncomingShare?> settled = _outcome.future
      .then<IncomingShare?>((share) => share, onError: (Object _) => null);

  int get total => raw.files.length;
  bool get failed => state == IncomingShareStagingState.failed;
  bool get preparing => state == IncomingShareStagingState.preparing;

  /// Completes with the staged share, or throws when the copy failed or was
  /// cancelled. Safe to await more than once.
  Future<IncomingShare> get result => _outcome.future;

  int _finishedBytes = 0;
  void _bytes(int index, int bytes) {
    if (index >= files.length) return;
    final file = files[index];
    if (file.state == IncomingShareFileState.waiting) {
      file.state = IncomingShareFileState.copying;
      notifyListeners();
    }
    final received = (file.file.sizeBytes ?? 0) > 0
        ? bytes.clamp(0, file.file.sizeBytes!)
        : bytes;
    file.progress.value = RaftTransferProgress(
      received: bytes,
      total: file.file.sizeBytes,
    );
    overall.value = RaftTransferProgress(
      received: _finishedBytes + received,
      total: totalBytes,
    );
  }

  void _fileDone(int count) {
    copied = count;
    final index = count - 1;
    if (index >= 0 && index < files.length) {
      final file = files[index];
      file.state = IncomingShareFileState.ready;
      final size = file.file.sizeBytes;
      file.progress.value = RaftTransferProgress(
        received: size ?? 0,
        total: size,
      );
      _finishedBytes += size ?? 0;
      overall.value = RaftTransferProgress(
        received: _finishedBytes,
        total: totalBytes,
      );
    }
    if (count < files.length) {
      files[count].state = IncomingShareFileState.copying;
    }
    notifyListeners();
  }

  void start(
    Future<IncomingShare> Function(
      void Function(int copied) progress,
      void Function(int index, int bytes) bytes,
    )
    run,
  ) {
    if (_outcome.isCompleted) return;
    if (staged != null) {
      _outcome.complete(staged);
      return;
    }
    // A failure is surfaced through [state]; unobserved futures stay quiet.
    unawaited(_outcome.future.then<void>((_) {}, onError: (Object _) {}));
    if (files.isNotEmpty) files.first.state = IncomingShareFileState.copying;
    unawaited(() async {
      try {
        final share = await run(_fileDone, _bytes);
        staged = share;
        state = IncomingShareStagingState.ready;
        // Whatever the per-file reports said, the copy is complete.
        for (final file in files) {
          file.state = IncomingShareFileState.ready;
        }
        _outcome.complete(share);
      } catch (error) {
        state = IncomingShareStagingState.failed;
        final reason = error is IncomingShareFailure ? error : null;
        failure = reason;
        final index = reason?.index;
        for (final (i, file) in files.indexed) {
          if (index == null || i == index) {
            file.state = IncomingShareFileState.failed;
            file.failure = reason?.reason;
          } else {
            file.state = IncomingShareFileState.stopped;
          }
        }
        _outcome.completeError(error);
      }
      notifyListeners();
    }());
  }

  /// Stops copying at the next chunk and removes what was copied.
  void cancel() => cancelled = true;
}
