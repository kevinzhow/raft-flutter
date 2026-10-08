import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:uuid/uuid.dart';

import 'models.dart';

abstract interface class SessionStore {
  Future<Session?> read(String origin);
  Future<void> write(String origin, Session? session);
}

class MemorySessionStore implements SessionStore {
  final Map<String, Session> _sessions = {};
  @override
  Future<Session?> read(String origin) async => _sessions[origin];
  @override
  Future<void> write(String origin, Session? session) async {
    if (session == null) {
      _sessions.remove(origin);
    } else {
      _sessions[origin] = session;
    }
  }
}

class RaftApiException implements Exception {
  const RaftApiException(this.message, {this.status}) : details = const {};
  RaftApiException.response(this.message, {this.status, Map? body})
    : details = _errorDetails(body);

  /// Allow-listed structured receipts; never part of the printable error.
  final Map<String, dynamic> details;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

Map<String, dynamic> _errorDetails(Map? body) {
  const keys = {
    'code',
    'conversionJob',
    'conversionCommand',
    'uploadScope',
    'uploadCount',
    'archivedChannelId',
    'archivedChannelName',
    'archivedChannelType',
    'canUnarchiveArchivedChannel',
  };
  dynamic freeze(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable({
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: freeze(entry.value),
      });
    }
    if (value is List) return List<dynamic>.unmodifiable(value.map(freeze));
    return value;
  }

  Map<String, dynamic> receipt(dynamic value, Set<String> receiptKeys) =>
      value is Map
      ? {
          for (final key in receiptKeys)
            if (value.containsKey(key)) key: value[key],
        }
      : {};
  dynamic selected(String key) {
    final value = body![key];
    if (key == 'uploadScope')
      return receipt(value, {
        'sessionIds',
        'transferIntentIds',
        'reservationIds',
      });
    if (key == 'conversionCommand')
      return receipt(value, {
        'id',
        'kind',
        'status',
        'jobId',
        'error',
        'createdAt',
      });
    if (key == 'conversionJob') {
      final job = receipt(value, {
        'id',
        'status',
        'phase',
        'canCancel',
        'progress',
        'error',
      });
      if (job['progress'] is Map)
        job['progress'] = receipt(job['progress'], {
          'rollbackState',
          'retryState',
          'errorCode',
          'failedAt',
          'relockedAt',
          'canonicalCopyStarted',
          'audienceCutoverAt',
          'uploadCount',
          'uploadScope',
        });
      final progress = job['progress'];
      if (progress is Map && progress['uploadScope'] is Map)
        progress['uploadScope'] = receipt(progress['uploadScope'], {
          'sessionIds',
          'transferIntentIds',
          'reservationIds',
        });
      return job;
    }
    return value;
  }

  return Map<String, dynamic>.unmodifiable({
    for (final key in keys)
      if (body?.containsKey(key) == true) key: freeze(selected(key)),
  });
}

class UploadCancellation {
  final CancelToken _token = CancelToken();
  bool get cancelled => _token.isCancelled;
  void cancel() => _token.cancel('User cancelled upload');
}

class RaftEvent {
  const RaftEvent(this.name, this.payload);
  final String name;
  final dynamic payload;
}

/// Human API transport; refresh rotation is shared by HTTP and socket recovery.
class RaftClient {
  RaftClient({
    required String origin,
    required this.sessionStore,
    this.clientKind = 'web',
    Dio? transport,
  }) : origin = origin.replaceFirst(RegExp(r'/$'), ''),
       http =
           transport ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    http.options.baseUrl = '${this.origin}/api';
  }
  final String origin;
  final String clientKind;
  final SessionStore sessionStore;
  final Dio http;
  Session? _session;
  RaftRecord? user;
  String? serverId;
  int _generation = 0;
  int _authenticationGeneration = 0;
  int get generation => _generation;
  bool get signedIn => _session != null;
  io.Socket? _socket;
  Future<void>? _refreshing;
  Timer? _authRetry;
  Future<void> _persistence = Future<void>.value();
  bool _closed = false;
  final _events = StreamController<RaftEvent>.broadcast();
  Stream<RaftEvent> get events => _events.stream;
  bool get connected => _socket?.connected ?? false;
  bool restoredOffline = false;

  void _emit(RaftEvent event) {
    if (!_closed) _events.add(event);
  }

  Future<void> _persist(Session? expected) {
    final pending = _persistence.catchError((Object _) {}).then((_) async {
      if (_session == expected) await sessionStore.write(origin, expected);
    });
    _persistence = pending;
    return pending;
  }

  Future<bool> restore() async {
    final authentication = ++_authenticationGeneration;
    _generation++;
    final stored = await sessionStore.read(origin);
    if (authentication != _authenticationGeneration || _closed) return false;
    _session = stored;
    if (_session == null) return false;
    try {
      user = RaftRecord(Map<String, dynamic>.from(await get('/auth/me')));
      final s = _session!;
      _session = Session(
        accessToken: s.accessToken,
        refreshToken: s.refreshToken,
        installationId: s.installationId,
        refreshAttemptId: s.refreshAttemptId,
        cachedUser: user!.json,
      );
      await _persist(_session);
    } on RaftApiException catch (e) {
      if (_session?.cachedUser == null || e.status != null && e.status! < 500)
        rethrow;
      user = RaftRecord(_session!.cachedUser!);
      restoredOffline = true;
    }
    return true;
  }

  Future<void> login(String email, String password) async {
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/login',
      data: {'email': email, 'password': password},
      authorized: false,
    );
    if (_closed || authGeneration != _authenticationGeneration) {
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    }
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  /// Registration requires the caller to collect explicit agreement first.
  Future<void> register(
    String email,
    String password, {
    required bool acceptTerms,
    String legalAcceptanceSource = 'signup',
  }) async {
    if (!acceptTerms)
      throw const RaftApiException(
        'Accept the terms and privacy policy to create an account.',
      );
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/register',
      authorized: false,
      data: {
        'email': email,
        'password': password,
        'acceptTerms': true,
        'termsVersion': '2026-05-12',
        'privacyVersion': '2026-05-12',
        'legalAcceptanceSource': legalAcceptanceSource,
      },
    );
    if (_closed || authGeneration != _authenticationGeneration)
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  Future<void> completeMobileOAuth(
    String code,
    String codeVerifier, {
    bool acceptTerms = false,
  }) async {
    final authGeneration = ++_authenticationGeneration;
    final result = await request(
      'POST',
      '/auth/mobile/oauth/complete',
      authorized: false,
      data: {
        'code': code,
        'codeVerifier': codeVerifier,
        if (acceptTerms) 'acceptTerms': true,
        if (acceptTerms) 'termsVersion': '2026-05-12',
        if (acceptTerms) 'privacyVersion': '2026-05-12',
        if (acceptTerms) 'legalAcceptanceSource': 'oauth',
      },
    );
    if (_closed || authGeneration != _authenticationGeneration)
      throw const RaftApiException(
        'The authentication attempt is no longer active.',
      );
    _session = Session.fromJson(Map<String, dynamic>.from(result));
    user = RaftRecord(Map<String, dynamic>.from(result['user']));
    _generation++;
    await _persist(_session);
  }

  Future<void> logout() async {
    final old = _session;
    _authenticationGeneration++;
    _session = null;
    user = null;
    serverId = null;
    _generation++;
    _socket?.dispose();
    _socket = null;
    await _persist(null);
    Future<dynamic>? revocation;
    if (old != null) {
      revocation = request(
        'POST',
        '/auth/logout',
        data: {'refreshToken': old.refreshToken},
        authorized: false,
      );
    }
    _emit(const RaftEvent('session:ended', null));
    if (revocation != null) {
      try {
        await revocation;
      } catch (_) {
        /* Local logout remains effective offline. */
      }
    }
  }

  void selectServer(String? id) {
    if (serverId == id) return;
    _generation++;
    serverId = id;
    _socket?.dispose();
    _socket = null;
  }

  /// A successful server exit can itself revoke its socket membership before
  /// the HTTP response arrives. Accept that acknowledgement for this exact
  /// server, while retaining the authentication-generation fence.
  Future<dynamic> exitServer(String id, {bool delete = false}) => request(
    delete ? 'DELETE' : 'POST',
    '/servers/$id${delete ? '' : '/leave'}',
    acceptServerExit: true,
  );
  Future<void> reloadUser() async {
    final next = RaftRecord(Map<String, dynamic>.from(await get('/auth/me')));
    final s = _session;
    if (s == null) return;
    user = next;
    _session = Session(
      accessToken: s.accessToken,
      refreshToken: s.refreshToken,
      installationId: s.installationId,
      refreshAttemptId: s.refreshAttemptId,
      cachedUser: next.json,
    );
    await _persist(_session);
    _emit(const RaftEvent('account:updated', null));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, {dynamic data}) =>
      request('POST', path, data: data);
  Future<dynamic> patch(String path, {dynamic data}) =>
      request('PATCH', path, data: data);
  Future<dynamic> delete(String path, {dynamic data}) =>
      request('DELETE', path, data: data);
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    final generation = _generation, authentication = _authenticationGeneration;
    final exit =
        acceptServerExit &&
        serverId != null &&
        (method == 'DELETE' && path == '/servers/$serverId' ||
            method == 'POST' && path == '/servers/$serverId/leave');
    try {
      final response = await http.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancellation?._token,
        onSendProgress: onSendProgress,
        options: Options(
          method: method,
          receiveTimeout: receiveTimeout,
          headers: {
            ...?headers,
            if (authorized && _session != null)
              'Authorization': 'Bearer ${_session!.accessToken}',
            if (authorized && serverId != null) 'X-Server-Id': serverId,
          },
        ),
      );
      if (authorized &&
          (authentication != _authenticationGeneration ||
              generation != _generation && !exit))
        throw const RaftApiException(
          'The account or workspace changed. Please retry.',
        );
      return response.data;
    } on DioException catch (e) {
      if (authorized &&
          (authentication != _authenticationGeneration ||
              generation != _generation && !exit)) {
        throw const RaftApiException(
          'The account or workspace changed. Please retry.',
        );
      }
      if (e.response?.statusCode == 401 &&
          authorized &&
          !retried &&
          (!path.startsWith('/auth/') || path == '/auth/me') &&
          _session != null) {
        if (generation != _generation ||
            authentication != _authenticationGeneration) {
          throw const RaftApiException('The account or workspace changed.');
        }
        await refresh();
        if (generation != _generation ||
            authentication != _authenticationGeneration)
          throw const RaftApiException('The account or workspace changed.');
        return request(
          method,
          path,
          data: data is FormData ? data.clone() : data,
          query: query,
          retried: true,
          cancellation: cancellation,
          onSendProgress: onSendProgress,
          headers: headers,
          acceptServerExit: acceptServerExit,
          receiveTimeout: receiveTimeout,
        );
      }
      final body = e.response?.data;
      throw RaftApiException.response(
        body is Map
            ? (body['error'] ?? body['message'] ?? 'Request failed').toString()
            : e.type == DioExceptionType.connectionError
            ? 'Cannot connect to the Raft server.'
            : 'Request failed. Please retry.',
        status: e.response?.statusCode,
        body: body is Map ? body : null,
      );
    }
  }

  Future<void> refresh() =>
      _refreshing ??= _rotate().whenComplete(() => _refreshing = null);
  Future<void> _rotate() async {
    var old = _session;
    if (old == null)
      throw const RaftApiException('Please sign in again.', status: 401);
    try {
      if (old.refreshAttemptId == null) {
        old = old.withAttempt(
          'arf_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}',
        );
        _session = old;
        await _persist(old);
      }
      if (_session != old) return;
      final value = await request(
        'POST',
        '/auth/refresh',
        data: {'refreshToken': old.refreshToken},
        authorized: false,
        headers: {
          'X-Slock-Auth-Refresh-Attempt-Id': old.refreshAttemptId,
          'X-Slock-Auth-Installation-Id': old.installationId,
        },
      );
      if (_session != old) return;
      _session = Session(
        accessToken: value['accessToken'],
        refreshToken: value['refreshToken'],
        installationId: old.installationId,
        cachedUser: old.cachedUser,
      );
      await _persist(_session);
      _socket?.auth = _authenticateSocket;
    } on RaftApiException catch (e) {
      if (_session == old && (e.status == 401 || e.status == 403))
        await logout();
      rethrow;
    }
  }

  Map<String, dynamic> get _socketAuth => {
    'token': _session?.accessToken,
    'serverId': serverId,
    'clientKind': clientKind,
  };
  bool get _accessNeedsRefresh {
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(
            base64Url.normalize(_session!.accessToken.split('.')[1]),
          ),
        ),
      );
      final exp = payload['exp'];
      return exp is num &&
          exp <= DateTime.now().millisecondsSinceEpoch / 1000 + 30;
    } catch (_) {
      return false;
    }
  }

  void _authenticateSocket(void Function(Map) callback) async {
    final generation = _generation;
    try {
      if (_accessNeedsRefresh) await refresh();
    } catch (_) {
      /* Retry policy keeps transient failures distinct from logout. */
    }
    if (_session != null && generation == _generation) callback(_socketAuth);
  }

  void connect() {
    if (_session == null || serverId == null) return;
    _socket?.dispose();
    final epoch = _generation;
    final socket = io.io(
      origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuthFn(_authenticateSocket)
          .build(),
    );
    _socket = socket;
    socket.onAny((String event, [dynamic payload]) {
      if (epoch == _generation) _emit(RaftEvent(event, payload));
    });
    socket.onConnect((_) {
      if (epoch == _generation) _emit(const RaftEvent('connected', null));
    });
    socket.onDisconnect((_) {
      if (epoch == _generation) _emit(const RaftEvent('disconnected', null));
    });
    socket.onConnectError((error) async {
      if (epoch != _generation) return;
      _emit(
        RaftEvent('connection:error', {
          'notServerMember': error.toString().contains(
            'Not a member of this server',
          ),
        }),
      );
      if (error.toString().toLowerCase().contains('token')) {
        try {
          await refresh();
          if (epoch == _generation) {
            socket.auth = _authenticateSocket;
            socket.connect();
          }
        } catch (_) {
          if (_session != null && epoch == _generation) {
            _authRetry?.cancel();
            _authRetry = Timer(const Duration(seconds: 2), () {
              if (epoch == _generation) socket.connect();
            });
          }
        }
      }
    });
    socket.io.on('reconnect_attempt', (_) {
      socket.auth = _authenticateSocket;
    });
    socket.connect();
  }

  void resume(BigInt seq) {
    _socket?.emit('sync:resume', {'lastSeq': seq.toInt()});
  }

  /// Pause the live transport while preserving credentials and history.
  void suspendConnection() {
    _authRetry?.cancel();
    _socket?.disconnect();
  }

  void recoverConnection(BigInt seq) {
    if (connected) {
      resume(seq);
    } else {
      connect();
    }
  }

  void joinChannel(String channelId) =>
      _socket?.emit('join:channel', channelId);
  Future<List<RaftRecord>> servers() async => (await get('/servers') as List)
      .map((e) => RaftRecord(Map<String, dynamic>.from(e)))
      .toList();
  Future<List<RaftChannel>> channels({bool dm = false}) async => (await get(
    dm ? '/channels/dm' : '/channels',
    query: dm ? null : {'archived': 'include'},
  ) as List).map((e) => RaftChannel(Map<String, dynamic>.from(e))).toList();
  Future<Map<String, dynamic>> messagePage(
    String id, {
    BigInt? before,
    BigInt? after,
    int limit = 50,
  }) async => Map<String, dynamic>.from(
    await get(
      '/messages/channel/$id',
      query: {
        'limit': limit,
        if (before != null) 'before': before.toString(),
        if (after != null) 'after': after.toString(),
      },
    ),
  );
  String newRandomId() => const Uuid().v4();
  Future<List<Map<String, dynamic>>> upload(
    String channelId,
    Uint8List bytes,
    String filename, {
    UploadCancellation? cancellation,
    void Function(int, int)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'channelId': channelId,
      'files': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final result = await request(
      'POST',
      '/attachments/upload',
      data: form,
      cancellation: cancellation,
      onSendProgress: onProgress,
    );
    return (result['attachments'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<RaftMessage> send(
    String channelId,
    String content, {
    List<String>? attachments,
    List<Map<String, dynamic>>? mentions,
    String? randomId,
  }) async {
    final value = await post(
      '/v2/messages',
      data: {
        'channelId': channelId,
        'content': content,
        'randomId': randomId ?? const Uuid().v4(),
        if (attachments != null) 'attachmentIds': attachments,
        if (mentions != null)
          'mentions': [
            for (final mention in mentions) Map<String, dynamic>.from(mention),
          ],
      },
    );
    return RaftMessage(Map<String, dynamic>.from(value['message'] ?? value));
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _generation++;
    _authenticationGeneration++;
    _session = null;
    user = null;
    _authRetry?.cancel();
    _socket?.dispose();
    await _events.close();
    http.close();
  }
}
