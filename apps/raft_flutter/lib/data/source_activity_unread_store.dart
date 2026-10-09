import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show canonicalUint64;

import 'workspace_controller.dart';

/// Current-server Activity attention, owned independently of the Activity page.
///
/// Source socketBridge owns boot at rooms:joined (with a two-second offline
/// fallback) and debounces live Activity ingress for 150 ms. A canonical inbox
/// response owns this total; Chat unread counters never substitute for it.
class SourceActivityUnreadStore extends ChangeNotifier {
  SourceActivityUnreadStore(this.workspace) {
    workspace.addListener(_workspaceChanged);
    _subscription = workspace.client.events.listen(_event);
    _readObserver = InterceptorsWrapper(
      onRequest: (request, next) {
        final requestScope = scope;
        if (_isReadWrite(request) &&
            request.headers['X-Server-Id'] == workspace.client.serverId &&
            requestScope != null) {
          _readScopes[request] = (
            scope: requestScope,
            authority: _authorityEpoch,
          );
        }
        next.next(request);
      },
      onResponse: (response, next) {
        final request = response.requestOptions;
        final requestScope = _readScopes[request];
        if (_isReadWrite(request) &&
            requestScope != null &&
            requestScope.scope == scope &&
            requestScope.authority == _authorityEpoch &&
            (hasAcceptedWindow || _inFlight != null) &&
            !_denied) {
          // Source registerPersistedChannelReadListener closes stale snapshots
          // only after a successful persisted read in the same authority.
          unawaited(refresh());
        }
        next.next(response);
      },
    );
    workspace.client.http.interceptors.add(_readObserver);
    _bind();
  }

  final WorkspaceController workspace;
  late final StreamSubscription<RaftEvent> _subscription;
  late final Interceptor _readObserver;
  final _readScopes = Expando<({String scope, int authority})>();
  Timer? _boot, _debounce;
  String? _scope;
  bool _everBound = false, _disposed = false, _denied = false;
  int _revision = 0, _request = 0, _authorityEpoch = 0;
  Future<void>? _inFlight, _trailing;
  Completer<void>? _trailingCompletion;
  List<Map<String, dynamic>> _rows = [];
  int? _total;

  String? _currentScope() {
    final client = workspace.client;
    final server = workspace.server;
    if (!client.signedIn ||
        client.user?.id.isEmpty != false ||
        server == null ||
        client.serverId != server.id) {
      return null;
    }
    return jsonEncode([
      client.origin,
      client.generation,
      client.user!.id,
      server.id,
      server.string('role'),
      server.json['capabilities'],
      server.json['membership'],
    ]);
  }

  /// Capture this authority when accepting an independently loaded page window.
  String? get scope => _currentScope();
  int get authorityEpoch => _authorityEpoch;
  bool get hasAcceptedWindow =>
      !_disposed && _scope == scope && _total != null && !_denied;
  int? get totalUnreadCount => hasAcceptedWindow ? _total : null;
  bool get hasAttention => (totalUnreadCount ?? 0) > 0;

  void _bind() {
    if (_disposed) return;
    final next = scope;
    if (next == _scope) return;
    _revision++;
    _request++;
    _authorityEpoch++;
    _scope = next;
    _total = null;
    _rows = [];
    _denied = false;
    _boot?.cancel();
    _debounce?.cancel();
    _inFlight = null;
    _finishTrailing();
    if (next == null) return;
    if (_everBound) {
      // Source Sidebar server-switch reset; this is not a connect-time fetch.
      unawaited(refresh());
    } else {
      _everBound = true;
      _boot = Timer(const Duration(seconds: 2), () {
        _boot = null;
        unawaited(refresh());
      });
    }
  }

  void _workspaceChanged() {
    if (_disposed) return;
    final previous = _scope;
    _bind();
    final changed = _projectFullyReadRows();
    if (previous != _scope || changed) notifyListeners();
  }

  bool _isReadWrite(RequestOptions request) =>
      request.method == 'POST' &&
      (RegExp(r'^/channels/[^/]+/read(?:-all)?$').hasMatch(request.path) ||
          request.path == '/channels/inbox/read-all');

  void _event(RaftEvent event) {
    if (_disposed) return;
    _workspaceChanged();
    if (_scope == null) return;
    final payload = event.payload;
    if (payload is Map &&
        payload['serverId'] is String &&
        payload['serverId'] != workspace.client.serverId) {
      return;
    }
    if (event.name == 'session:ended' ||
        event.name == 'server:membership-removed' &&
            payload is Map &&
            payload['serverId'] == workspace.client.serverId ||
        event.name == 'connection:error' &&
            payload is Map &&
            payload['notServerMember'] == true) {
      deny(scope: _scope);
      return;
    }
    if (event.name == 'rooms:joined') {
      _boot?.cancel();
      _boot = null;
      _denied = false;
      unawaited(refresh());
      return;
    }
    if (_denied) return;
    final relevant = switch (event.name) {
      'message:new' => payload is Map && _messageRelevant(payload),
      'thread:updated' =>
        payload is Map &&
            payload['threadChannelId'] is String &&
            (payload['latestReply'] is! Map ||
                _messageRelevant(payload['latestReply'] as Map)),
      'dm:new' =>
        payload is Map && ((payload['channelId'] ?? payload['id']) is String),
      _ => false,
    };
    if (!relevant) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _debounce = null;
      unawaited(refresh());
    });
  }

  bool _messageRelevant(Map message) {
    final id = message['channelId'];
    if (id is! String || id.isEmpty) return false;
    final mentions = message['mentions'];
    if (mentions is List &&
        mentions.whereType<Map>().any(
          (m) =>
              (m['type'] ?? m['targetType']) == 'user' &&
              (m['id'] ?? m['targetId']) == workspace.client.user?.id,
        )) {
      return true;
    }
    final context = message['conversationContext'];
    if (context is Map && context['channelType'] == 'thread') return true;
    final candidates = [...workspace.channels, ...workspace.dms];
    final channel = candidates.where((c) => c.id == id).firstOrNull;
    if (channel?.json['activityMuted'] != true) return true;
    final from = num.tryParse('${channel?.json['muteFromSeq']}');
    final seq = num.tryParse('${message['seq']}');
    return from != null && from.isFinite && seq != null && seq < from;
  }

  /// Accept the actual Activity DTO, including its server-wide total when the
  /// page is filtered. This also supersedes an older background count response.
  void acceptWindow(Map window, {required String? scope, int? authorityEpoch}) {
    _bind();
    if (_disposed ||
        _denied ||
        scope == null ||
        scope != _scope ||
        authorityEpoch != null && authorityEpoch != _authorityEpoch) {
      return;
    }
    final rawRows = window['items'];
    if (rawRows is! List) return;
    final rows = rawRows
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    final supplied = window['totalUnreadCount'];
    final count = supplied == null
        ? rows.fold<int>(0, (sum, row) => sum + _count(row['unreadCount']))
        : _validCount(supplied);
    if (count == null) return;
    _revision++;
    _rows = rows;
    _total = count;
    _projectFullyReadRows();
    notifyListeners();
  }

  static int? _validCount(dynamic value) =>
      value is num && value.isFinite && value >= 0 && value == value.truncate()
      ? value.toInt()
      : null;
  static int _count(dynamic value) => _validCount(value) ?? 0;

  // A present authority frontier, not a thread's display/parent sequence, can
  // prove a row fully read. Partial/missing frontiers retain the accepted count
  // until canonical reconciliation; they never invent an unread projection.
  bool _projectFullyReadRows() {
    if (!hasAcceptedWindow) return false;
    var delta = 0;
    for (final row in _rows) {
      if (row['kind'] == 'mention_action') continue;
      final id = row['kind'] == 'thread'
          ? row['threadChannelId']
          : row['channelId'];
      final frontier = row['readState'];
      if (id is! String || frontier is! Map || frontier['kind'] != 'present') {
        continue;
      }
      final activity = frontier['latestActivity'];
      final latest = activity is Map ? canonicalUint64(activity['seq']) : null;
      final read = workspace.readState.state(
        workspace.client.serverId!,
        workspace.client.user!.id,
        id,
      );
      if (latest == null ||
          read == null ||
          BigInt.from(read['maxReadSeq']) < latest) {
        continue;
      }
      delta += _count(row['unreadCount']);
      row['unreadCount'] = 0;
    }
    if (delta == 0) return false;
    _total = (_total! - delta).clamp(0, _total!);
    return true;
  }

  void deny({required String? scope, int? authorityEpoch}) {
    if (_disposed ||
        scope == null ||
        scope != _scope ||
        scope != this.scope ||
        authorityEpoch != null && authorityEpoch != _authorityEpoch) {
      return;
    }
    _revision++;
    _request++;
    _authorityEpoch++;
    _denied = true;
    _total = null;
    _rows = [];
    _boot?.cancel();
    _debounce?.cancel();
    _inFlight = null;
    _finishTrailing();
    notifyListeners();
  }

  /// Coalesce one trailing background reset, rather than invalidate the ready
  /// response of a request already in flight (Source inboxStore906–944).
  Future<void> refresh() {
    if (_disposed) return Future.value();
    _bind();
    if (_scope == null || _denied) return Future.value();
    if (_inFlight != null) {
      _trailingCompletion ??= Completer<void>();
      return _trailing ??= _trailingCompletion!.future;
    }
    final authority = _scope!;
    final revision = _revision;
    final request = ++_request;
    final pending = _load(authority, revision, request);
    _inFlight = pending;
    return pending;
  }

  Future<void> _load(String authority, int revision, int request) async {
    final readGeneration = workspace.readState.generation;
    try {
      final value = await workspace.client.get(
        '/channels/inbox',
        query: {'filter': 'all', 'sort': 'desc', 'limit': 30, 'offset': 0},
      );
      if (_disposed ||
          authority != scope ||
          request != _request ||
          revision != _revision ||
          readGeneration != workspace.readState.generation ||
          _denied ||
          value is! Map) {
        return;
      }
      acceptWindow(value, scope: authority);
    } catch (error) {
      if (!_disposed &&
          authority == scope &&
          request == _request &&
          revision == _revision &&
          error is RaftApiException &&
          [401, 403].contains(error.status)) {
        deny(scope: authority);
      }
      // Source transient errors retain the last accepted server window/count.
    } finally {
      if (!_disposed && request == _request) {
        _inFlight = null;
        final completion = _trailingCompletion;
        _trailing = null;
        _trailingCompletion = null;
        if (completion != null) {
          await refresh();
          if (!completion.isCompleted) completion.complete();
        }
      }
    }
  }

  void _finishTrailing() {
    final completion = _trailingCompletion;
    _trailingCompletion = null;
    _trailing = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rows = [];
    _total = null;
    _boot?.cancel();
    _debounce?.cancel();
    _finishTrailing();
    _subscription.cancel();
    workspace.removeListener(_workspaceChanged);
    workspace.client.http.interceptors.remove(_readObserver);
    super.dispose();
  }
}
