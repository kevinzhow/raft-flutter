import 'dart:async';
import 'dart:io';

import 'proxy_types.dart';
import 'resolver.dart';

/// Where the effective proxy decision comes from.
enum ProxySource { direct, manual, environment, system, pac }

/// A snapshot of "what would happen now", for Settings and diagnostics. Holds
/// no credentials.
class ProxyStatus {
  const ProxyStatus({
    required this.source,
    this.proxy,
    this.pacUrl,
    this.socksOnly = false,
    this.pacUnsupported = false,
    this.hasCredentials = false,
    this.credentialsProblem,
  });
  final ProxySource source;

  /// `host:port` of the HTTP proxy in use (the sample URL's answer), if any.
  final String? proxy;
  final String? pacUrl;

  /// The system proxy is SOCKS-only; requests go direct (HTTP proxies only).
  final bool socksOnly;

  /// A PAC / auto-detect configuration this platform cannot evaluate.
  final bool pacUnsupported;
  final bool hasCredentials;
  final String? credentialsProblem;

  @override
  String toString() =>
      'ProxyStatus(${source.name}, ${proxy ?? '-'}'
      '${socksOnly ? ', socks-only' : ''})';
}

/// One mechanism for every network path: the OS's proxy decision, the app's own
/// manual setting, or "direct", answered synchronously from a cache so a
/// request never waits on a native lookup.
///
/// Order: the app's Settings choice (direct / manual) wins; for "system" the
/// `http_proxy` / `https_proxy` / `no_proxy` environment is an override when
/// set, otherwise the OS configuration.
class SystemProxy {
  SystemProxy({
    SystemProxyResolver? resolver,
    Map<String, String>? environment,
    DateTime Function()? now,
    this.maxAge = const Duration(seconds: 60),
    this.readyTimeout = const Duration(milliseconds: 750),
  }) : _resolver = resolver ?? const NoSystemProxyResolver(),
       _environment = environment,
       _now = now ?? DateTime.now {
    _subscription = _resolver.changes.listen((_) => unawaited(refresh()));
  }

  /// The process-wide instance every network path uses. The app installs the
  /// platform resolver and the saved settings at start-up.
  static SystemProxy instance = SystemProxy();

  SystemProxyResolver _resolver;
  final Map<String, String>? _environment;
  final DateTime Function() _now;
  StreamSubscription<void>? _subscription;

  /// Cached entries older than this are served once more and refreshed in the
  /// background (no timers: refresh is driven by requests and by the app).
  final Duration maxAge;

  /// How long the first request to a host may wait for a PAC answer.
  final Duration readyTimeout;

  ProxySettings _settings = ProxySettings.system;
  SystemProxySnapshot? _snapshot;
  DateTime? _snapshotAt;
  Future<void>? _snapshotLoad;
  final Map<String, ({List<ProxyEntry> entries, DateTime at})> _pac = {};
  final Map<String, Future<void>> _pacLoads = {};
  final _changes = StreamController<void>.broadcast();

  ProxySettings get settings => _settings;
  SystemProxySnapshot? get snapshotOrNull => _snapshot;

  /// Fires when the settings, the OS snapshot or a PAC answer changed.
  Stream<void> get changes => _changes.stream;

  Map<String, String> get _env => _environment ?? Platform.environment;

  void useResolver(SystemProxyResolver resolver) {
    _subscription?.cancel();
    _resolver = resolver;
    _subscription = resolver.changes.listen((_) => unawaited(refresh()));
    _snapshot = null;
    _snapshotAt = null;
    _pac.clear();
  }

  /// Applies the user's Settings choice. Cheap, synchronous effect on
  /// [findProxy]; connections already open keep their proxy until they close.
  void configure(ProxySettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _changes.add(null);
  }

  // -- the synchronous decision ------------------------------------------------

  /// `HttpClient.findProxy`: `PROXY host:port`, a `;` list, or `DIRECT`.
  String findProxy(Uri url) => _decide(url).decision.findProxyString;

  ({ProxyDecision decision, ProxySource source, bool authenticated}) _decide(
    Uri url,
  ) {
    const direct = ProxyDecision.direct;
    switch (_settings.mode) {
      case ProxyMode.direct:
        return (
          decision: direct,
          source: ProxySource.direct,
          authenticated: false,
        );
      case ProxyMode.manual:
        if (!_settings.hasManualTarget ||
            ProxyBypass(_settings.bypass).matches(url)) {
          return (
            decision: direct,
            source: ProxySource.manual,
            authenticated: false,
          );
        }
        final host = _settings.host.trim();
        return (
          // The entry carries no credentials; [findProxyForClient] adds them.
          decision: ProxyDecision([
            ProxyEntry(
              ProxyKind.http,
              host.startsWith('[') && host.endsWith(']')
                  ? host.substring(1, host.length - 1)
                  : host,
              _settings.port,
            ),
          ]),
          source: ProxySource.manual,
          authenticated:
              _settings.hasCredentials && _settings.credentialsProblem == null,
        );
      case ProxyMode.system:
        break;
    }
    final fromEnvironment = _environmentDecision(url);
    if (fromEnvironment != null) {
      return (
        decision: fromEnvironment,
        source: ProxySource.environment,
        authenticated: false,
      );
    }
    _refreshIfStale();
    final snapshot = _snapshot;
    if (snapshot == null) {
      return (
        decision: direct,
        source: ProxySource.system,
        authenticated: false,
      );
    }
    if (snapshot.isPac && _resolver.canResolvePac) {
      if (ProxyBypass.isLoopback(url.host)) {
        return (
          decision: direct,
          source: ProxySource.pac,
          authenticated: false,
        );
      }
      final key = _key(url);
      final cached = _pac[key];
      if (cached == null || _now().difference(cached.at) > maxAge) {
        _loadPac(url);
      }
      if (cached != null) {
        return (
          decision: decisionFromEntries(cached.entries),
          source: ProxySource.pac,
          authenticated: false,
        );
      }
      // Cold miss: the static part of the configuration (or DIRECT) answers
      // until the PAC result lands.
      return (
        decision: snapshot.decide(url),
        source: ProxySource.pac,
        authenticated: false,
      );
    }
    return (
      decision: snapshot.decide(url),
      source: snapshot.isPac ? ProxySource.pac : ProxySource.system,
      authenticated: false,
    );
  }

  /// `http_proxy` / `https_proxy` / `no_proxy` (either case), parsed by dart:io.
  ProxyDecision? _environmentDecision(Uri url) {
    final env = _env;
    bool set(String name) =>
        (env[name] ?? env[name.toUpperCase()] ?? '').trim().isNotEmpty;
    if (!set('http_proxy') && !set('https_proxy')) return null;
    if (ProxyBypass.isLoopback(url.host)) return ProxyDecision.direct;
    try {
      return decisionFromEntries(
        parsePacResult(
          // ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: the HttpClient factory and the environment override of the proxy decision.
          HttpClient.findProxyFromEnvironment(url, environment: env),
        ),
      );
    } catch (_) {
      return ProxyDecision.direct;
    }
  }

  static String _key(Uri url) {
    final secure = url.scheme == 'https' || url.scheme == 'wss';
    final port = url.hasPort ? url.port : (secure ? 443 : 80);
    return '${secure ? 'https' : 'http'}://${url.host.toLowerCase()}:$port';
  }

  /// URL passed to a PAC script: the origin only. The path and query of a
  /// signed attachment URL never reach the OS or a PAC script.
  static Uri _origin(Uri url) {
    final secure = url.scheme == 'https' || url.scheme == 'wss';
    return Uri(
      scheme: secure ? 'https' : 'http',
      host: url.host,
      port: url.hasPort ? url.port : null,
      path: '/',
    );
  }

  // -- the asynchronous fill -----------------------------------------------------

  void _refreshIfStale() {
    final at = _snapshotAt;
    if (_snapshotLoad != null) return;
    if (at == null || _now().difference(at) > maxAge) {
      unawaited(refresh());
    }
  }

  /// Reloads the OS configuration and drops PAC answers. Never throws.
  Future<void> refresh() {
    final running = _snapshotLoad;
    if (running != null) return running;
    return _snapshotLoad = () async {
      try {
        final next = await _resolver.snapshot();
        final changed = !_sameSnapshot(_snapshot, next);
        _snapshot = next;
        _snapshotAt = _now();
        if (changed) {
          _pac.clear();
          _changes.add(null);
        }
      } catch (_) {
        // Keep the last good snapshot; an unreadable OS setting must not break
        // networking. Mark it fresh so a broken query is not retried per request.
        _snapshotAt = _now();
      } finally {
        _snapshotLoad = null;
      }
    }();
  }

  static bool _sameSnapshot(SystemProxySnapshot? a, SystemProxySnapshot b) =>
      a != null &&
      a.mode == b.mode &&
      a.http == b.http &&
      a.https == b.https &&
      a.socks == b.socks &&
      a.pacUrl == b.pacUrl &&
      a.autoDetect == b.autoDetect &&
      a.bypass.excludeSimpleHostnames == b.bypass.excludeSimpleHostnames &&
      a.bypass.patterns.join('\n') == b.bypass.patterns.join('\n');

  void _loadPac(Uri url) {
    final key = _key(url);
    _pacLoads[key] ??= () async {
      try {
        final entries = await _resolver.resolve(_origin(url));
        if (entries.isNotEmpty) {
          final before = _pac[key]?.entries.join(',');
          _pac[key] = (entries: entries, at: _now());
          if (before != entries.join(',')) _changes.add(null);
        }
      } catch (_) {
        // Leave the cache as it was; the static fallback keeps answering.
      } finally {
        _pacLoads.remove(key);
      }
    }();
  }

  /// Warms the caches for [urls] (at start-up and when the network changes).
  /// Bounded; never throws.
  Future<void> warm(Iterable<Uri> urls, {Duration? timeout}) async {
    if (_settings.mode != ProxyMode.system) return;
    final limit = timeout ?? const Duration(seconds: 2);
    try {
      await refresh().timeout(limit);
      final snapshot = _snapshot;
      if (snapshot == null || !snapshot.isPac || !_resolver.canResolvePac)
        return;
      await Future.wait([
        for (final url in urls)
          if (!ProxyBypass.isLoopback(url.host))
            () {
              _loadPac(url);
              return _pacLoads[_key(url)] ?? Future<void>.value();
            }(),
      ]).timeout(limit);
    } on TimeoutException {
      // The request path falls back to the static answer / DIRECT.
    }
  }

  /// Bounded wait before the first request to a host whose proxy is decided by
  /// a PAC script: that is the only case where DIRECT would be wrong. Static
  /// configurations and cache hits return at once.
  Future<void> ready(Uri url) async {
    if (_settings.mode != ProxyMode.system) return;
    if (_environmentDecision(url) != null) return;
    var snapshot = _snapshot;
    if (snapshot == null) {
      try {
        await refresh().timeout(readyTimeout);
      } on TimeoutException {
        return;
      }
      snapshot = _snapshot;
    }
    if (snapshot == null || !snapshot.isPac || !_resolver.canResolvePac) return;
    if (ProxyBypass.isLoopback(url.host) || _pac.containsKey(_key(url))) return;
    _loadPac(url);
    try {
      await (_pacLoads[_key(url)] ?? Future<void>.value()).timeout(
        readyTimeout,
      );
    } on TimeoutException {
      // First request goes out on the static answer.
    }
  }

  // -- status for Settings ------------------------------------------------------

  /// What the next request to [sample] would do.
  ProxyStatus status([Uri? sample]) {
    final url = sample ?? Uri.parse('https://example.com/');
    final decided = _decide(url);
    final firstHttp = decided.decision.entries
        .where((e) => e.isHttp)
        .map((e) => e.authority)
        .firstOrNull;
    final snapshot = _snapshot;
    return ProxyStatus(
      source: decided.source,
      proxy: firstHttp,
      pacUrl: decided.source == ProxySource.pac ? snapshot?.pacUrl : null,
      socksOnly:
          _settings.mode == ProxyMode.system &&
          decided.source != ProxySource.environment &&
          (snapshot?.socksOnly ?? false),
      pacUnsupported:
          _settings.mode == ProxyMode.system &&
          decided.source != ProxySource.environment &&
          (snapshot?.isPac ?? false) &&
          !_resolver.canResolvePac &&
          snapshot?.http == null &&
          snapshot?.https == null,
      hasCredentials:
          _settings.mode == ProxyMode.manual && _settings.hasCredentials,
      credentialsProblem: _settings.mode == ProxyMode.manual
          ? _settings.credentialsProblem
          : null,
    );
  }

  // -- applying it to dart:io ------------------------------------------------------

  /// `findProxy` for [HttpClient]: the cached decision, with the manual proxy's
  /// credentials added (dart:io sends them as preemptive Basic
  /// `Proxy-Authorization`, the only form it supports on a CONNECT tunnel).
  String findProxyForClient(Uri url) {
    final decided = _decide(url);
    final entries = decided.decision.entries;
    if (decided.source == ProxySource.manual &&
        decided.authenticated &&
        !decided.decision.isDirect) {
      final e = entries.first;
      return 'PROXY ${_settings.username}:${_settings.password}@${e.authority}';
    }
    return decided.decision.findProxyString;
  }

  /// Points [client] at this service. Safe to call on any [HttpClient].
  HttpClient apply(HttpClient client) {
    client.findProxy = findProxyForClient;
    return client;
  }

  /// A new [HttpClient] that follows the proxy decision.
  HttpClient createHttpClient([SecurityContext? context]) =>
      // ignore: raft_lints/avoid_unproxied_network_client -- The proxy hook itself: the HttpClient factory and the environment override of the proxy decision.
      apply(HttpClient(context: context));

  /// Makes every plain `HttpClient()` in the process follow the proxy decision,
  /// including third-party packages. The explicit hooks in the Dio adapters and
  /// the WebSocket connector stay: they work even where overrides are replaced.
  void installGlobally() {
    var previous = HttpOverrides.current;
    while (previous is ProxyHttpOverrides) {
      previous = previous.previous;
    }
    HttpOverrides.global = ProxyHttpOverrides(this, previous);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}

/// `HttpOverrides` that wraps the next override (tests install their own).
class ProxyHttpOverrides extends HttpOverrides {
  ProxyHttpOverrides(this.proxy, this.previous);
  final SystemProxy proxy;
  final HttpOverrides? previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final base = previous?.createHttpClient(context);
    return proxy.apply(base ?? super.createHttpClient(context));
  }

  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) =>
      proxy.findProxy(url);
}
