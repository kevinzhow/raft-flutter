import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

typedef _Account = (String, int);

class FeedbackUnreadState extends ChangeNotifier {
  FeedbackUnreadState._(this.workspace) {
    workspace.addListener(_syncAccount);
    workspace.resumes.addListener(_onShow);
    _events = workspace.client.events.listen(_onEvent);
    _syncAccount();
  }

  static final _states = Expando<FeedbackUnreadState>();

  static FeedbackUnreadState of(WorkspaceController workspace) {
    final source = workspace.presentationSource;
    if (source != null) return of(source);
    return _states[workspace] ??= _attach(workspace);
  }

  static FeedbackUnreadState _attach(WorkspaceController workspace) {
    final state = FeedbackUnreadState._(workspace);
    workspace.services.disposeWithSession(state.dispose);
    return state;
  }

  final WorkspaceController workspace;
  late final StreamSubscription<RaftEvent> _events;
  final _retry = RaftIdleTimer(yieldToAnimation: false);
  DateTime? _freshAt, _notBefore;
  _Account? _owner;
  Object? _pending;
  int _count = 0, _revision = 0, _failures = 0, _consumers = 0;
  bool _oweRead = false, _disposed = false;

  _Account? get _account {
    final client = workspace.client;
    final id = client.user?.id;
    return id == null ? null : (id, client.authenticationGeneration);
  }

  int get count => _owner == _account ? _count : 0;

  VoidCallback retain() {
    if (++_consumers == 1) unawaited(refresh());
    return () {
      if (_disposed || --_consumers != 0) return;
      _retry.cancel();
      _pending = null;
    };
  }

  void _syncAccount() {
    final account = _account;
    if (_owner == account) return;
    _owner = account;
    _pending = null;
    _freshAt = null;
    _count = 0;
    _revision++;
    _oweRead = false;
    _resetBackoff();
    notifyListeners();
    unawaited(refresh());
  }

  void _onEvent(RaftEvent event) {
    _syncAccount();
    if (event.name == 'connected') {
      unawaited(refresh());
    } else if (event.name == 'product_feedback:unread') {
      final payload = event.payload;
      if (payload
          case {'userId': final String id, 'unreadTotal': final int count}
          when id == _owner?.$1 && _validCount(count)) {
        _cancelRetry();
        _accept(count);
      }
    }
  }

  void _onShow() {
    final fresh = _freshAt;
    if (_oweRead ||
        fresh == null ||
        DateTime.now().difference(fresh) >= const Duration(minutes: 30)) {
      unawaited(refresh());
    }
  }

  bool _validCount(Object? value) =>
      value is int && value >= 0 && value <= 9007199254740991;

  void _accept(int count) {
    _freshAt = DateTime.now();
    _oweRead = false;
    _revision++;
    if (_count == count) return;
    _count = count;
    notifyListeners();
  }

  ValueChanged<int> capture({required bool list}) {
    final owner = _account, revision = _revision;
    return (count) {
      if (_disposed ||
          owner == null ||
          _owner != owner ||
          _account != owner ||
          (list && revision != _revision) ||
          !_validCount(count)) {
        return;
      }
      _resetBackoff();
      _accept(count);
    };
  }

  Future<void> refresh() async {
    final owner = _owner;
    if (_disposed ||
        _consumers == 0 ||
        owner == null ||
        owner != _account ||
        _pending != null) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused) {
      _oweRead = true;
      return;
    }
    final notBefore = _notBefore;
    if (notBefore != null && DateTime.now().isBefore(notBefore)) {
      _scheduleRetry();
      return;
    }
    final request = Object();
    _pending = request;
    _oweRead = false;
    final revision = _revision;
    bool current() =>
        !_disposed && identical(_pending, request) && owner == _account;
    try {
      final page = await RaftClient.runFresh(
        () => workspace.client.getForAccount(
          '/product-feedback/tickets',
          query: {'limit': 1, 'degraded_ok': 1},
        ),
      );
      if (!current() || revision != _revision) return;
      if (page case {'degraded': true}) {
        final hint = page['retry_after_seconds'];
        _backOff(
          hint is num && hint.isFinite && hint > 0
              ? Duration(seconds: math.min(hint.ceil(), 600))
              : null,
        );
      } else if (page case {'unread_total': final int count}
          when _validCount(count)) {
        _resetBackoff();
        _accept(count);
      } else {
        _backOff(null);
      }
    } catch (error) {
      if (current() && revision == _revision) {
        if (error is RaftApiException && error.staleScope) {
          _oweRead = true;
        } else {
          _backOff(error is RaftApiException ? error.retryAfter : null);
        }
      }
    } finally {
      if (identical(_pending, request)) _pending = null;
    }
  }

  void _cancelRetry() => _retry.cancel();

  void _resetBackoff() {
    _cancelRetry();
    _failures = 0;
    _notBefore = null;
  }

  void _backOff(Duration? hint) {
    final seconds = math.min(600, 60 << math.min(_failures++, 4));
    _notBefore = DateTime.now().add(
      Duration(seconds: math.min(600, math.max(seconds, hint?.inSeconds ?? 0))),
    );
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retry.isActive) return;
    _retry.start(_notBefore!.difference(DateTime.now()), () {
      unawaited(refresh());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRetry();
    unawaited(_events.cancel());
    workspace.resumes.removeListener(_onShow);
    workspace.removeListener(_syncAccount);
    super.dispose();
  }
}
