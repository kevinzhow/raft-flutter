import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart' show RaftCardButton;

import '../data/feature_flag_client_facts.dart';
import '../data/workspace_controller.dart';
import 'app_link_models.dart';

enum AppLinkChoice { allowing, declining, allowed, declined, failed }

enum AppLinkPhase { refreshing, preparing, holding, executing, pending }

typedef AppLinkNotice = ({
  String text,
  Map<String, Object?> args,
  String? tone,
});

typedef _OperationRecord = ({
  String messageId,
  String urlHash,
  String requestId,
  int startedAt,
  String? operationId,
  String? state,
  int revision,
});

String _urlHash(String url) => sha256.convert(utf8.encode(url)).toString();

final _stores = Expando<AppLinkStore>();

class AppLinkStore {
  AppLinkStore(this.workspace, this.scope);

  static AppLinkStore of(WorkspaceController workspace) {
    final scope = _authority(workspace);
    final current = _stores[workspace];
    if (current != null && current.scope == scope) return current;
    if (current == null) {
      workspace.services.disposeWithSession(
        () => _stores[workspace]?._dispose(),
      );
    } else {
      current._dispose();
    }
    return _stores[workspace] = AppLinkStore(workspace, scope);
  }

  static Object _authority(WorkspaceController workspace) => (
    workspace.client.generation,
    workspace.client.user?.id,
    workspace.client.serverId,
    workspace.server?.string('role'),
  );

  final WorkspaceController workspace;
  final Object scope;
  final _cache = <Object, AppLinkMessage>{};
  final _mounted = <AppLinkMessage>{};
  final _promptOwners = <(String, String), AppLinkMessage>{};
  final _choices = <String, AppLinkChoice>{};
  StreamSubscription<RaftEvent>? _hints;
  Future<bool>? _flag;
  DateTime? _readHold;
  bool _disposed = false;
  Future<Map<String, _OperationRecord>>? _journal;
  static const _journalKind = 'link-card-operations';

  RaftClient get client => workspace.client;
  bool get current => !_disposed && scope == _authority(workspace);

  Future<Map<String, _OperationRecord>> get _records =>
      _journal ??= _readRecords();

  Future<Map<String, _OperationRecord>> _readRecords() async {
    final raw = await workspace.deviceStore.read(_journalKind, '');
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: 48))
        .millisecondsSinceEpoch;
    final records = <String, _OperationRecord>{};
    if (raw is! List) return records;
    for (final row in raw.take(50).whereType<Map>()) {
      if (row
          case {
            'message_id': final String messageId,
            'url_sha256': final String urlHash,
            'client_request_id': final String requestId,
            'started_at': final int startedAt,
            'revision': final int revision,
          }
          when startedAt >= cutoff) {
        records[requestId] = (
          messageId: messageId,
          urlHash: urlHash,
          requestId: requestId,
          startedAt: startedAt,
          operationId: row['operation_id'] is String
              ? row['operation_id'] as String
              : null,
          state: row['state'] is String ? row['state'] as String : null,
          revision: revision,
        );
      }
    }
    return records;
  }

  Future<void> _saveRecord(String requestId, _OperationRecord? record) async {
    if (workspace.cache == null || !current) return;
    final records = await _records;
    if (!current) return;
    records.remove(requestId);
    if (record != null) records[requestId] = record;
    while (records.length > 50) {
      records.remove(records.keys.first);
    }
    await workspace.deviceStore.write(_journalKind, '', [
      for (final item in records.values)
        {
          'message_id': item.messageId,
          'url_sha256': item.urlHash,
          'client_request_id': item.requestId,
          'started_at': item.startedAt,
          'operation_id': item.operationId,
          'state': item.state,
          'revision': item.revision,
        },
    ]);
  }

  void _dispose() {
    _disposed = true;
    unawaited(_hints?.cancel());
    for (final entry in {..._cache.values, ..._mounted}) {
      entry.dispose();
    }
    _cache.clear();
    _mounted.clear();
    _promptOwners.clear();
  }

  void _hint(RaftEvent event) {
    if (!current || event.name != 'link_card.operation_changed') return;
    if (event.payload case {'operation_id': final String id}) {
      for (final message in _mounted) {
        for (final action in message._actions.values) {
          if (action._operationId == id) action._schedule(immediate: true);
        }
      }
    }
  }

  AppLinkMessage message(RaftMessage message, String locale) {
    final channel = _channelAuthority(message.channelId);
    final key = (
      message.channelId,
      channel,
      message.id,
      message.content,
      locale,
    );
    final entry =
        _cache.remove(key) ?? AppLinkMessage(this, message, locale, channel);
    _cache[key] = entry;
    if (_cache.length > 300) {
      final evict = _cache.keys
          .where(
            (candidate) => candidate != key && !_cache[candidate]!.attached,
          )
          .firstOrNull;
      if (evict != null) _cache.remove(evict)!.dispose();
    }
    return entry;
  }

  Object _channelAuthority(String id) {
    final channel = [
      ...workspace.channels,
      ...workspace.dms,
    ].where((candidate) => candidate.id == id).firstOrNull;
    return (channel?.joined, jsonEncode(channel?.json['channelCapabilities']));
  }

  Future<bool> get interactive => _flag ??= _readFlag();

  Future<bool> _readFlag() async {
    try {
      final response = await client.post(
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const [RaftFeatureFlags.interactiveLinkCards],
          serverId: client.serverId,
        ),
      );
      final rows = response is Map ? response['evaluations'] : null;
      return rows is List &&
          rows.any(
            (row) => switch (row) {
              {'key': RaftFeatureFlags.interactiveLinkCards, 'enabled': true} =>
                true,
              _ => false,
            },
          );
    } catch (_) {
      return false;
    }
  }

  AppLinkChoice? choice(String app) => _choices[app];

  bool ownsPrompt(AppLinkMessage message, String app) =>
      identical(_promptOwners[(message.conversation, app)], message);

  void _reassignPrompts() {
    _promptOwners.clear();
    for (final message in _mounted) {
      for (final link in message.links.values.whereType<AppLinkConsent>()) {
        _promptOwners.putIfAbsent((
          message.conversation,
          link.app.id,
        ), () => message);
      }
    }
  }

  Future<void> choose(AppLinkConsent prompt, {required bool allow}) async {
    final app = prompt.app.id;
    if (!current ||
        choice(app) == AppLinkChoice.allowing ||
        choice(app) == AppLinkChoice.declining) {
      return;
    }
    _choices[app] = allow ? AppLinkChoice.allowing : AppLinkChoice.declining;
    _notify();
    try {
      final id = Uri.encodeComponent(app);
      await client.post(
        '/integrations/clients/$id/link-preview-${allow ? 'consent' : 'decline'}',
      );
      if (!current) return;
      _choices[app] = allow ? AppLinkChoice.allowed : AppLinkChoice.declined;
      for (final message in {..._cache.values, ..._mounted}) {
        final affected = message.links.values.any((link) => link.app.id == app);
        if (!affected) continue;
        if (allow) {
          message._loaded = false;
          if (message.attached) {
            unawaited(
              message.read(force: true).then((read) {
                if (!read && message.current) {
                  message.links = Map.of(message.links)
                    ..removeWhere(
                      (_, link) => link is AppLinkConsent && link.app.id == app,
                    );
                  message.changed();
                }
              }),
            );
          }
        } else {
          message.links = Map.of(message.links)
            ..removeWhere((_, link) => link.app.id == app);
        }
      }
    } on RaftApiException catch (error) {
      if (!current) return;
      _choices[app] = error.status == 404
          ? AppLinkChoice.declined
          : AppLinkChoice.failed;
    } catch (_) {
      if (!current) return;
      _choices[app] = AppLinkChoice.failed;
    }
    _notify();
  }

  void _notify() {
    _reassignPrompts();
    for (final message in _mounted.toList()) {
      message.changed();
    }
  }
}

class AppLinkMessage extends ChangeNotifier {
  AppLinkMessage(this.store, this.message, this.locale, this.channelAuthority)
    : viewId = store.client.newRandomId();

  final AppLinkStore store;
  final RaftMessage message;
  final String locale, viewId;
  final Object channelAuthority;
  final _tickets = <String, String>{};
  final _actions = <String, AppLinkOperation>{};
  final _retries = <String, int>{};
  Map<String, AppLinkResult> links = const {};
  Timer? _readRetry;
  int _mounts = 0, _seq = 0;
  bool _loaded = false;
  bool _disposed = false;
  Future<bool>? _reading;
  bool _restored = false;
  AppLinkNotice? _notice;

  AppLinkNotice? takeNotice() {
    final next = _notice;
    _notice = null;
    return next;
  }

  bool get attached => _mounts > 0;
  String get conversation => message.threadId ?? message.channelId;
  bool get current =>
      store.current &&
      channelAuthority == store._channelAuthority(message.channelId);
  RaftClient get _client => store.client;
  String get _messagePath => '/messages/${Uri.encodeComponent(message.id)}';

  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readRetry?.cancel();
    for (final action in _actions.values) {
      action._timer?.cancel();
    }
    super.dispose();
  }

  void attach() {
    if (++_mounts > 1) return;
    store._hints ??= _client.events.listen(store._hint);
    store._mounted.add(this);
    store._reassignPrompts();
    if (!_loaded) {
      unawaited(read());
    } else {
      unawaited(_restoreOperations());
    }
    for (final operation in _actions.values) {
      operation.resume();
    }
  }

  void detach() {
    if (_disposed) return;
    if (--_mounts > 0) return;
    store._mounted.remove(this);
    store._reassignPrompts();
    _readRetry?.cancel();
    for (final operation in _actions.values) {
      operation.pause();
    }
  }

  Future<bool> read({Set<String>? urls, bool force = false}) {
    if (!current || !attached) return Future.value(false);
    if (!force && _reading != null) return _reading!;
    final seq = ++_seq;
    return _reading = _read(seq, urls).whenComplete(() {
      if (seq == _seq) _reading = null;
    });
  }

  Future<bool> _read(int seq, Set<String>? urls) async {
    try {
      final batched = await store.interactive;
      while (current && attached && seq == _seq) {
        final delay = store._readHold?.difference(DateTime.now());
        if (delay == null || delay <= Duration.zero) break;
        await Future<void>.delayed(delay);
      }
      if (!current || !attached || seq != _seq) return false;
      final tickets = {
        for (final entry in _tickets.entries)
          if (urls == null || urls.contains(entry.key)) entry.key: entry.value,
      };
      final answer = batched
          ? await _client.post(
              '$_messagePath/link-cards/read',
              data: {
                'view_instance_id': viewId,
                'locale': locale,
                'capabilities': const [
                  'card.v2',
                  'inline.v1',
                  'inline.tone.v2',
                  'button.v1',
                  'confirm.v1',
                  'undo.v1',
                  'block.v1',
                  'preview.v3',
                ],
                if (urls != null) 'urls': urls.toList(),
                if (tickets.isNotEmpty) 'tickets': tickets,
              },
            )
          : await _client.get('$_messagePath/app-link-previews');
      if (!current || seq != _seq) return false;
      final parsed = readAppLinkAnswer(answer, interactive: batched);
      final next = urls == null
          ? <String, AppLinkResult>{}
          : (Map.of(links)..removeWhere((url, _) => urls.contains(url)));
      for (final link in parsed.links.values) {
        final choice = store.choice(link.app.id);
        if (choice == AppLinkChoice.declined ||
            link is AppLinkConsent && choice == AppLinkChoice.allowed) {
          continue;
        }
        next[link.url] = link;
        if (link is AppLinkPreview) {
          final ticket = link.ticket;
          if (ticket == null) {
            _tickets.remove(link.url);
          } else {
            _tickets[link.url] = ticket;
          }
        }
      }
      links = next;
      _loaded = parsed.retrySeconds.isEmpty;
      if (!_loaded) _retry(parsed.retrySeconds);
      if (batched) unawaited(_restoreOperations());
      store._reassignPrompts();
      changed();
      return true;
    } on RaftApiException catch (error) {
      if (error.rateLimited && attached && current && seq == _seq) {
        final seconds = (error.retryAfter?.inSeconds ?? 1).clamp(1, 60);
        store._readHold = DateTime.now().add(Duration(seconds: seconds));
        _readRetry?.cancel();
        _readRetry = Timer(Duration(seconds: seconds), () {
          unawaited(read(urls: urls));
        });
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _retry(Map<String, int> retry) {
    final seconds = retry.values.reduce(
      (first, second) => first > second ? first : second,
    );
    store._readHold = DateTime.now().add(Duration(seconds: seconds));
    final urls = {
      for (final url in retry.keys)
        if ((_retries[url] = (_retries[url] ?? 0) + 1) <= 3) url,
    };
    _readRetry?.cancel();
    if (urls.isEmpty || !attached) return;
    _readRetry = Timer(Duration(seconds: seconds), () {
      unawaited(read(urls: urls));
    });
  }

  AppLinkOperation operation(String url) =>
      _actions[url] ??= AppLinkOperation(this, url);

  Future<void> _restoreOperations() async {
    if (_restored ||
        !attached ||
        links.isEmpty ||
        store.workspace.cache == null) {
      return;
    }
    _restored = true;
    final records = await store._records;
    if (!current || !attached) {
      _restored = false;
      return;
    }
    final urls = {
      for (final link in links.values.whereType<AppLinkPreview>())
        _urlHash(link.url): link.url,
    };
    for (final record in records.values.toList().reversed) {
      final url = urls[record.urlHash];
      if (record.messageId == message.id && url != null) {
        operation(url)._restore(record);
      }
    }
  }
}

typedef AppLinkConfirm = Future<bool> Function(Map description);

class AppLinkOperation {
  AppLinkOperation(this.owner, this.url);

  final AppLinkMessage owner;
  final String url;
  AppLinkPhase? phase;
  AppLinkNotice? notice;
  Timer? _timer;
  String? _operationId;
  String? _lastState;
  int _receiptRevision = -1;
  String? label;
  int undoSeconds = 0, _polls = 0;
  bool _polling = false;
  DateTime? _followSince;
  _OperationRecord? _record;

  RaftClient get _client => owner._client;
  bool get busy => phase != null;
  static const _open = {'sent', 'accepted', 'unknown', 'needs_reconciliation'};
  static const _closed = {
    'done',
    'refused',
    'failed_not_sent',
    'resolved_manually',
  };
  static const _pollSeconds = [2, 5, 15, 60];

  Future<dynamic> _post(String path, {required Map<String, Object?> data}) =>
      _client.request(
        'POST',
        path,
        data: data,
        headers: {'Accept-Language': owner.locale},
      );

  void _change(AppLinkPhase? next) {
    phase = next;
    owner.changed();
  }

  void _notice(AppLinkNotice value) {
    notice = value;
    owner._notice = value;
  }

  void undo() {
    if (phase != AppLinkPhase.holding) return;
    _timer?.cancel();
    _change(null);
  }

  Future<void> press(
    AppLinkPreview card,
    RaftCardButton button,
    AppLinkAction action,
    AppLinkConfirm confirm,
  ) async {
    if (busy || button.disabledReason != null) return;
    if (!owner.current) {
      _finish("Card actions aren't available right now.");
      return;
    }
    notice = null;
    label = button.label;
    if (action is AppLinkRefresh) {
      _change(AppLinkPhase.refreshing);
      final read = await owner.read(urls: {url}, force: true);
      _finish(read ? null : "Couldn't refresh this card. Try again.");
      return;
    }
    if (action is! AppLinkExecute || action.handle == null) return;
    if (card.readAt != null &&
        DateTime.now().difference(card.readAt!) >= const Duration(minutes: 9)) {
      _change(AppLinkPhase.refreshing);
      final read = await owner.read(urls: {url}, force: true);
      if (!read) {
        _finish("Couldn't refresh this card. Try again.");
        return;
      }
      final fresh = owner.links[url];
      if (fresh is! AppLinkPreview) {
        _finish('This card changed. Check it and try again.');
        return;
      }
      final candidate = fresh.buttons.entries.where((entry) {
        final next = entry.value;
        return next is AppLinkExecute &&
            next.id == action.id &&
            next.handle != null &&
            next.undoWindow == action.undoWindow &&
            entry.key.label == button.label &&
            entry.key.disabledReason == null;
      }).firstOrNull;
      if (candidate == null) {
        _finish('This card changed. Check it and try again.');
        return;
      }
      _change(null);
      await press(fresh, candidate.key, candidate.value, confirm);
      return;
    }
    final window = action.undoWindow;
    if (window != null) {
      var remaining = window;
      undoSeconds = (remaining.inMilliseconds / 1000).ceil();
      _change(AppLinkPhase.holding);
      void tick() {
        final step = remaining > const Duration(seconds: 1)
            ? const Duration(seconds: 1)
            : remaining;
        _timer = Timer(step, () {
          remaining -= step;
          if (remaining == Duration.zero) {
            unawaited(_execute(action.handle!));
          } else {
            undoSeconds = (remaining.inMilliseconds / 1000).ceil();
            owner.changed();
            tick();
          }
        });
      }

      tick();
      return;
    }
    _change(AppLinkPhase.preparing);
    try {
      final response = await _post(
        '/link-cards/prepare',
        data: {
          'handle': action.handle,
          'claimed': {'business_revision': card.revision},
        },
      );
      if (!owner.current || !owner.attached) {
        _finish(null);
      } else if (response case {
        'prepared_action_id': final String id,
        'prepared_digest': final String digest,
        'description': final Map description,
      }) {
        if (await confirm(description)) {
          await _execute(action.handle!, prepared: (id, digest));
        } else {
          _finish(null);
        }
      } else {
        _finish("The app couldn't prepare this action. Try again.");
      }
    } on RaftApiException catch (error) {
      await _failure(error);
    } catch (_) {
      _finish("The app couldn't prepare this action. Try again.");
    }
  }

  Future<void> _execute(String handle, {(String, String)? prepared}) async {
    if (!owner.current) {
      _finish("Card actions aren't available right now.");
      return;
    }
    owner._seq++;
    owner._reading = null;
    _change(AppLinkPhase.executing);
    final requestId = _client.newRandomId();
    _record = (
      messageId: owner.message.id,
      urlHash: _urlHash(url),
      requestId: requestId,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      operationId: null,
      state: null,
      revision: -1,
    );
    await owner.store._saveRecord(requestId, _record);
    if (!owner.current) return;
    final body = {
      'handle': handle,
      'client_request_id': requestId,
      if (prepared != null) 'prepared_action_id': prepared.$1,
      if (prepared != null) 'prepared_digest': prepared.$2,
    };
    try {
      Object? response;
      const waits = [1, 2, 4];
      for (var attempt = 0; owner.current; attempt++) {
        try {
          response = await _post('/link-cards/execute', data: body);
          break;
        } on RaftApiException catch (error) {
          final lost =
              error.status == null ||
              error.status! >= 500 ||
              error.rateLimited &&
                  (error.code == 'LOCK_TIMEOUT' ||
                      attempt > 0 && error.code == 'RATE_LIMITED');
          if (attempt >= waits.length || !lost) {
            rethrow;
          }
          final seconds = error.rateLimited
              ? (error.retryAfter?.inSeconds ?? waits[attempt]).clamp(1, 60)
              : waits[attempt];
          await Future<void>.delayed(Duration(seconds: seconds));
        }
      }
      if (!owner.current) return;
      if (response
          case {'operation_id': final String id, 'state': final String state}
          when _open.contains(state) || _closed.contains(state)) {
        _accept(id, state, refresh: true);
      } else if (response case {'state': 'not_visible'}) {
        await owner.read(urls: {url}, force: true);
        _finish("Card actions aren't available right now.");
      } else {
        await _recover(requestId: requestId);
      }
    } on RaftApiException catch (error) {
      if (owner.current && (error.status == null || error.status! >= 500)) {
        await _recover(requestId: requestId);
      } else {
        await _failure(error);
      }
    } catch (_) {
      await _recover(requestId: requestId);
    }
  }

  Future<void> _recover({String? requestId, bool quiet = false}) async {
    if (!owner.current) return;
    try {
      final response = await _client.get(
        '/link-cards/operations',
        query: requestId == null
            ? {'message_id': owner.message.id, 'url_sha256': _urlHash(url)}
            : {'client_request_id': requestId},
      );
      if (!owner.current) return;
      final records = response is Map ? response['operations'] : null;
      final eligible = records is List
          ? records.whereType<Map>().where(
              (row) =>
                  row['operation_id'] is String &&
                  row['receipt_revision'] is int &&
                  (row['receipt_revision'] as int) >= 0 &&
                  (_open.contains(row['state']) ||
                      requestId != null && _closed.contains(row['state'])),
            )
          : const <Map>[];
      final record = requestId == null
          ? eligible.lastOrNull
          : eligible.firstOrNull;
      if (record
          case {
            'operation_id': final String id,
            'state': final String state,
            'receipt_revision': final int revision,
          }
          when revision >= 0 &&
              (_open.contains(state) || _closed.contains(state))) {
        _accept(id, state, receiptRevision: revision, refresh: true);
        return;
      }
    } catch (_) {
      if (!owner.current) return;
    }
    if (quiet) {
      _change(null);
    } else {
      _finish("Couldn't run this action. Try again.");
    }
  }

  Future<void> _failure(RaftApiException error) async {
    if (!owner.current) return;
    switch (error.status) {
      case 409:
        if (error.details['operation_id'] case final String id) {
          _accept(id, 'sent');
        } else if (error.code == 'VIEW_PENDING') {
          await _recover();
        } else {
          _finish('This button was already used.');
        }
      case 410:
        await owner.read(urls: {url}, force: true);
        _finish('This card was out of date and has been refreshed. Try again.');
      case 429:
        _finish('Too many card actions. Try again in {seconds}s.', {
          'seconds': error.retryAfter?.inSeconds ?? 1,
        });
      case 404:
        _finish("Card actions aren't available right now.");
      default:
        _finish("Couldn't run this action. Try again.");
    }
  }

  void _accept(
    String id,
    String state, {
    bool refresh = false,
    int? receiptRevision,
    Object? appToast,
  }) {
    if (_operationId != id) {
      _lastState = null;
      _receiptRevision = -1;
    }
    if (receiptRevision != null) {
      if (receiptRevision <= _receiptRevision) {
        _schedule();
        return;
      }
      _receiptRevision = receiptRevision;
    }
    if (refresh) unawaited(owner.read(urls: {url}, force: true));
    final message = switch (state) {
      'sent' => 'Sent. Waiting for the app.',
      'accepted' => 'Accepted. The app is finishing it.',
      'done' => 'Done. Open the app to see the result.',
      'refused' || 'failed_not_sent' => 'The action was not carried out.',
      'unknown' || 'needs_reconciliation' => "The result isn't confirmed yet.",
      'resolved_manually' => 'The result could not be confirmed.',
      _ => null,
    };
    if (appToast case {'tone': final String tone, 'text': final String text}
        when const {'info', 'success', 'warning'}.contains(tone) &&
            text.trim().isNotEmpty &&
            text.runes.length <= 200) {
      _notice((text: text, args: const {}, tone: tone));
    } else if (message != null && _lastState != state) {
      _notice((text: message, args: const {}, tone: null));
    }
    _lastState = state;
    if (_open.contains(state)) {
      if (_operationId != id) {
        _polls = 0;
        _followSince = DateTime.now();
      }
      _operationId = id;
      if (_record case final record?) {
        _record = (
          messageId: record.messageId,
          urlHash: record.urlHash,
          requestId: record.requestId,
          startedAt: record.startedAt,
          operationId: id,
          state: state,
          revision: _receiptRevision,
        );
        unawaited(owner.store._saveRecord(record.requestId, _record));
      }
      _change(AppLinkPhase.pending);
      _schedule();
    } else {
      _finish(null);
    }
  }

  void _finish(String? message, [Map<String, Object?> params = const {}]) {
    _timer?.cancel();
    _operationId = null;
    if (_record case final record?) {
      _record = null;
      unawaited(owner.store._saveRecord(record.requestId, null));
    }
    if (message != null) _notice((text: message, args: params, tone: null));
    _change(null);
  }

  void pause() {
    if (phase == AppLinkPhase.pending) _timer?.cancel();
  }

  void resume() {
    if (phase == AppLinkPhase.pending) _schedule(immediate: true);
  }

  void _restore(_OperationRecord record) {
    if (busy) return;
    _record = record;
    if (record.operationId case final id?) {
      _operationId = id;
      _receiptRevision = record.revision;
      _lastState = record.state;
      _followSince = DateTime.fromMillisecondsSinceEpoch(record.startedAt);
      _change(AppLinkPhase.pending);
      _schedule(immediate: true);
    } else {
      _change(AppLinkPhase.pending);
      unawaited(_recover(requestId: record.requestId, quiet: true));
    }
  }

  void _schedule({bool immediate = false, Duration? retryAfter}) {
    _timer?.cancel();
    if (!owner.attached || !owner.current || _polling) return;
    if (DateTime.now().difference(_followSince!) >= const Duration(hours: 24)) {
      _finish("The result isn't confirmed yet.");
      return;
    }
    final cadence = _polls < _pollSeconds.length ? _pollSeconds[_polls] : 300;
    Future<void> poll() async {
      final id = _operationId;
      if (id == null || !owner.current || !owner.attached) return;
      _polls++;
      _polling = true;
      try {
        final response = await _post(
          '/link-cards/status',
          data: {'operation_id': id},
        );
        _polling = false;
        if (!owner.current || _operationId != id) return;
        if (response
            case {
              'operation_id': final String receiptId,
              'state': final String state,
            }
            when receiptId == id) {
          if (state == 'not_visible') {
            unawaited(owner.read(urls: {url}, force: true));
            _finish(null);
            return;
          }
          if (response case {'receipt_revision': final int revision}
              when revision >= 0 &&
                  (_open.contains(state) || _closed.contains(state))) {
            final result = response['app_result'];
            _accept(
              id,
              state,
              receiptRevision: revision,
              appToast: result is Map ? result['toast'] : null,
              refresh: _closed.contains(state),
            );
            return;
          }
        }
      } on RaftApiException catch (error) {
        _polling = false;
        if (!owner.current || _operationId != id) return;
        if (error.status == 404) {
          _finish(null);
          return;
        }
        if (error.rateLimited) {
          _schedule(retryAfter: error.retryAfter);
          return;
        }
      } catch (_) {
        _polling = false;
        if (!owner.current || _operationId != id) return;
      }
      _schedule();
    }

    if (immediate) {
      unawaited(poll());
    } else {
      _timer = Timer(retryAfter ?? Duration(seconds: cadence), poll);
    }
  }
}
