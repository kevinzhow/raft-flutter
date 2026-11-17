import 'package:flutter/foundation.dart';

import 'attachment_limit_decision.dart';

/// A limit the person met that a plan change lifts (Web opens its upgrade
/// dialog for these; the app shows the limit notice and sends the upgrade to
/// the Web).
@immutable
class LimitNoticeRequest {
  const LimitNoticeRequest({
    required this.serverId,
    required this.gate,
    this.upload,
  });

  /// The server the limit was met on: the notice never shows on another one.
  final String? serverId;

  /// `WebBillingGate` value.
  final String gate;

  /// Set when an upload limit opened it (`upload_file_size`,
  /// `upload_monthly_quota`): the files and quota the line under the title
  /// names.
  final UploadLimitContext? upload;
}

/// Limit notices the data layer raised and the workspace shell has not shown
/// yet (`LimitNoticeHost`). A plain queue: it holds no UI.
class LimitNoticeQueue extends ChangeNotifier {
  static final _of = Expando<LimitNoticeQueue>('limitNotices');

  /// The queue of one owner (the session's uploads): created on first use.
  static LimitNoticeQueue of(Object owner) => _of[owner] ??= LimitNoticeQueue();

  /// Ends the queue of [owner] (its session closed).
  static void release(Object owner) => _of[owner]?.dispose();

  final _pending = <LimitNoticeRequest>[];

  bool get isEmpty => _pending.isEmpty;

  void add(LimitNoticeRequest request) {
    _pending.add(request);
    notifyListeners();
  }

  /// The oldest pending notice, removed; null when there is none.
  LimitNoticeRequest? take() => _pending.isEmpty ? null : _pending.removeAt(0);

  void clear() {
    if (_pending.isEmpty) return;
    _pending.clear();
    notifyListeners();
  }
}
