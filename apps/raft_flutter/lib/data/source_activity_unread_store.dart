import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_sync/raft_sync.dart'
    show canonicalUint64, canonicalWireSeq, ReadStateLedger;

import 'device_preferences.dart';
import 'inbox_background_refresh.dart';
import 'inbox_convergence.dart';
import 'inbox_in_place_unread.dart';
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
/// fallback). A live message first patches its listed row's unread in place
/// ([InboxInPlaceUnread], Web #244), then asks for the realtime re-read
/// through [InboxBackgroundRefresh] (leading+trailing 2.5 s, nothing while the
/// app is hidden). A canonical inbox response owns this total; Chat unread
/// counters never substitute for it.
///
/// The server lists a new message in the inbox about a second after the socket
/// announces it, so a window read 150 ms after `message:new` can predate it.
/// An event therefore also records what the window must reach
/// ([InboxConvergence]) and the store reads again at 0.7 s, 1.5 s and 3 s until
/// it does.
class SourceActivityUnreadStore extends ChangeNotifier {
  SourceActivityUnreadStore(
    this.workspace, {
    required this._projectReadState,
    this._liveUnread,
  }) {
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
          _persistedRead(request);
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
  final LiveUnread Function(Map message)? _liveUnread;
  late final StreamSubscription<RaftEvent> _subscription;
  final _pageEvents = StreamController<RaftEvent>.broadcast(sync: true);
  late final Interceptor _readObserver;
  final _readScopes = Expando<({String scope, int authority})>();
  Timer? _boot;
  final _settling = <String, Timer>{};
  final _inPlace = InboxInPlaceUnread();
  final _live = <String, LiveUnread>{};
  late final _background = InboxBackgroundRefresh(
    read: () => unawaited(refresh()),
    now: () => clock(),
  );
  String? _scope;
  bool _started = false, _everBound = false, _disposed = false, _denied = false;
  int _revision = 0, _request = 0, _authorityEpoch = 0;
  // Web's catch-up retries (1.5 s, 3 s) also read nothing while hidden; ours
  // keep their own 0.7/1.5/3 s schedule and budget.
  late final _convergence = InboxConvergence(
    retry: () {
      if (!_background.deferWhileHidden()) unawaited(refresh());
    },
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

  /// The rows the server last served, before a row patched in place was kept
  /// over its stale answer: what a convergence wait is judged against.
  List<Map<String, dynamic>> _served = [];
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
      _served = [];
      _window = null;
      _denied = false;
      _acceptedAt = null;
      _convergence.reset();
      _boot?.cancel();
      _resetBackground();
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
    _readThrough(event);
    if (!_refreshes(event)) return;
    _expect(event.name, payload);
    _patchInPlace(event);
    _background.request();
  }

  void _resetBackground() {
    _background.cancel();
    _inPlace.reset();
    _live.clear();
    for (final timer in _settling.values) {
      timer.cancel();
    }
    _settling.clear();
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

  /// The judgement of a live message ([LiveUnread]), made once per message and
  /// shared with the mounted page, which patches its own copy of the row.
  LiveUnread? liveUnreadOf(Map message) {
    final id = message['id'];
    if (id is! String) return null;
    final known = _live[id];
    if (known != null) return known;
    final judge = _liveUnread;
    if (judge == null || _denied || _scope == null) return null;
    if (_live.length >= 128) _live.remove(_live.keys.first);
    return _live[id] = judge(message);
  }

  /// Web #244: a live message patches its listed row's unread at once, in the
  /// window the badge counts and in the page's first-window seed.
  void _patchInPlace(RaftEvent event) {
    final payload = event.payload;
    final message = switch (event.name) {
      'message:new' => payload is Map ? payload : null,
      'thread:updated' =>
        payload is Map && payload['latestReply'] is Map
            ? payload['latestReply'] as Map
            : null,
      _ => null,
    };
    final live = message == null ? null : liveUnreadOf(message);
    final scope = message?['channelId'];
    final server = workspace.client.serverId, user = workspace.client.user?.id;
    if (message == null || live == null || scope is! String) return;
    final read = server == null || user == null
        ? null
        : workspace.readState.state(server, user, scope);
    final cursor = read == null ? null : BigInt.from(read['maxReadSeq']);
    final now = clock();
    InPlaceApplied? patch(List<Map<String, dynamic>> rows) =>
        _inPlace.apply(rows, message, live, now: now, readSeq: cursor);
    final shown = patch(_rows);
    final window = _window, first = window?['items'];
    final seeded = window == null || first is! List
        ? null
        : patch([
            for (final row in first.whereType<Map>())
              Map<String, dynamic>.from(row),
          ]);
    if (shown == null && seeded == null) return;
    final delta = (shown ?? seeded)!.delta;
    if (shown != null) _rows = shown.rows;
    if (seeded != null && window != null) {
      _window = {...window, 'items': seeded.rows};
    }
    _total = _total == null ? null : (_total! + delta).clamp(0, 1 << 53);
    if (_window case final Map<String, dynamic> kept?) {
      _window = {...kept, 'totalUnreadCount': _total};
      _windowSerial = ++_serials;
    }
    if (!_inPlace.noteApplied(message)) _background.request();
    notifyListeners();
  }

  /// A persisted read answered (Web registerPersistedChannelReadListener): the
  /// stale snapshot closes with a re-read, unless the row of a settled list
  /// already shows the read and `inbox_read_inplace_v1` is on.
  void _persistedRead(RequestOptions request) {
    final scope = RegExp(r'^/channels/([^/]+)/read(?:-all)?$')
        .firstMatch(request.path)
        ?.group(1);
    if (scope == null || scope == 'inbox') {
      _background.request();
      return;
    }
    final authority = _scope, epoch = _authorityEpoch;
    // The caller applies the receipt to the read state after this answer
    // returns; judge the row once it has.
    _settling[scope]?.cancel();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- one-shot, cancelled with the store; waits for the receipt's own microtasks.
    _settling[scope] = Timer(Duration.zero, () {
      _settling.remove(scope);
      if (_disposed || authority != _scope || epoch != _authorityEpoch) return;
      if (_projectReadStateRows()) notifyListeners();
      final skip = readPersistedSkipsReread(
        _rows,
        scope,
        listSettled: hasAcceptedWindow && _inFlight == null,
        flagOn: _readInplaceOn,
      );
      if (!skip) _background.request();
    });
  }

  /// `inbox_read_inplace_v1` for this server, as the rollout flags last
  /// evaluated it (default off).
  bool get _readInplaceOn {
    final client = workspace.client, server = workspace.server;
    final user = client.user?.id;
    if (server == null || user == null) return false;
    return FeatureFlagMemory.read([
          client.origin,
          user,
          server.id,
          server.string('role'),
        ], inboxReadInplaceFlagKey) ??
        false;
  }

  /// Web applyReadStateUpdate / clearActivityRowReadThrough: an accepted
  /// `read_state:updated` this client cannot project, covering the row's latest
  /// message, zeroes the Activity row. Never consumes the event.
  void _readThrough(RaftEvent event) {
    final payload = event.payload;
    final server = workspace.client.serverId, user = workspace.client.user?.id;
    if (_scope == null ||
        payload is! Map ||
        server == null ||
        user == null ||
        event.name != 'read_state:updated' &&
            event.name != 'read_state:updated_bulk') {
      return;
    }
    final updates = <String, ({BigInt read, Map update})>{};
    for (final update
        in event.name.endsWith('_bulk')
            ? (payload['scopes'] as List? ?? const [])
            : [payload]) {
      final scope = update is Map ? update['scopeId'] : null;
      final read = update is Map
          ? canonicalWireSeq(update['maxReadSeq'])
          : null;
      final accepted = scope is String
          ? workspace.readState.state(server, user, scope)
          : null;
      // Accepted: the ledger holds this very frame (consumeReadStateUpdate).
      if (accepted != null &&
          read != null &&
          accepted['readStateVersion'] == (update as Map)['readStateVersion']) {
        updates[scope as String] = (read: read, update: update);
      }
    }
    if (updates.isEmpty) return;
    var delta = 0;
    List<Map<String, dynamic>>? clear(List<Map<String, dynamic>> rows) {
      var changed = false;
      final next = [
        for (final row in rows)
          () {
            final fact = updates[activityScopeId(row)];
            final cleared = fact == null
                ? null
                : clearedByReadThrough(
                    row,
                    maxReadSeq: fact.read,
                    markedUnread: fact.update['markedUnread'] == true,
                    unreadCount: fact.update['unreadCount'] is int
                        ? fact.update['unreadCount'] as int
                        : null,
                  );
            if (cleared == null) return row;
            changed = true;
            delta +=
                _count(cleared['unreadCount']) - _count(row['unreadCount']);
            return cleared;
          }(),
      ];
      return changed ? next : null;
    }

    final rows = clear(_rows);
    final shownDelta = delta;
    delta = 0;
    final window = _window;
    final items = window?['items'];
    final seeded = items is List
        ? clear([
            for (final row in items.whereType<Map>())
              Map<String, dynamic>.from(row),
          ])
        : null;
    if (rows == null && seeded == null) return;
    if (rows != null) _rows = rows;
    final total = _total;
    if (total != null) {
      _total = (total + (rows == null ? delta : shownDelta)).clamp(0, 1 << 53);
    }
    if (window != null && seeded != null) {
      _window = {...window, 'items': seeded, 'totalUnreadCount': _total};
      _windowSerial = ++_serials;
    }
    notifyListeners();
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
    if (hasAcceptedWindow && want.satisfiedBy(_served)) {
      _convergence.observe(_served);
      return Future.value(true);
    }
    // The trailing read of the announcing event reads soon enough by itself.
    if (!_background.pending && _inFlight == null) unawaited(refresh());
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
    // A realtime read owed while hidden is paid now, fresh window or not.
    final owed = _background.takeOwed();
    if (_inFlight != null) return _inFlight!;
    if (!owed && hasAcceptedWindow && isFresh) return Future.value();
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
    final served = rawRows
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
    // A served row still behind a row patched in place keeps its unread.
    _inPlace.counted.noteServed(served, reset: firstPage);
    final kept = _inPlace.keepAhead(served, _rows, now: clock());
    final rows = kept.rows;
    final supplied = window['totalUnreadCount'];
    final served0 = supplied == null
        ? rows.fold<int>(0, (sum, row) => sum + _count(row['unreadCount']))
        : _validCount(supplied);
    final count = served0 == null || supplied == null
        ? served0
        : served0 + kept.delta;
    if (count == null) return;
    _revision++;
    final retained = _rows;
    _rows = rows;
    _served = served;
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
    _convergence.observe(served);
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
    // A live reply patched in place advances the display seq past the
    // frontier: a read covering only the frontier leaves it unread.
    final display = canonicalUint64(projected['latestActivitySeq']);
    if (latest != null &&
        read != null &&
        BigInt.from(read['maxReadSeq']) >= latest &&
        (display == null || BigInt.from(read['maxReadSeq']) >= display) &&
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
    _served = [];
    _window = null;
    _acceptedAt = null;
    _convergence.reset();
    _boot?.cancel();
    _resetBackground();
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
    _background.noteResetStarted();
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
    _served = [];
    _window = null;
    _total = null;
    _acceptedAt = null;
    _convergence.dispose();
    _boot?.cancel();
    _resetBackground();
    _finishTrailing();
    _subscription.cancel();
    _pageEvents.close();
    workspace.removeListener(_workspaceChanged);
    workspace.client.http.interceptors.remove(_readObserver);
    super.dispose();
  }
}
