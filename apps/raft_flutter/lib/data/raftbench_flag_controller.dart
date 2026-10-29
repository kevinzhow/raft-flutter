import 'dart:async';

import 'package:flutter/foundation.dart';

import 'feature_flag_client_facts.dart';
import 'raftbench_access.dart';
import 'raftbench_hosted_controller.dart' show RaftbenchRequest;

enum RaftbenchFlagState { loading, enabled, disabled, undetermined }

/// The `raftbench_overview_v0` rollout of the selected server (Web
/// `useServerFeatureFlag(RAFTBENCH_OVERVIEW_FLAG_KEY)` + the page's
/// `confirmedFlag`).
///
/// [state] is `undetermined` when the evaluation failed twice: the flag fails
/// closed for new reads, but a page that was already confirmed on stays open
/// ([pageEnabled]) with its data, and only [analysisAllowed] pauses.
///
/// One controller serves one identity (account, server, role); [identity] is
/// compared on every result so a late answer never changes another server's
/// state.
class RaftbenchFlagController extends ChangeNotifier {
  RaftbenchFlagController({
    required this.request,
    required this.identity,
    required this.serverId,
    required this.cached,
    required this.remember,
    this.retryDelay = const Duration(milliseconds: 250),
  }) {
    final known = cached();
    state = known == null
        ? RaftbenchFlagState.loading
        : known
        ? RaftbenchFlagState.enabled
        : RaftbenchFlagState.disabled;
    if (known != null) _confirmed = known;
  }

  final RaftbenchRequest request;
  final String Function() identity;
  final String? Function() serverId;

  /// The value last evaluated for this identity (this session or the device).
  final bool? Function() cached;

  /// Record a resolved value for [identity] so the next first frame is final.
  final void Function(bool enabled, String identity) remember;
  final Duration retryDelay;

  late RaftbenchFlagState state;
  bool? _confirmed;
  late final String _identity = identity();
  int _seq = 0;
  bool _disposed = false;
  DateTime? _lastRefresh;

  /// The flag is confirmed on right now: new analysis reads are allowed.
  bool get analysisAllowed => state == RaftbenchFlagState.enabled;

  /// The Settings entry shows only on a confirmed `enabled`.
  bool get navEnabled => state == RaftbenchFlagState.enabled;

  /// The page body shows: enabled, or undetermined after a confirmed enabled.
  bool get pageEnabled =>
      state == RaftbenchFlagState.enabled ||
      (state == RaftbenchFlagState.undetermined && _confirmed == true);

  bool get resolved => state != RaftbenchFlagState.loading;

  /// Evaluate. [force] ignores the 1 second spacing of focus-driven refreshes.
  Future<void> refresh({bool force = true}) async {
    final id = serverId();
    if (_disposed || id == null || identity() != _identity) return;
    final nowTime = DateTime.now();
    if (!force &&
        _lastRefresh != null &&
        nowTime.difference(_lastRefresh!).inMilliseconds < 1000) {
      return;
    }
    _lastRefresh = nowTime;
    final seq = ++_seq;
    Future<bool> evaluate() async {
      final result = await request(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(keys: [raftbenchFlagKey], serverId: id),
      );
      final rows = result is Map ? result['evaluations'] : null;
      return rows is List &&
          rows.whereType<Map>().any(
            (f) => f['key'] == raftbenchFlagKey && f['enabled'] == true,
          );
    }

    RaftbenchFlagState next;
    try {
      next = await evaluate()
          ? RaftbenchFlagState.enabled
          : RaftbenchFlagState.disabled;
    } catch (_) {
      await _pause(retryDelay);
      if (_disposed || seq != _seq) return;
      try {
        next = await evaluate()
            ? RaftbenchFlagState.enabled
            : RaftbenchFlagState.disabled;
      } catch (_) {
        next = RaftbenchFlagState.undetermined;
      }
    }
    if (_disposed || seq != _seq || identity() != _identity) return;
    if (next != RaftbenchFlagState.undetermined) {
      _confirmed = next == RaftbenchFlagState.enabled;
      remember(_confirmed!, _identity);
    }
    if (next != state) {
      state = next;
      notifyListeners();
    }
  }

  Timer? _retry;

  /// The wait before the one retry; cancelled with the controller so no timer
  /// outlives the page (the future then never completes, and nothing awaits it
  /// past [dispose]).
  Future<void> _pause(Duration delay) {
    final done = Completer<void>();
    _retry = Timer(delay, done.complete);
    return done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _seq++;
    super.dispose();
  }
}
