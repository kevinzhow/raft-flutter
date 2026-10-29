import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Bytes received so far of one attachment transfer. [total] is null when the
/// server sent no usable length (dio reports -1).
@immutable
class AttachmentTransferProgress {
  const AttachmentTransferProgress(this.received, [this.total]);

  /// The request is in flight but no byte has arrived yet.
  static const connecting = AttachmentTransferProgress(0);
  final int received;
  final int? total;
  @override
  bool operator ==(Object other) =>
      other is AttachmentTransferProgress &&
      received == other.received &&
      total == other.total;
  @override
  int get hashCode => Object.hash(received, total);
}

/// Progress of one in-flight transfer, safe to feed from every network chunk:
/// listeners are notified at most once per [interval] (a leading update, then
/// the newest value at each tick), so a fast download costs ~10 notifications
/// per second no matter how many chunks arrive. A null value means the bytes
/// are not on the network (queued, or served from the disk cache).
class AttachmentTransfer extends ValueNotifier<AttachmentTransferProgress?> {
  AttachmentTransfer({this.interval = const Duration(milliseconds: 100)})
    : super(null);
  final Duration interval;
  Timer? _timer;
  AttachmentTransferProgress? _pending;
  bool _closed = false;

  /// Call with dio's `onReceiveProgress` arguments (any chunk rate).
  void report(int received, int total) {
    if (_closed) return;
    final next = AttachmentTransferProgress(received, total > 0 ? total : null);
    if (_timer == null) {
      value = next;
      _timer = Timer(interval, _tick);
    } else {
      _pending = next;
    }
  }

  void _tick() {
    _timer = null;
    final next = _pending;
    _pending = null;
    if (next == null || _closed) return;
    value = next;
    _timer = Timer(interval, _tick);
  }

  /// Publishes the newest coalesced value now (end of a transfer).
  void flush() {
    final next = _pending;
    _pending = null;
    if (next != null && !_closed) value = next;
  }

  /// Stops pending updates; the last value stays readable.
  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }
}

/// An image fetch's explicitly reported stage. `transfer` preserves existing
/// byte-progress behavior; it does not assert that any bytes have arrived.
enum AttachmentFetchPhase { transfer, waitingForAddress }

/// A [CancelToken] that also carries the progress sink of the fetch it
/// cancels, so loaders written against `(CancelToken) => bytes` can report
/// progress without a signature change.
class AttachmentFetchToken extends CancelToken {
  AttachmentFetchToken(this.report, {this.reportPhase});

  /// dio `onReceiveProgress` shape.
  final void Function(int received, int total) report;

  /// No address or credential is retained in a phase notification.
  final void Function(AttachmentFetchPhase)? reportPhase;
}

extension AttachmentProgressSink on CancelToken {
  void reportAttachmentPhase(AttachmentFetchPhase phase) {
    if (this case AttachmentFetchToken(:final reportPhase)) {
      reportPhase?.call(phase);
    }
  }

  /// The progress sink of an [AttachmentFetchToken]; null for plain tokens.
  void Function(int received, int total)? get progressSink {
    final token = this;
    return token is AttachmentFetchToken ? token.report : null;
  }
}
