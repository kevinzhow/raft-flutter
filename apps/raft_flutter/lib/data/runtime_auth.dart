// Web v1.24 utils/runtimeAuthClient.ts (+ shared/src/runtimeAuth.ts): signing
// a Computer's runtimes (Claude Code, Codex, Kimi, Qoder, Pi, OpenCode …) in
// and out from the app, and spending their limit resets. One read per
// (server, Computer), cached 30s and dropped when the server says the
// Computer sent a new status (`machine:runtime_auth:updated`, content-free).
// Login links and codes arrive on this person's own socket only
// (`runtime_auth:login:event|result`), filtered by login id by the caller.
//
// Nothing here logs: a pasted code, and a provider's API key, go into one
// request body each and nowhere else.
import 'dart:async';

import 'package:raft_client/raft_client.dart';

import 'workspace_controller.dart';

/// RUNTIME_AUTH_RUNTIMES.
const runtimeAuthRuntimes = [
  'claude',
  'codex',
  'kimi',
  'qoder',
  'qwen',
  'antigravity',
  'pi',
  'grok',
  'opencode',
  'codebuddy',
];

/// RUNTIME_AUTH_V1_RUNTIMES: what a server that predates `runtimes` offers.
const runtimeAuthV1Runtimes = ['claude', 'codex'];

/// RUNTIME_AUTH_SERVER_GATED_RUNTIMES: offered only where the server lists it.
const runtimeAuthServerGatedRuntimes = ['antigravity'];

/// RUNTIME_AUTH_ACTIONS.
const runtimeAuthActions = <String, List<String>>{
  'claude': ['login', 'logout'],
  'codex': ['login', 'logout'],
  'kimi': ['login', 'logout'],
  'qoder': ['login'],
  'qwen': ['connect_provider'],
  'antigravity': ['login', 'logout'],
  'pi': ['login', 'logout', 'connect_provider'],
  'grok': ['login', 'logout'],
  'opencode': ['login', 'logout', 'connect_provider'],
  'codebuddy': ['login', 'logout'],
};

bool runtimeAuthSupports(String runtime, String action) =>
    runtimeAuthActions[runtime]?.contains(action) ?? false;

/// runtimeAuthLogoutNeedsCapability: a logout that only a newer daemon has.
bool runtimeAuthLogoutNeedsCapability(String runtime) =>
    runtime == 'antigravity';

/// RUNTIME_AUTH_LOGIN_REGION_CHOICES: Kimi asks for a region first.
const runtimeAuthLoginRegionChoices = <String, List<String>>{
  'kimi': ['mainland-cn', 'global'],
};

/// RUNTIME_AUTH_PER_PROVIDER_RUNTIMES (Pi, OpenCode: one sign-in per provider).
bool runtimeAuthSignsInPerProvider(String runtime) =>
    runtime == 'pi' || runtime == 'opencode';

/// RUNTIME_AUTH_OAUTH_METHOD_RUNTIMES (OpenCode names the chosen method).
bool runtimeAuthChoosesOAuthMethod(String runtime) => runtime == 'opencode';

/// runtimeProviderKey.ts hasProviderKey: a runtime signed in by a provider
/// key only (Qwen Code); its status is presence ("Provider configured").
bool runtimeAuthHasProviderKey(String runtime) => runtime == 'qwen';

/// runtimeAuthRuntimeFor: the runtime-auth id of a Raft runtime id
/// (`kimi-sdk` is Kimi's), or null when it has no sign-in from here.
String? runtimeAuthRuntimeFor(String raftRuntimeId) {
  if (raftRuntimeId == 'kimi-sdk') return 'kimi';
  // The deprecated Kimi CLI (`kimi`) has none: its agents run on
  // `~/.kimi/config.toml`, which that sign-in does not touch.
  if (raftRuntimeId == 'kimi') return null;
  return runtimeAuthRuntimes.contains(raftRuntimeId) ? raftRuntimeId : null;
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// RuntimeAuthAccount: the masked email, plan and method, any of them absent.
class RuntimeAuthAccount {
  const RuntimeAuthAccount({
    this.maskedLabel,
    this.planLabel,
    this.methodLabel,
  });
  static RuntimeAuthAccount? fromJson(Object? value) {
    final map = _map(value);
    if (map == null) return null;
    String? text(String key) {
      final v = map[key];
      return v is String && v.trim().isNotEmpty ? v : null;
    }

    return RuntimeAuthAccount(
      maskedLabel: text('maskedLabel'),
      planLabel: text('planLabel'),
      methodLabel: text('methodLabel'),
    );
  }

  final String? maskedLabel, planLabel, methodLabel;
}

/// accountText.ts: "masked email · plan" (whichever is known), or null.
String? runtimeAuthAccountText(RuntimeAuthAccount? account) {
  if (account == null) return null;
  final parts = [?account.maskedLabel, ?account.planLabel];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// RuntimeAuthSignedInProvider: a per-provider runtime's stored sign-in.
class RuntimeAuthSignedInProvider {
  const RuntimeAuthSignedInProvider({
    required this.id,
    required this.label,
    required this.method,
    this.subscription,
  });
  static RuntimeAuthSignedInProvider? fromJson(Object? value) {
    final map = _map(value);
    final id = map?['id'], label = map?['label'], method = map?['method'];
    if (id is! String || label is! String) return null;
    if (method != 'oauth' && method != 'api_key') return null;
    final subscription = map!['subscription'];
    return RuntimeAuthSignedInProvider(
      id: id,
      label: label,
      method: method as String,
      subscription: subscription is bool ? subscription : null,
    );
  }

  final String id, label;

  /// `oauth` | `api_key`.
  final String method;
  final bool? subscription;
}

/// RuntimeAuthStatus: `logged_in` (account, providers) | `logged_out` |
/// `unknown` | `unavailable` (reason not_installed | version_unsupported |
/// unsupported_installation).
class RuntimeAuthStatus {
  const RuntimeAuthStatus(
    this.kind, {
    this.account,
    this.providers,
    this.reason,
  });
  static RuntimeAuthStatus? fromJson(Object? value) {
    final map = _map(value);
    final kind = map?['kind'];
    switch (kind) {
      case 'logged_in':
        final providers = map!['providers'];
        return RuntimeAuthStatus(
          'logged_in',
          account: RuntimeAuthAccount.fromJson(map['account']),
          providers: providers is List
              ? [
                  for (final p in providers)
                    ?RuntimeAuthSignedInProvider.fromJson(p),
                ]
              : null,
        );
      case 'logged_out' || 'unknown':
        return RuntimeAuthStatus(kind as String);
      case 'unavailable':
        final reason = map!['reason'];
        return RuntimeAuthStatus(
          'unavailable',
          reason: reason is String ? reason : 'unsupported_installation',
        );
    }
    return null;
  }

  final String kind;
  final RuntimeAuthAccount? account;
  final List<RuntimeAuthSignedInProvider>? providers;
  final String? reason;
  bool get loggedIn => kind == 'logged_in';
  bool get loggedOut => kind == 'logged_out';
}

/// RuntimeAuthView: what `GET …/runtime-auth` answers for one Computer.
class RuntimeAuthView {
  const RuntimeAuthView({
    required this.statuses,
    required this.availability,
    required this.canAct,
    this.runtimes,
    this.logoutRuntimes,
    this.claudeLimitResets,
    this.claudeLimitResetCanUse = true,
    this.claudeLimitResetCanConsent = true,
  });

  factory RuntimeAuthView.fromJson(Object? value) {
    final map = _map(value) ?? const <String, dynamic>{};
    final report = _map(map['status']);
    final reported = _map(report?['runtimes']) ?? const <String, dynamic>{};
    final statuses = <String, RuntimeAuthStatus>{
      for (final entry in reported.entries)
        if (runtimeAuthRuntimes.contains(entry.key))
          entry.key: ?RuntimeAuthStatus.fromJson(entry.value),
    };
    List<String>? names(Object? value) => value is List
        ? [
            for (final v in value)
              if (v is String && runtimeAuthRuntimes.contains(v)) v,
          ]
        : null;
    final availability = map['availability'];
    final resets = map['claudeLimitResets'];
    final access = _map(map['claudeLimitResetAccess']);
    return RuntimeAuthView(
      statuses: statuses,
      availability: availability is String ? availability : 'computer_offline',
      canAct: map['canAct'] == true,
      runtimes: names(map['runtimes']),
      logoutRuntimes: names(map['logoutRuntimes']),
      claudeLimitResets: resets == 'ok' || resets == 'computer_upgrade_required'
          ? resets as String
          : null,
      claudeLimitResetCanUse: access == null || access['canUse'] == true,
      claudeLimitResetCanConsent:
          access == null || access['canConsent'] == true,
    );
  }

  /// The runtimes' statuses the Computer reported (none before its first
  /// report: `status` null on the wire).
  final Map<String, RuntimeAuthStatus> statuses;

  /// `ok` | `computer_offline` | `computer_upgrade_required` |
  /// `computer_not_attached`.
  final String availability;
  final bool canAct;
  final List<String>? runtimes, logoutRuntimes;

  /// `ok` | `computer_upgrade_required` | null (nothing to show).
  final String? claudeLimitResets;
  final bool claudeLimitResetCanUse, claudeLimitResetCanConsent;

  /// runtimeAuthStatusOf.
  RuntimeAuthStatus? statusOf(String runtime) => statuses[runtime];

  /// The person may act on this Computer's runtimes now.
  bool get canActNow => canAct && availability == 'ok';

  /// runtimeAuthComputerSupports.
  bool supports(String runtime) =>
      (runtimes ?? runtimeAuthV1Runtimes).contains(runtime);

  /// runtimeAuthComputerSignsOut.
  bool signsOut(String runtime) {
    if (!runtimeAuthSupports(runtime, 'logout')) return false;
    if (logoutRuntimes != null) return logoutRuntimes!.contains(runtime);
    return !runtimeAuthLogoutNeedsCapability(runtime) && supports(runtime);
  }
}

/// A login push (`runtime_auth:login:event` / `:result`) whose routing
/// fields checked out. [payload] is the `event` or `result` object; its
/// `kind` is one of the known kinds (others are dropped here).
class RuntimeAuthLoginPush {
  const RuntimeAuthLoginPush({
    required this.serverId,
    required this.machineId,
    required this.runtime,
    required this.loginId,
    required this.isResult,
    required this.payload,
  });
  final String serverId, machineId, runtime, loginId;

  /// false: an event (auth_url | device_code | info | code_prompt);
  /// true: a result (logged_in | failed | cancelled | unsupported | busy).
  final bool isResult;
  final Map<String, dynamic> payload;
  String get kind => '${payload['kind']}';
}

const _loginEventKinds = {'auth_url', 'device_code', 'info', 'code_prompt'};
const _loginResultKinds = {
  'logged_in',
  'failed',
  'cancelled',
  'unsupported',
  'busy',
};

/// asRuntimeAuthLoginId: a 1–128 char id of letters, digits, `_` and `-`.
bool isRuntimeAuthLoginId(Object? value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

/// Thrown when the server's answer does not check out
/// (RuntimeAuthMalformedResponseError).
class RuntimeAuthMalformedResponse implements Exception {
  const RuntimeAuthMalformedResponse();
  @override
  String toString() => 'The server answered in a shape this page does not read';
}

/// runtimeAuthRequestError: the HTTP status and server `code` of a failure.
({int? status, String? code}) runtimeAuthRequestError(Object error) {
  if (error is RaftApiException)
    return (status: error.status, code: error.code);
  return (status: null, code: null);
}

/// The headers on the requests that answer with a usage snapshot (read,
/// refresh, limit reset): this build reads a window's `scope`
/// (RUNTIME_USAGE_REQUEST_HEADERS).
const runtimeUsageRequestHeaders = <String, String>{
  'X-Raft-Client-Capabilities': 'runtime-usage-window-scope@2',
};

class RuntimeAuthClient {
  RuntimeAuthClient({
    required this.get,
    required this.post,
    required this.events,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const cacheFor = Duration(seconds: 30);
  static const updatedEvent = 'machine:runtime_auth:updated';
  static const loginEvent = 'runtime_auth:login:event';
  static const loginResultEvent = 'runtime_auth:login:result';

  final Future<dynamic> Function(String path) get;
  final Future<dynamic> Function(String path, Map<String, dynamic> body) post;
  final DateTime Function() now;
  final Stream<RaftEvent> events;
  StreamSubscription<RaftEvent>? _subscription;
  final _cache = <String, (RuntimeAuthView, DateTime)>{};
  final _reads = <String, Future<RuntimeAuthView>>{};
  final _watchers = <String, Set<void Function()>>{};
  // The socket is listened to once the first caller listens (the getter
  // below runs before its `listen`, so it cannot know).
  late final _login = StreamController<RuntimeAuthLoginPush>.broadcast(
    onListen: _syncSocket,
  );

  static String _key(String server, String machine) => '$server\u0000$machine';
  static String _base(String server, String machine) =>
      '/servers/${Uri.encodeComponent(server)}/machines/'
      '${Uri.encodeComponent(machine)}/runtime-auth';

  /// The cached view for first paint, if still fresh.
  RuntimeAuthView? cached(String server, String machine) {
    final hit = _cache[_key(server, machine)];
    return hit != null && hit.$2.isAfter(now()) ? hit.$1 : null;
  }

  Future<RuntimeAuthView> read(String server, String machine) {
    final key = _key(server, machine);
    final hit = cached(server, machine);
    if (hit != null) return Future.value(hit);
    final pending = _reads[key];
    if (pending != null) return pending;
    late final Future<RuntimeAuthView> request;
    request = get(_base(server, machine))
        .then((value) {
          final view = RuntimeAuthView.fromJson(value);
          if (identical(_reads[key], request)) {
            _cache[key] = (view, now().add(cacheFor));
          }
          return view;
        })
        .whenComplete(() {
          if (identical(_reads[key], request)) _reads.remove(key);
        });
    return _reads[key] = request;
  }

  /// Drops the cached view so the next read asks the server, and tells
  /// every watcher of that Computer.
  void invalidate(String server, String machine) {
    final key = _key(server, machine);
    _cache.remove(key);
    _reads.remove(key);
    _notify(machine);
  }

  /// Calls [onChange] whenever this Computer's status may have changed (a
  /// new report, a login or logout from here). The watcher re-reads.
  void Function() watch(String machine, void Function() onChange) {
    (_watchers[machine] ??= {}).add(onChange);
    _syncSocket();
    return () {
      final set = _watchers[machine];
      set?.remove(onChange);
      if (set != null && set.isEmpty) _watchers.remove(machine);
      _syncSocket();
    };
  }

  /// Login events and results on this person's socket, checked. Filter by
  /// [RuntimeAuthLoginPush.loginId].
  Stream<RuntimeAuthLoginPush> get loginPushes {
    _syncSocket();
    return _login.stream;
  }

  /// Starts a login on the Computer. [region]: Kimi's chosen region;
  /// [providerId]: a per-provider runtime's provider (Pi, OpenCode);
  /// [oauthMethod]: OpenCode's chosen sign-in, by its label.
  Future<String> startLogin(
    String server,
    String machine,
    String runtime, {
    String? region,
    String? providerId,
    String? oauthMethod,
  }) async {
    final answer = await post('${_base(server, machine)}/$runtime/login', {
      'region': ?region,
      'providerId': ?providerId,
      'oauthMethod': ?oauthMethod,
    });
    final loginId = answer is Map ? answer['loginId'] : null;
    if (!isRuntimeAuthLoginId(loginId)) {
      throw const RuntimeAuthMalformedResponse();
    }
    return loginId as String;
  }

  /// Sends the one-time code (or the pasted page address) to that login.
  /// Never log [code].
  Future<void> submitCode(
    String server,
    String machine,
    String runtime,
    String loginId,
    String code,
  ) => post(
    '${_base(server, machine)}/$runtime/login/${Uri.encodeComponent(loginId)}/code',
    {'code': code},
  );

  Future<void> cancelLogin(
    String server,
    String machine,
    String runtime,
    String loginId,
  ) => post(
    '${_base(server, machine)}/$runtime/login/${Uri.encodeComponent(loginId)}/cancel',
    const {},
  );

  /// `{kind: logged_out}` | `{kind: failed, reason, detail?}` |
  /// `{kind: unsupported, reason}`. [providerId]: the one provider to sign
  /// out of a per-provider runtime (Pi).
  Future<Map<String, dynamic>> logout(
    String server,
    String machine,
    String runtime, {
    String? providerId,
  }) async {
    final answer = await post('${_base(server, machine)}/$runtime/logout', {
      'providerId': ?providerId,
    });
    return _result(answer, const {'logged_out', 'failed', 'unsupported'});
  }

  /// `{kind: listed, providers: [...]}` | `{kind: failed, reason}` |
  /// `{kind: unsupported, reason}` (runtimeAuthProviderSchema per provider).
  Future<Map<String, dynamic>> listProviders(
    String server,
    String machine,
    String runtime,
  ) async {
    final answer = await get('${_base(server, machine)}/$runtime/providers');
    final result = _result(answer, const {'listed', 'failed', 'unsupported'});
    if (result['kind'] == 'listed' && result['providers'] is! List) {
      throw const RuntimeAuthMalformedResponse();
    }
    return result;
  }

  /// Saves a provider's API key on the Computer: `{providerId, apiKey,
  /// baseUrl?, modelIds?}`. Never log [input]. `{kind: connected}` |
  /// `{kind: failed, reason}` | `{kind: unsupported, reason}` | `{kind: busy}`.
  Future<Map<String, dynamic>> connectProvider(
    String server,
    String machine,
    String runtime,
    Map<String, dynamic> input,
  ) async {
    final answer = await post(
      '${_base(server, machine)}/$runtime/connect-provider',
      input,
    );
    return _result(answer, const {
      'connected',
      'failed',
      'unsupported',
      'busy',
    });
  }

  /// Spends one limit reset of the runtime account (Codex; Claude names
  /// [kind]). [idempotencyKey] names one confirmed click: retry an attempt
  /// whose outcome was never learned with the same key. Answers the outcome
  /// (`reset` | `nothing_to_reset` | `no_reset` | `already_redeemed` |
  /// `reauth_required` | `unsupported` | `unknown`) and the usage the
  /// Computer read right after (null when it could not).
  Future<({Map<String, dynamic> result, Map<String, dynamic>? snapshot})>
  redeemLimitReset(
    String server,
    String machine,
    String provider,
    String idempotencyKey, {
    String? kind,
  }) async {
    final answer = await RaftClient.runWithHeaders(
      runtimeUsageRequestHeaders,
      () => post(
        '/servers/${Uri.encodeComponent(server)}/machines/'
        '${Uri.encodeComponent(machine)}/runtime-account-usage/$provider/limit-reset',
        {'idempotencyKey': idempotencyKey, 'kind': ?kind},
      ),
    );
    final result = _result(answer is Map ? answer['result'] : null, const {
      'reset',
      'nothing_to_reset',
      'no_reset',
      'already_redeemed',
      'reauth_required',
      'unsupported',
      'unknown',
    });
    final snapshot = answer is Map ? _map(answer['snapshot']) : null;
    return (
      result: result,
      snapshot: snapshot != null && snapshot['accounts'] is List
          ? snapshot
          : null,
    );
  }

  /// Reads which limit resets the Claude account holds (opens Claude Code's
  /// own command per kind). Only on a person's click. [consent]: the person
  /// accepted that, at the 5-hour limit, this can use the older program's
  /// 5-hour reset. `{kind: read, program?, fiveHourSpent?, resets: [...]}` |
  /// `{kind: reauth_required, reason}` | `{kind: unsupported, reason}` |
  /// `{kind: unknown}`.
  Future<Map<String, dynamic>> readLimitResets(
    String server,
    String machine, {
    required bool consent,
  }) async {
    final answer = await post(
      '/servers/${Uri.encodeComponent(server)}/machines/'
      '${Uri.encodeComponent(machine)}/runtime-account-usage/claude/limit-resets/read',
      consent ? {'consent': true} : <String, dynamic>{},
    );
    final result = _result(answer is Map ? answer['result'] : null, const {
      'read',
      'reauth_required',
      'unsupported',
      'unknown',
    });
    if (result['kind'] == 'read' && result['resets'] is! List) {
      throw const RuntimeAuthMalformedResponse();
    }
    return result;
  }

  /// The `{result: {...}}` envelope's result (or [answer] itself when it is
  /// the result), checked against [kinds].
  static Map<String, dynamic> _result(Object? answer, Set<String> kinds) {
    var map = _map(answer);
    if (map != null && map['kind'] == null && map['result'] is Map) {
      map = _map(map['result']);
    }
    if (map == null || !kinds.contains(map['kind'])) {
      throw const RuntimeAuthMalformedResponse();
    }
    return map;
  }

  void clear() {
    _cache.clear();
    _reads.clear();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _login.close();
  }

  void _notify(String machine) {
    for (final listener in [...?_watchers[machine]]) {
      listener();
    }
  }

  void _syncSocket() {
    final needed = _watchers.isNotEmpty || _login.hasListener;
    if (needed && _subscription == null) {
      _subscription = events.listen(_onEvent);
    }
  }

  void _onEvent(RaftEvent event) {
    switch (event.name) {
      case updatedEvent:
        final machine = _map(event.payload)?['machineId'];
        if (machine is! String) return;
        // The event names only the Computer: drop every server's view of it.
        for (final key in [..._cache.keys, ..._reads.keys]) {
          if (key.endsWith('\u0000$machine')) {
            _cache.remove(key);
            _reads.remove(key);
          }
        }
        _notify(machine);
      case loginEvent || loginResultEvent:
        final push = _push(event);
        if (push != null && !_login.isClosed) _login.add(push);
    }
  }

  static RuntimeAuthLoginPush? _push(RaftEvent event) {
    final map = _map(event.payload);
    if (map == null) return null;
    final serverId = map['serverId'], machineId = map['machineId'];
    final runtime = map['runtime'], loginId = map['loginId'];
    if (serverId is! String || machineId is! String) return null;
    if (runtime is! String || !runtimeAuthRuntimes.contains(runtime)) {
      return null;
    }
    if (!isRuntimeAuthLoginId(loginId)) return null;
    final isResult = event.name == loginResultEvent;
    final payload = _map(map[isResult ? 'result' : 'event']);
    final kinds = isResult ? _loginResultKinds : _loginEventKinds;
    if (payload == null || !kinds.contains(payload['kind'])) return null;
    // An auth link or a device code's page is relayed only over https.
    for (final field in const ['url', 'verificationUri']) {
      final value = payload[field];
      if (value != null &&
          (value is! String || Uri.tryParse(value)?.scheme != 'https')) {
        return null;
      }
    }
    return RuntimeAuthLoginPush(
      serverId: serverId,
      machineId: machineId,
      runtime: runtime,
      loginId: loginId as String,
      isResult: isResult,
      payload: payload,
    );
  }
}

/// The workspace's runtime-auth client, bound to the server-level identity
/// (the cache empties on account / server / role changes, as the usage
/// client's does).
RuntimeAuthClient runtimeAuthClientOf(WorkspaceController w) =>
    w.agentTabCache.putIfAbsent(
      'runtime-auth',
      () => RuntimeAuthClient(
        get: (path) => w.query(path),
        post: (path, body) => w.command('POST', path, data: body),
        events: w.client.events,
      ),
    ) as RuntimeAuthClient;
