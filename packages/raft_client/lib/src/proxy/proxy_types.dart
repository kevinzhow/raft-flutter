/// Pure-Dart proxy model: PAC-result parsing, the OS snapshot, bypass matching
/// and the app's own proxy settings. No dart:io, so every rule is unit-tested
/// on any host.
library;

enum ProxyKind { http, socks, unsupported, direct }

/// One answer of a PAC script or of the OS: where to send one request.
class ProxyEntry {
  const ProxyEntry.direct() : kind = ProxyKind.direct, host = '', port = 0;
  const ProxyEntry(this.kind, this.host, this.port);

  final ProxyKind kind;
  final String host;
  final int port;

  bool get isHttp => kind == ProxyKind.http;

  /// `host:port` with IPv6 literals bracketed, for display and `findProxy`.
  String get authority => host.contains(':') ? '[$host]:$port' : '$host:$port';

  @override
  String toString() => switch (kind) {
    ProxyKind.direct => 'DIRECT',
    ProxyKind.http => 'PROXY $authority',
    ProxyKind.socks => 'SOCKS $authority',
    ProxyKind.unsupported => 'UNSUPPORTED $authority',
  };

  @override
  bool operator ==(Object other) =>
      other is ProxyEntry &&
      other.kind == kind &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(kind, host, port);
}

/// Splits `host:port`, `[v6]:port` and `scheme://host:port[/]`. Null if there
/// is no usable host. A missing port falls back to [defaultPort].
({String host, int port})? parseHostPort(String text, {int defaultPort = 80}) {
  var value = text.trim();
  final scheme = value.indexOf('://');
  if (scheme >= 0) value = value.substring(scheme + 3);
  final slash = value.indexOf('/');
  if (slash >= 0) value = value.substring(0, slash);
  final at = value.lastIndexOf('@');
  if (at >= 0) value = value.substring(at + 1);
  if (value.isEmpty) return null;
  String host;
  String? portText;
  if (value.startsWith('[')) {
    final close = value.indexOf(']');
    if (close < 0) return null;
    host = value.substring(1, close);
    final rest = value.substring(close + 1);
    if (rest.startsWith(':')) portText = rest.substring(1);
  } else {
    final colon = value.lastIndexOf(':');
    if (colon >= 0 && value.indexOf(':') == colon) {
      host = value.substring(0, colon);
      portText = value.substring(colon + 1);
    } else {
      host = value;
    }
  }
  host = host.trim();
  if (host.isEmpty) return null;
  var port = defaultPort;
  if (portText != null && portText.trim().isNotEmpty) {
    final parsed = int.tryParse(portText.trim());
    if (parsed == null || parsed <= 0 || parsed > 65535) return null;
    port = parsed;
  }
  return (host: host, port: port);
}

/// Parses a PAC `FindProxyForURL` result such as
/// `PROXY a:8080; SOCKS5 b:1080; DIRECT`. Unknown or malformed tokens are
/// dropped. `HTTPS` (a TLS proxy) is [ProxyKind.unsupported]: dart:io cannot
/// speak TLS to a proxy.
List<ProxyEntry> parsePacResult(String result) {
  final entries = <ProxyEntry>[];
  for (final raw in result.split(';')) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    final space = token.indexOf(RegExp(r'\s'));
    final word = (space < 0 ? token : token.substring(0, space)).toUpperCase();
    final rest = space < 0 ? '' : token.substring(space + 1);
    if (word == 'DIRECT') {
      entries.add(const ProxyEntry.direct());
      continue;
    }
    final target = parseHostPort(
      rest,
      defaultPort: word.startsWith('SOCKS') ? 1080 : 80,
    );
    if (target == null) continue;
    switch (word) {
      case 'PROXY' || 'HTTP':
        entries.add(ProxyEntry(ProxyKind.http, target.host, target.port));
      case 'SOCKS' || 'SOCKS4' || 'SOCKS5':
        entries.add(ProxyEntry(ProxyKind.socks, target.host, target.port));
      case 'HTTPS':
        entries.add(
          ProxyEntry(ProxyKind.unsupported, target.host, target.port),
        );
    }
  }
  return entries;
}

/// What to do with one request after unsupported kinds are dropped.
class ProxyDecision {
  const ProxyDecision(this.entries, {this.skippedUnsupported = false});
  static const direct = ProxyDecision([ProxyEntry.direct()]);

  /// Only HTTP and DIRECT entries; never empty.
  final List<ProxyEntry> entries;

  /// A SOCKS (or TLS-proxy) entry was in the answer and was ignored.
  final bool skippedUnsupported;

  bool get isDirect => entries.every((e) => e.kind == ProxyKind.direct);

  /// A `HttpClient.findProxy` string.
  String get findProxyString => entries.map((e) => e.toString()).join('; ');
}

/// Keeps what dart:io can use. An answer of only SOCKS entries is DIRECT (v1
/// supports HTTP proxies only) and says so through `skippedUnsupported`.
ProxyDecision decisionFromEntries(List<ProxyEntry> entries) {
  final usable = <ProxyEntry>[];
  var skipped = false;
  for (final entry in entries) {
    if (entry.kind == ProxyKind.http || entry.kind == ProxyKind.direct) {
      usable.add(entry);
    } else {
      skipped = true;
    }
    // A DIRECT entry ends the list: nothing after it is ever tried.
    if (entry.kind == ProxyKind.direct) break;
  }
  if (usable.isEmpty) {
    return ProxyDecision(const [
      ProxyEntry.direct(),
    ], skippedUnsupported: skipped);
  }
  return ProxyDecision(usable, skippedUnsupported: skipped);
}

/// Host exclusion shared by every platform's list syntax:
/// `example.com`, `.example.com`, `*.example.com`, `10.*`, `10.0.0.0/8`,
/// `host:port`, `<local>` (dotless names) and `*`.
class ProxyBypass {
  const ProxyBypass(this.patterns, {this.excludeSimpleHostnames = false});
  const ProxyBypass.none()
    : patterns = const [],
      excludeSimpleHostnames = false;

  final List<String> patterns;

  /// `<local>` on Windows, `ExcludeSimpleHostnames` on Apple: names with no
  /// dot go direct.
  final bool excludeSimpleHostnames;

  static bool isLoopback(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' ||
        h.endsWith('.localhost') ||
        h == '::1' ||
        h == '0:0:0:0:0:0:0:1' ||
        RegExp(r'^127\.\d+\.\d+\.\d+$').hasMatch(h);
  }

  bool matches(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return true;
    // Browsers and the OS libraries never proxy the loopback; a developer's
    // local server must keep working under any proxy setting.
    if (isLoopback(host)) return true;
    if (excludeSimpleHostnames && !host.contains('.') && !host.contains(':')) {
      return true;
    }
    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' || uri.scheme == 'wss' ? 443 : 80);
    for (final raw in patterns) {
      var pattern = raw.trim().toLowerCase();
      if (pattern.isEmpty) continue;
      if (pattern == '<local>') {
        if (!host.contains('.') && !host.contains(':')) return true;
        continue;
      }
      if (pattern == '*') return true;
      if (pattern.startsWith('<')) continue;
      final cidr = _cidr(pattern);
      if (cidr != null) {
        if (_inCidr(host, cidr.$1, cidr.$2)) return true;
        continue;
      }
      int? wantPort;
      if (!pattern.startsWith('[')) {
        final colon = pattern.lastIndexOf(':');
        if (colon > 0 && pattern.indexOf(':') == colon) {
          wantPort = int.tryParse(pattern.substring(colon + 1));
          if (wantPort != null) pattern = pattern.substring(0, colon);
        }
      } else if (pattern.contains(']:')) {
        final close = pattern.indexOf(']');
        wantPort = int.tryParse(pattern.substring(close + 2));
        pattern = pattern.substring(0, close + 1);
      }
      if (wantPort != null && wantPort != port) continue;
      if (pattern.startsWith('[') && pattern.endsWith(']')) {
        pattern = pattern.substring(1, pattern.length - 1);
      }
      if (_hostMatches(host, pattern)) return true;
    }
    return false;
  }

  static bool _hostMatches(String host, String pattern) {
    if (pattern.contains('*')) {
      final regex = RegExp(
        '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
      );
      return regex.hasMatch(host);
    }
    if (pattern.startsWith('.')) {
      return host.endsWith(pattern) || host == pattern.substring(1);
    }
    // no_proxy semantics: `example.com` also covers `www.example.com`.
    return host == pattern || host.endsWith('.$pattern');
  }

  static (List<int>, int)? _cidr(String pattern) {
    final slash = pattern.indexOf('/');
    if (slash < 0) return null;
    final bits = int.tryParse(pattern.substring(slash + 1));
    final address = _ipv4(pattern.substring(0, slash));
    if (bits == null || address == null || bits < 0 || bits > 32) return null;
    return (address, bits);
  }

  static List<int>? _ipv4(String text) {
    final parts = text.split('.');
    if (parts.length != 4) return null;
    final bytes = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return null;
      bytes.add(value);
    }
    return bytes;
  }

  static bool _inCidr(String host, List<int> network, int bits) {
    final address = _ipv4(host);
    if (address == null) return false;
    var remaining = bits;
    for (var i = 0; i < 4 && remaining > 0; i++) {
      final take = remaining >= 8 ? 8 : remaining;
      final mask = (0xff << (8 - take)) & 0xff;
      if ((address[i] & mask) != (network[i] & mask)) return false;
      remaining -= take;
    }
    return true;
  }
}

enum SnapshotMode { none, staticProxy, pac }

/// The OS proxy configuration, independent of any URL, plus enough to answer
/// a request synchronously. PAC / auto-detect answers are per URL and come from
/// the platform resolver into the cache.
class SystemProxySnapshot {
  const SystemProxySnapshot({
    this.mode = SnapshotMode.none,
    this.http,
    this.https,
    this.socks,
    this.bypass = const ProxyBypass.none(),
    this.pacUrl,
    this.autoDetect = false,
  });
  static const none = SystemProxySnapshot();

  final SnapshotMode mode;

  /// Static proxies, already normalised to [ProxyKind.http].
  final ProxyEntry? http;
  final ProxyEntry? https;
  final ProxyEntry? socks;
  final ProxyBypass bypass;
  final String? pacUrl;
  final bool autoDetect;

  bool get isPac => mode == SnapshotMode.pac;

  /// The system proxy is configured but only as SOCKS: nothing usable.
  bool get socksOnly =>
      mode == SnapshotMode.staticProxy &&
      http == null &&
      https == null &&
      socks != null;

  ProxyDecision decide(Uri uri) {
    // A PAC configuration may also carry static proxies (Windows keeps both);
    // they answer when the script cannot be evaluated.
    if (mode == SnapshotMode.none) return ProxyDecision.direct;
    if (bypass.matches(uri)) return ProxyDecision.direct;
    final secure = uri.scheme == 'https' || uri.scheme == 'wss';
    final entry = secure ? (https ?? http) : http;
    if (entry != null) return ProxyDecision([entry]);
    return ProxyDecision(const [
      ProxyEntry.direct(),
    ], skippedUnsupported: socks != null);
  }

  /// Builds a snapshot from the channel payload of a native resolver.
  factory SystemProxySnapshot.fromMap(Map<Object?, Object?> map) {
    ProxyEntry? entry(Object? value) {
      if (value is! String || value.isEmpty) return null;
      final target = parseHostPort(value);
      return target == null
          ? null
          : ProxyEntry(ProxyKind.http, target.host, target.port);
    }

    final socksText = map['socks'];
    final socksTarget = socksText is String
        ? parseHostPort(socksText, defaultPort: 1080)
        : null;
    final pac = map['pacUrl'];
    final auto = map['autoDetect'] == true;
    final bypass = <String>[
      for (final value in (map['bypass'] as List?) ?? const []) '$value',
    ];
    final http = entry(map['http']), https = entry(map['https']);
    final socks = socksTarget == null
        ? null
        : ProxyEntry(ProxyKind.socks, socksTarget.host, socksTarget.port);
    final mode = (pac is String && pac.isNotEmpty) || auto
        ? SnapshotMode.pac
        : (http != null || https != null || socks != null)
        ? SnapshotMode.staticProxy
        : SnapshotMode.none;
    return SystemProxySnapshot(
      mode: mode,
      http: http,
      https: https,
      socks: socks,
      bypass: ProxyBypass(
        bypass,
        excludeSimpleHostnames: map['excludeSimple'] == true,
      ),
      pacUrl: pac is String && pac.isNotEmpty ? pac : null,
      autoDetect: auto,
    );
  }
}

/// WinHTTP proxy string: `host:port`, `a:1;b:2`, or
/// `http=h:p;https=h:p;socks=h:p`.
({ProxyEntry? http, ProxyEntry? https, ProxyEntry? socks}) parseWinHttpProxy(
  String text,
) {
  ProxyEntry? http, https, socks;
  ProxyEntry? bare;
  for (final raw in text.split(RegExp(r'[;\s]+'))) {
    final token = raw.trim();
    if (token.isEmpty) continue;
    final eq = token.indexOf('=');
    final scheme = eq >= 0 ? token.substring(0, eq).toLowerCase() : '';
    final value = eq >= 0 ? token.substring(eq + 1) : token;
    // `socks=`, or a `socks5://` URL, is a SOCKS proxy.
    final isSocks =
        scheme == 'socks' || value.toLowerCase().startsWith('socks');
    final target = parseHostPort(value, defaultPort: isSocks ? 1080 : 80);
    if (target == null) continue;
    final http1 = ProxyEntry(ProxyKind.http, target.host, target.port);
    if (isSocks) {
      socks ??= ProxyEntry(ProxyKind.socks, target.host, target.port);
    } else if (scheme == 'http') {
      http ??= http1;
    } else if (scheme == 'https') {
      https ??= http1;
    } else if (scheme.isEmpty) {
      bare ??= http1;
    }
  }
  if (bare != null) {
    http ??= bare;
    https ??= bare;
  }
  return (http: http, https: https, socks: socks);
}

enum ProxyMode { system, manual, direct }

/// The user's choice in Settings > Network. The password lives in secure
/// storage and appears here only in memory; [toString] never prints it.
class ProxySettings {
  const ProxySettings({
    this.mode = ProxyMode.system,
    this.host = '',
    this.port = 0,
    this.username = '',
    this.password = '',
    this.bypass = const [],
  });
  static const system = ProxySettings();

  final ProxyMode mode;
  final String host;
  final int port;
  final String username;
  final String password;
  final List<String> bypass;

  bool get hasManualTarget =>
      host.trim().isNotEmpty && port > 0 && port <= 65535;
  bool get hasCredentials => username.isNotEmpty;

  /// Why the credentials cannot be sent, or null. dart:io only supports
  /// preemptive Basic credentials for HTTPS tunnels through the `findProxy`
  /// string `PROXY user:pass@host:port`, which the SDK splits on `;`, on the
  /// first `:` and on the last `@`, and trims.
  String? get credentialsProblem {
    if (!hasCredentials) return null;
    if (username.contains(':')) return 'username-colon';
    if (password.isEmpty) return 'password-empty';
    if (password.contains(';') || username.contains(';')) {
      return 'semicolon';
    }
    if (password != password.trim() || username != username.trim()) {
      return 'whitespace';
    }
    return null;
  }

  ProxySettings copyWith({
    ProxyMode? mode,
    String? host,
    int? port,
    String? username,
    String? password,
    List<String>? bypass,
  }) => ProxySettings(
    mode: mode ?? this.mode,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    bypass: bypass ?? this.bypass,
  );

  @override
  bool operator ==(Object other) =>
      other is ProxySettings &&
      other.mode == mode &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      _same(other.bypass, bypass);

  @override
  int get hashCode =>
      Object.hash(mode, host, port, username, password, Object.hashAll(bypass));

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Safe to log: the password is never included.
  @override
  String toString() =>
      'ProxySettings(${mode.name}, ${host.isEmpty ? '-' : '$host:$port'}'
      '${hasCredentials ? ', user set' : ''})';
}

/// Splits a user-typed bypass list (commas, semicolons, spaces, newlines).
List<String> parseBypassList(String text) => [
  for (final part in text.split(RegExp(r'[,;\s]+')))
    if (part.trim().isNotEmpty) part.trim(),
];
