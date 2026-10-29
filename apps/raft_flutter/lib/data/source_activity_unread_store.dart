import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart' show canonicalUint64, ReadStateLedger;

import 'inbox_convergence.dart';
import 'raft_api_gateway.dart';
import 'resource_row_reconcile.dart';
import 'source_read_all_transport.dart';

/// Accepted session facts and notifications consumed by the inbox projection.
abstract interface class ActivityUnreadAuthority implements Listenable {
  RaftClient get client;
  RaftRecord? get server;
  List<RaftChannel> get channels;
  List<RaftChannel> get dms;
  ReadStateLedger get readState;
  SourceActivityUnreadStore get activityUnread;
  SourceActivityUnreadStore? get activityUnreadIfBound;
  Future<dynamic> sharedQuery(String path, {Map<String, dynamic>? query});
}

/// Current-server Activity attention, owned independently of the Activity page.
///
/// Source socketBridge owns boot at rooms:joined (with a two-second offline
/// fallback) and debounces live Activity ingress for 150 ms. A canonical inbox
/// response owns this total; Chat unread counters never substitute for it.
///
/// The server lists a new message in the inbox about a second after the socket
/// announces it, so a window read 150 ms after `message:new` can predate it.
/// An event therefore also records what the window must reach
/// ([InboxConvergence]) and the store reads again at 0.7 s, 1.5 s and 3 s until
/// it does.
class SourceActivityUnreadStore extends ChangeNotifier {
  SourceActivityUnreadStore(this.workspace, {required this._projectReadState}) {
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
            request.extra[sourceDoneOwnsReadRefresh] != true &&
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

  final ActivityUnreadAuthority workspace;
  final Map<String, dynamic> Function(
    Map<String, dynamic>, {
    Map<String, dynamic>? retained,
  })
  _projectReadState;
  late final StreamSubscription<RaftEvent> _subscription;
  final _pageEvents = StreamController<RaftEvent>.broadcast(sync: true);
  late final Interceptor _readObserver;
  final _readScopes = Expando<({String scope, int authority})>();
  Timer? _boot, _debounce;
  String? _scope;
  bool _started = false, _everBound = false, _disposed = false, _denied = false;
  int _revision = 0, _request = 0, _authorityEpoch = 0;
  late final _convergence = InboxConvergence(
    retry: () => unawaited(refresh()),
    now: () => clock(),
  );

  /// The time source of the freshness guard and the retry budget; tests that
  /// pump fake time replace it.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;
  DateTime? _acceptedAt;
  Future<void>? _inFlight, _trailing;
  Completer<void>? _trailingCompletion;
  List<Map<String, dynamic>> _rows = [];
  int? _total;

  /// The newest-first first-page inbox window accepted by this session, kept
  /// whole so a page opened later paints it at once (Web's single inboxStore
  /// feeds the badge and the list from the same `items`).
  Map<String, dynamic>? _window;
  int _windowSerial = 0;
  static int _serials = 0;

  static const _firstPageLimit = 30;

  /// Request shape of [windowSince], in the same form as the Activity page's
  /// list view key (path and filters, without the window).
  static final defaultInboxView = jsonEncode([
    '/channels/inbox',
    {'sort': 'desc', 'filter': 'all'},
  ]);

  /// Only facts a mounted Activity page consumes. Extra page events never
  /// activate session reads; the existing background policy stays unchanged.
  /// A page mounted without a bound store keeps its client event subscription
  /// for that mount; creating a store later does not rebind that subscription.
  Stream<RaftEvent> get pageEvents => _pageEvents.stream;

  static bool reconcilesPage(String name) =>
      name.startsWith('message:') ||
      name.startsWith('read_state:') ||
      name.startsWith('scope_read:') ||
      name.startsWith('thread:') ||
      name == 'sync:resume:response';

  static bool _pageEvent(String name) =>
      reconcilesPage(name) ||
      changesAuthority(name) ||
      const {'task:updated', 'task:created'}.contains(name);

  static bool changesAuthority(String name) => const {
    'channel:removed',
    'channel:updated',
    'channel:members-updated',
    'channel:authority-updated',
  }.contains(name);

  /// Process-wide monotonic id of the newest window this store accepted; 0
  /// before any. Pages record the id they last synchronised with.
  int get windowSerial => _windowSerial;

  /// A copy of the first-page window accepted after [serial], or null when the
  /// page already presented it (or newer) or no window is accepted.
  Map<String, dynamic>? windowSince(int serial) {
    final window = _window;
    if (!hasAcceptedWindow || window == null || _windowSerial <= serial) {
      return null;
    }
    return RaftApiGateway.copyDecoded(window) as Map<String, dynamic>;
  }

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

  /// A copy of the currently accepted server window, never raw socket rows.
  List<Map<String, dynamic>> get acceptedRows => hasAcceptedWindow
      ? [for (final row in _rows) Map<String, dynamic>.from(row)]
      : const [];

  /// Start the session's socket-driven work. Construction and borrowing only
  /// retain state; the session owner starts this at server selection or rooms.
  void start() {
    if (_disposed || _started) return;
    _started = true;
    _bind(activate: true);
  }

  static void activateForRooms(ActivityUnreadAuthority workspace) {
    if (workspace.activityUnreadIfBound == null) {
      // A restored session can join before a view or selection borrowed it.
      unawaited(workspace.activityUnread.refresh());
    } else {
      workspace.activityUnread.start();
    }
  }

  void _bind({bool activate = false}) {
    if (_disposed) return;
    final next = scope;
    if (next == _scope && !activate) return;
    if (next != _scope) {
      _revision++;
      _request++;
      _authorityEpoch++;
      _scope = next;
      _total = null;
      _rows = [];
      _window = null;
      _denied = false;
      _acceptedAt = null;
      _convergence.reset();
      _boot?.cancel();
      _debounce?.cancel();
      _inFlight = null;
      _finishTrailing();
    }
    if (!_started || next == null) return;
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
    final changed = _projectReadStateRows();
    if (previous != _scope || changed) notifyListeners();
  }

  bool _isReadWrite(RequestOptions request) =>
      request.method == 'POST' &&
      (RegExp(r'^/channels/[^/]+/read(?:-all)?$').hasMatch(request.path) ||
          request.path == '/channels/inbox/read-all');

  void _event(RaftEvent event) {
    if (_disposed) return;
    _workspaceChanged();
    final payload = event.payload;
    if (payload is Map &&
        payload['serverId'] is String &&
        payload['serverId'] != workspace.client.serverId) {
      return;
    }
    _handleEvent(event);
    if (!_disposed && _pageEvent(event.name)) _pageEvents.add(event);
  }

  /// Whether the session already owns this event's default-window refresh.
  /// Filtered and paged views still reconcile their own request shapes.
  bool _refreshes(RaftEvent event) {
    if (_disposed || !_started || _scope == null || _denied) return false;
    final payload = event.payload;
    return switch (event.name) {
      'message:new' => payload is Map && _messageRelevant(payload),
      'thread:updated' =>
        payload is Map &&
            payload['threadChannelId'] is String &&
            (payload['latestReply'] is! Map ||
                _messageRelevant(payload['latestReply'] as Map)),
      'notification_prefs:updated' => true,
      'dm:new' =>
        payload is Map && ((payload['channelId'] ?? payload['id']) is String),
      _ => false,
    };
  }

  bool ownsPageRefresh(
    RaftEvent event, {
    required String? view,
    required int loadedRows,
  }) =>
      view == defaultInboxView &&
      loadedRows <= _firstPageLimit &&
      (_refreshes(event) || event.name == 'sync:resume:response' && isFresh);

  void _handleEvent(RaftEvent event) {
    if (_scope == null || !_started) return;
    final payload = event.payload;
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
    if (!_refreshes(event)) return;
    _expect(event.name, payload);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _debounce = null;
      unawaited(refresh());
    });
  }

  /// Remember what the window read after this event has to contain.
  void _expect(String name, Object? payload) {
    if (payload is! Map) return;
    switch (name) {
      case 'message:new':
        final channel = payload['channelId'], id = payload['id'];
        if (channel is String && channel.isNotEmpty) {
          _convergence.expect(
            channel,
            messageId: id is String ? id : null,
            seq: payload['seq'],
          );
        }
      case 'thread:updated':
        final thread = payload['threadChannelId'],
            reply = payload['latestReply'];
        if (thread is String && thread.isNotEmpty && reply is Map) {
          final id = reply['id'];
          _convergence.expect(
            thread,
            messageId: id is String ? id : null,
            seq: reply['seq'],
          );
        }
      case 'dm:new':
        final channel = payload['channelId'] ?? payload['id'];
        if (channel is String && channel.isNotEmpty) {
          _convergence.expect(channel);
        }
    }
  }

  /// Read the inbox until it lists [messageId] of [channelId] (an OS
  /// notification waits for this, so that opening the app from it finds the
  /// conversation already current). Completes true as soon as an accepted
  /// window shows it, false after [timeout] or when this store cannot read.
  Future<bool> reach({
    required String channelId,
    required String messageId,
    Object? seq,
    required Duration timeout,
  }) {
    if (_disposed || !_started || _scope == null || _denied) {
      return Future.value(false);
    }
    final want = _convergence.expect(channelId, messageId: messageId, seq: seq);
    // A conversation the window keeps not listing is not waited for.
    if (want == null) return Future.value(false);
    if (hasAcceptedWindow && want.satisfiedBy(_rows)) {
      _convergence.observe(_rows);
      return Future.value(true);
    }
    // The debounce of the announcing event reads soon enough by itself.
    if (_debounce == null && _inFlight == null) unawaited(refresh());
    return _convergence.whenReached(want, timeout);
  }

  /// How long a window this store accepted counts as current for the reads a
  /// return to the foreground would otherwise repeat.
  static const freshness = Duration(seconds: 5);

  /// Whether this store is reading the inbox, or accepted a window of its own
  /// within [freshness].
  bool get isFresh {
    if (_inFlight != null) return true;
    final at = _acceptedAt;
    return at != null && clock().difference(at) < freshness;
  }

  /// Return to the foreground: read the window now, in parallel with the
  /// socket's resume handshake, unless it was read within [freshness]. Reads
  /// an event's retries still owe are not skipped: they are already due.
  Future<void> refreshOnResume() {
    if (_disposed || !_started || _scope == null || _denied) {
      return Future.value();
    }
    if (_inFlight != null) return _inFlight!;
    if (hasAcceptedWindow && isFresh) return Future.value();
    return refresh();
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
  void acceptWindow(
    Map window, {
    required String? scope,
    int? authorityEpoch,
    bool firstPage = false,
  }) {
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
    final retained = _rows;
    _rows = rows;
    _total = count;
    _projectReadStateRows(retainedRows: retained);
    if (firstPage) {
      _window = RaftApiGateway.copyDecoded({
        ...window,
        'items': _rows.take(_firstPageLimit).toList(),
        'totalUnreadCount': _total,
        'hasMore': rows.length > _firstPageLimit || window['hasMore'] == true,
      }) as Map<String, dynamic>;
      _windowSerial = ++_serials;
      _acceptedAt = clock();
    }
    _convergence.observe(rows);
    notifyListeners();
  }

  static int? _validCount(dynamic value) =>
      value is num && value.isFinite && value >= 0 && value == value.truncate()
      ? value.toInt()
      : null;
  static int _count(dynamic value) => _validCount(value) ?? 0;

  // A present authority frontier, not a thread's display/parent sequence, can
  // prove a row fully read. A complete unread ACK supplies its exact count.
  // Every consumer, including the retained first page, sees that projection.
  bool _projectReadStateRows({List<Map<String, dynamic>>? retainedRows}) {
    if (!hasAcceptedWindow) return false;
    final retained = activityRowsByReadVersion([
      if (_window?['items'] case final List items)
        ...items.whereType<Map>().map(Map<String, dynamic>.from),
      ...retainedRows ?? _rows,
    ]);
    var delta = 0, changed = false;
    final next = <Map<String, dynamic>>[];
    for (final row in _rows) {
      final projected = _projectWindowRow(
        row,
        retained: retained[activityScopeId(row)],
      );
      next.add(projected);
      if (identical(projected, row)) continue;
      changed = true;
      delta += _count(projected['unreadCount']) - _count(row['unreadCount']);
    }
    if (!changed) return false;
    _rows = next;
    _total = (_total! + delta).clamp(0, 1 << 53);
    final window = _window;
    if (window != null) {
      _window = {
        ...window,
        'items': [
          for (final row in (window['items'] as List).whereType<Map>())
            _projectWindowRow(
              Map<String, dynamic>.from(row),
              retained: retained[activityScopeId(row)],
            ),
        ],
        'totalUnreadCount': _total,
      };
      _windowSerial = ++_serials;
    }
    return true;
  }

  Map<String, dynamic> _projectWindowRow(
    Map<String, dynamic> row, {
    Map<String, dynamic>? retained,
  }) {
    if (row['kind'] == 'mention_action') return row;
    final projected = _projectReadState(row, retained: retained);
    final id = row['kind'] == 'thread'
        ? row['threadChannelId']
        : row['channelId'];
    final frontier = projected['readState'];
    if (id is! String || frontier is! Map || frontier['kind'] != 'present') {
      return projected;
    }
    final activity = frontier['latestActivity'];
    final latest = activity is Map ? canonicalUint64(activity['seq']) : null;
    final read = workspace.readState.state(
      workspace.client.serverId!,
      workspace.client.user!.id,
      id,
    );
    if (read != null &&
        activityUnreadCountOwnsCursor(
          projected,
          BigInt.from(read['maxReadSeq']),
          read['readStateVersion'] as int?,
        )) {
      return projected;
    }
    if (latest != null &&
        read != null &&
        BigInt.from(read['maxReadSeq']) >= latest &&
        _count(projected['unreadCount']) > 0) {
      return {...projected, 'unreadCount': 0};
    }
    return projected;
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
    _window = null;
    _acceptedAt = null;
    _convergence.reset();
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
    // An explicit read is also an activation. It covers the boot fallback.
    _started = true;
    _bind();
    _boot?.cancel();
    _boot = null;
    if (_scope == null || _denied) return Future.value();
    _everBound = true;
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
      // Shared with a mounted Activity page reconciling the same window.
      final value = await workspace.sharedQuery(
        '/channels/inbox',
        query: {
          'filter': 'all',
          'sort': 'desc',
          'limit': _firstPageLimit,
          'offset': 0,
        },
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
      acceptWindow(value, scope: authority, firstPage: true);
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
    _window = null;
    _total = null;
    _acceptedAt = null;
    _convergence.dispose();
    _boot?.cancel();
    _debounce?.cancel();
    _finishTrailing();
    _subscription.cancel();
    _pageEvents.close();
    workspace.removeListener(_workspaceChanged);
    workspace.client.http.interceptors.remove(_readObserver);
    super.dispose();
  }
}
