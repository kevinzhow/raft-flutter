import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';

import 'desktop_windows.dart';
import 'desktop_cache_scope.dart';
import '../data/workspace_cache.dart';
import 'desktop_drafts.dart';

const _host = MethodChannel('app.raft/desktop-window');

/// Called before session/cache bootstrap. Native-created engines are identified
/// through the plugin, not a caller-supplied URL or arbitrary CLI arguments.
Future<DesktopWindows?> initializeDesktopWindows(List<String> arguments) async {
  if (kIsWeb ||
      !const {
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform)) {
    return null;
  }
  final current = await WindowController.fromCurrentEngine();
  // QA-only metadata; never reads sessions, arguments or business state.
  if (const bool.fromEnvironment('RAFT_MULTIWINDOW_QA')) {
    unawaited(
      _host
          .invokeMethod<bool>('qaWindowIdentity', current.windowId)
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }
  if (current.arguments.isEmpty) {
    late final StreamSubscription<void> changes;
    var windowSequence = 0;
    Future<Set<String>> observeWindows() async {
      final sequence = ++windowSequence;
      final windows = await WindowController.getAll();
      if (sequence != windowSequence) throw const RaftApiException.staleScope();
      return windows.map((w) => w.windowId).toSet();
    }

    final broker = DesktopSessionBroker(
      createWindow: _create,
      createCache: DesktopOwnedCache.create,
      observeWindows: observeWindows,
      focusPrimary: () => _host.invokeMethod<void>('focus'),
      releaseNative: () => changes.cancel(),
    );
    changes = onWindowsChanged.listen((_) {
      unawaited(
        observeWindows().then(broker.removeClosed, onError: (Object _) {}),
      );
    });
    _host.setMethodCallHandler(
      (call) async => call.method == 'prepareClose'
          ? broker.prepareExit()
          : throw MissingPluginException(),
    );
    return broker;
  }
  late final Map value;
  try {
    final decoded = jsonDecode(current.arguments);
    if (decoded is! Map ||
        decoded['v'] != 1 ||
        decoded['binding'] is! String ||
        decoded['server'] is! String ||
        decoded['slug'] is! String ||
        decoded.length != 4) {
      throw const FormatException();
    }
    value = decoded;
  } catch (_) {
    await _host.invokeMethod<void>('forceClose');
    throw const FormatException('Invalid desktop window route.');
  }
  final child = _ChildWindows(value['binding'], value['server'], value['slug']);
  try {
    await child.start();
  } catch (_) {
    await _host.invokeMethod<void>('forceClose');
    rethrow;
  }
  _host.setMethodCallHandler(
    (call) async => call.method == 'prepareClose'
        ? child.prepareExit()
        : throw MissingPluginException(),
  );
  try {
    final lease = await child._invoke('cacheLease');
    if (lease is! Map) {
      throw const FormatException('Invalid desktop cache lease.');
    }
    await DesktopCacheScope.initializeChild(lease);
  } catch (_) {
    await child.dispose();
    rethrow;
  }
  return child;
}

Future<DesktopWindowPeer> _create(
  String binding,
  RaftRecord server,
  DesktopSessionBroker broker,
) async {
  final channel = WindowMethodChannel(
    'app.raft/session/$binding',
    mode: ChannelMode.bidirectional,
  );
  final ready = Completer<void>();
  await channel.setMethodCallHandler((call) async {
    try {
      switch (call.method) {
        case 'cacheLease':
          return await broker.cacheLease(binding);
        case 'read':
          final snapshot = broker.snapshot(binding);
          return _encode(snapshot);
        case 'ready':
          broker.snapshot(binding);
          if (!ready.isCompleted) ready.complete();
          return null;
        case 'refresh':
          if (call.arguments is! int) throw const FormatException();
          return _encode(await broker.refresh(binding, call.arguments));
        case 'end':
          final reason = SessionEndReason.values
              .where((r) => r.name == call.arguments)
              .single;
          await broker.end(binding, reason);
          return null;
        case 'user':
          return _encode(await broker.synchronizeUser(binding));
        case 'draftRead':
        case 'draftWrite':
          final args = call.arguments;
          if (args is! List ||
              args.length != (call.method == 'draftRead' ? 5 : 6) ||
              args.take(5).any((v) => v is! String)) {
            throw const FormatException();
          }
          if (call.method == 'draftRead') {
            return await broker.readDraft(
              binding,
              args[0],
              args[1],
              args[2],
              args[3],
              args[4],
            );
          }
          await broker.writeDraft(
            binding,
            args[0],
            args[1],
            args[2],
            args[3],
            args[4],
            args[5],
          );
          return null;
        case 'bind':
          await broker.bindServer(binding, call.arguments as String?);
          return null;
        case 'open':
          final snapshot = broker.snapshot(binding);
          final serverId = call.arguments;
          if (serverId is! String || snapshot.principal == null) {
            throw const FormatException();
          }
          await broker.openFromWindow(binding, RaftRecord({'id': serverId}));
          return null;
        default:
          throw MissingPluginException();
      }
    } on DesktopWindowAlreadyOpen {
      throw PlatformException(code: 'desktop_window_already_open');
    } on RaftApiException catch (error) {
      throw PlatformException(
        code: 'raft_api',
        // ignore: raft_lints/avoid_caught_exception_text -- Serializes the typed API server message over paired native IPC; never renders or stringifies an exception.
        message: error.message,
        details: {
          'status': error.status,
          'stale': error.staleScope,
          'retryAfter': error.retryAfter?.inMilliseconds,
        },
      );
    }
  });
  try {
    final window = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({
          'v': 1,
          'binding': binding,
          'server': server.id,
          'slug': server.string('slug'),
        }),
      ),
    );
    return _NativePeer(window, channel, ready.future);
  } catch (_) {
    await channel.setMethodCallHandler(null);
    rethrow;
  }
}

Map<String, dynamic> _encode(SharedSessionSnapshot snapshot) => {
  'origin': snapshot.origin,
  'epoch': snapshot.epoch,
  'revision': snapshot.revision,
  'credentialRevision': snapshot.credentialRevision,
  'session': snapshot.session.toJson(),
};

SharedSessionSnapshot _decode(dynamic value) {
  if (value is! Map ||
      value['origin'] is! String ||
      value['epoch'] is! String ||
      value['revision'] is! int ||
      value['credentialRevision'] is! int ||
      value['session'] is! Map) {
    throw const FormatException('Invalid desktop session handoff.');
  }
  final session = Session.fromJson(Map<String, dynamic>.from(value['session']));
  if (session.cachedUser?['id'] is! String ||
      session.accessToken.isEmpty ||
      session.refreshToken.isEmpty) {
    throw const FormatException();
  }
  return SharedSessionSnapshot(
    origin: value['origin'],
    epoch: value['epoch'],
    revision: value['revision'],
    credentialRevision: value['credentialRevision'],
    session: session,
  );
}

class _NativePeer implements DesktopWindowPeer {
  _NativePeer(this.window, this.channel, this.ready);
  final Future<void> ready;
  final WindowController window;
  final WindowMethodChannel channel;
  @override
  String get id => window.windowId;
  @override
  Future<void> focus() async {
    // The first native frame is accepted only after a paired read and the
    // root has released its startup frame; no blank or wrong-theme flash.
    // A read is possible only after the second native engine has registered
    // its paired handler. Reuse must not quietly focus a dead engine.
    await ready.timeout(const Duration(seconds: 20));
    await window.show();
    await channel
        .invokeMethod<void>('focus')
        .timeout(const Duration(seconds: 5));
  }

  @override
  Future<bool> prepareClose() async =>
      await channel
          .invokeMethod<bool>('prepareClose')
          .timeout(const Duration(seconds: 7), onTimeout: () => false) ==
      true;
  @override
  Future<void> cancelClose() async => channel
      .invokeMethod<void>('cancelClose')
      .timeout(const Duration(seconds: 2));

  @override
  Future<void> close() async {
    try {
      await channel
          .invokeMethod<void>('close')
          .timeout(const Duration(seconds: 3));
    } finally {
      await channel.setMethodCallHandler(null);
    }
  }

  @override
  Future<void> publish(SharedSessionSnapshot? snapshot) => channel
      .invokeMethod<void>(
        'session',
        snapshot == null ? null : _encode(snapshot),
      )
      .timeout(const Duration(seconds: 3));
}

class _ChildWindows implements DesktopWindows, SharedSessionAuthority {
  _ChildWindows(this.binding, this.serverId, this.slug)
    : channel = WindowMethodChannel(
        'app.raft/session/$binding',
        mode: ChannelMode.bidirectional,
      );
  final String binding, serverId, slug;
  final WindowMethodChannel channel;
  final _changes = StreamController<SharedSessionSnapshot?>.broadcast();
  SharedSessionSnapshot? _snapshot;
  Timer? _heartbeat;
  StreamSubscription<void>? _windows;
  bool _closed = false;
  String? _boundServer;
  bool _startupResolved = false;
  Future<bool> Function()? _prepareClose;
  void Function()? _cancelClose;
  @override
  void cancelClose() {
    if (_closed) return;
    DesktopCacheScope.resume();
    _cancelClose?.call();
  }

  @override
  late final WorkspaceCache draftCache = DesktopDraftCache(
    readRecord: (origin, principal, server, kind, id) =>
        _invoke('draftRead', [origin, principal, server, kind, id]),
    writeRecord: (origin, principal, server, kind, id, value) async =>
        _invoke<void>('draftWrite', [
          origin,
          principal,
          server,
          kind,
          id,
          value,
        ]),
  );
  @override
  Future<void> retireDrafts() async {}
  @override
  Future<bool> prepareExit() async {
    final accepted = await _prepareClose?.call() == true;
    if (accepted) DesktopCacheScope.retire();
    return accepted;
  }

  @override
  bool get isChild => true;
  @override
  String? get origin => _snapshot?.origin;
  @override
  String get navigationNamespace => binding;
  @override
  String? get startupServerId => _startupResolved ? null : serverId;
  @override
  Uri get initialLocation => Uri(pathSegments: ['', 's', slug]);
  @override
  SharedSessionAuthority get sessionAuthority => this;
  @override
  Stream<SharedSessionSnapshot?> get changes => _changes.stream;

  Future<T?> _invoke<T>(String method, [dynamic value]) async {
    try {
      return await channel.invokeMethod<T>(method, value);
    } on WindowChannelException catch (error) {
      if (error.code == 'desktop_window_already_open') {
        throw const DesktopWindowAlreadyOpen();
      }
      if (error.code != 'raft_api') rethrow;
      final details = error.details is Map ? error.details as Map : const {};
      if (details['stale'] == true) throw const RaftApiException.staleScope();
      throw RaftApiException(
        // ignore: raft_lints/avoid_caught_exception_text -- Reconstructs only the primary broker's typed raft_api envelope; no exception object or diagnostic text reaches UI.
        error.message,
        status: details['status'] as int?,
        retryAfter: details['retryAfter'] is int
            ? Duration(milliseconds: details['retryAfter'])
            : null,
      );
    }
  }

  Future<void> start() async {
    Future<dynamic> handle(MethodCall call) async {
      switch (call.method) {
        case 'session':
          if (call.arguments == null) {
            await _revoke();
            return null;
          }
          _accept(_decode(call.arguments));
          return null;
        case 'cancelClose':
          cancelClose();
          return null;
        case 'prepareClose':
          return await _prepareClose?.call() == true;
        case 'focus':
          return _host.invokeMethod<void>('focus');
        case 'close':
          return _revoke();
        default:
          throw MissingPluginException();
      }
    }

    await channel.setMethodCallHandler(handle);
    _accept(_decode(await _invoke('read')));
    _windows = onWindowsChanged.listen((_) {
      // In particular, loss of the primary engine must retire children now.
      // A hidden-but-live macOS primary still answers its paired channel.
      unawaited(read().then<void>((_) {}, onError: (Object _) => _revoke()));
    });
    // ignore: raft_lints/avoid_unreviewed_idle_work -- One bounded native ownership probe per ten seconds, with a five-second timeout and no HTTP polling; revocation/dispose cancels it.
    _heartbeat = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(
        read().then<void>((_) {}, onError: (Object _) => _revoke()),
      ),
    );
  }

  void _accept(SharedSessionSnapshot next) {
    final before = _snapshot;
    if (_closed ||
        before != null &&
            (next.epoch != before.epoch ||
                next.principal != before.principal ||
                next.origin != before.origin)) {
      throw const RaftApiException.staleScope();
    }
    if (before != null && next.revision < before.revision) return;
    _snapshot = next;
    _changes.add(next);
  }

  @override
  Future<SharedSessionSnapshot?> read() async {
    if (_closed) return null;
    try {
      final next = _decode(
        await _invoke('read').timeout(const Duration(seconds: 5)),
      );
      _accept(next);
      return _snapshot;
    } catch (_) {
      await _revoke();
      rethrow;
    }
  }

  @override
  Future<SharedSessionSnapshot> refresh(int revision) async {
    try {
      final value = await _invoke(
        'refresh',
        revision,
      ).timeout(const Duration(seconds: 45));
      _accept(_decode(value));
      return _snapshot!;
    } catch (_) {
      // A network failure keeps credentials; a missing broker retires them.
      // The next heartbeat validates ownership independently of HTTP recovery.
      rethrow;
    }
  }

  @override
  Future<SharedSessionSnapshot> synchronizeUser() async {
    _accept(_decode(await _invoke('user')));
    return _snapshot!;
  }

  @override
  Future<void> end(SessionEndReason reason) async {
    if (_closed) return;
    try {
      await _invoke<void>('end', reason.name);
    } finally {
      await _revoke();
    }
  }

  @override
  void bind(
    RaftClient? client,
    String? serverId, {
    Future<void> Function()? onLogout,
    WorkspaceCache? cache,
    Future<bool> Function()? prepareClose,
    void Function()? cancelClose,
  }) {
    _prepareClose = prepareClose;
    _cancelClose = cancelClose;
    if (_closed || _boundServer == serverId) return;
    _boundServer = serverId;
    if (serverId != null) _startupResolved = true;
    unawaited(
      channel
          .invokeMethod<void>('bind', serverId)
          .catchError((Object _) => _revoke()),
    );
  }

  @override
  Future<void> selectServer(String serverId) async {
    await _invoke<void>('bind', serverId);
    _boundServer = serverId;
  }

  @override
  Future<void> openServer(RaftRecord server) =>
      channel.invokeMethod<void>('open', server.id);

  Future<void> _revoke() async {
    if (_closed) return;
    _closed = true;
    DesktopCacheScope.retire();
    _snapshot = null;
    _heartbeat?.cancel();
    unawaited(_windows?.cancel());
    _changes.add(null);
    try {
      await _host.invokeMethod<void>('forceClose');
    } on MissingPluginException {
      /* No native host in isolated tests. */
    }
  }

  @override
  Future<void> frameReady() async {
    if (!_closed) await _invoke<void>('ready');
  }

  @override
  Future<void> dispose() async {
    await _revoke();
    await channel.setMethodCallHandler(null);
    await _changes.close();
  }
}
