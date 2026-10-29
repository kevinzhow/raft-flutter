import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'proxy_types.dart';
import 'resolver.dart';

/// Parses `gsettings list-recursively org.gnome.system.proxy` output into a
/// `schema key -> raw value` map. Values keep GVariant text (`'x'`, `8080`,
/// `true`, `['a', 'b']`, `@as []`).
Map<String, String> parseGsettingsDump(String text) {
  final result = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    final first = line.indexOf(' ');
    if (first <= 0) continue;
    final second = line.indexOf(' ', first + 1);
    if (second <= 0) continue;
    result['${line.substring(0, first)} ${line.substring(first + 1, second)}'] =
        line.substring(second + 1).trim();
  }
  return result;
}

String _gString(String? value) {
  if (value == null) return '';
  final v = value.replaceFirst(RegExp(r'^@\w+\s*'), '').trim();
  if (v.length >= 2 && (v.startsWith("'") || v.startsWith('"'))) {
    return v.substring(1, v.length - 1);
  }
  return v;
}

List<String> _gList(String? value) {
  if (value == null) return const [];
  final v = value.replaceFirst(RegExp(r'^@\w+\s*'), '').trim();
  if (!v.startsWith('[') || !v.endsWith(']')) return const [];
  return [
    for (final m in RegExp('\'([^\']*)\'|"([^"]*)"').allMatches(v))
      m.group(1) ?? m.group(2) ?? '',
  ];
}

/// GNOME `org.gnome.system.proxy` (mode none / manual / auto). Null when the
/// schema is absent or empty.
SystemProxySnapshot? gnomeSnapshot(String dump) {
  final values = parseGsettingsDump(dump);
  final mode = _gString(values['org.gnome.system.proxy mode']);
  if (mode.isEmpty) return null;
  const base = 'org.gnome.system.proxy';
  final ignore = _gList(values['$base ignore-hosts']);
  final bypass = ProxyBypass(ignore);
  switch (mode) {
    case 'manual':
      ProxyEntry? pick(String scheme, ProxyKind kind) {
        final host = _gString(values['$base.$scheme host']);
        final port = int.tryParse(values['$base.$scheme port'] ?? '') ?? 0;
        if (host.isEmpty || port <= 0) return null;
        return ProxyEntry(kind, host, port);
      }

      return SystemProxySnapshot(
        mode: SnapshotMode.staticProxy,
        http: pick('http', ProxyKind.http),
        https: pick('https', ProxyKind.http),
        socks: pick('socks', ProxyKind.socks),
        bypass: bypass,
      );
    case 'auto':
      final url = _gString(values['$base autoconfig-url']);
      return SystemProxySnapshot(
        mode: SnapshotMode.pac,
        pacUrl: url.isEmpty ? null : url,
        autoDetect: url.isEmpty,
        bypass: bypass,
      );
    default:
      return SystemProxySnapshot.none;
  }
}

/// Parses an INI file into `section -> key -> value`.
Map<String, Map<String, String>> parseIni(String text) {
  final result = <String, Map<String, String>>{};
  var section = '';
  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) continue;
    if (line.startsWith('[') && line.endsWith(']')) {
      section = line.substring(1, line.length - 1);
      continue;
    }
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    result.putIfAbsent(section, () => {})[line.substring(0, eq).trim()] = line
        .substring(eq + 1)
        .trim();
  }
  return result;
}

/// KDE `~/.config/kioslaverc` `[Proxy Settings]`. ProxyType: 0 none,
/// 1 manual, 2 PAC script, 3 WPAD, 4 environment variables (left to the
/// environment override, so none here).
SystemProxySnapshot? kdeSnapshot(String ini) {
  final section = parseIni(ini)['Proxy Settings'];
  if (section == null) return null;
  final type = int.tryParse(section['ProxyType'] ?? '') ?? 0;
  final bypass = ProxyBypass(parseBypassList(section['NoProxyFor'] ?? ''));
  switch (type) {
    case 1:
      ProxyEntry? pick(String key, ProxyKind kind) {
        final value = (section[key] ?? '').trim();
        if (value.isEmpty) return null;
        // KDE writes `http://host:3128` or the older `host 3128`.
        final target = parseHostPort(value.replaceFirst(RegExp(r'\s+'), ':'));
        if (target == null) return null;
        return ProxyEntry(kind, target.host, target.port);
      }

      return SystemProxySnapshot(
        mode: SnapshotMode.staticProxy,
        http: pick('httpProxy', ProxyKind.http),
        https: pick('httpsProxy', ProxyKind.http),
        socks: pick('socksProxy', ProxyKind.socks),
        bypass: bypass,
      );
    case 2:
      final url = (section['Proxy Config Script'] ?? '').trim();
      return SystemProxySnapshot(
        mode: SnapshotMode.pac,
        pacUrl: url.isEmpty ? null : url,
        bypass: bypass,
      );
    case 3:
      return SystemProxySnapshot(
        mode: SnapshotMode.pac,
        autoDetect: true,
        bypass: bypass,
      );
    default:
      return SystemProxySnapshot.none;
  }
}

typedef TextSource = Future<String?> Function();
typedef PacEvaluator = Future<List<ProxyEntry>> Function(Uri url);

/// Linux: GNOME gsettings first, then KDE kioslaverc. PAC and WPAD are
/// evaluated by libproxy when the system has it (loaded with dlopen, so it is
/// not a dependency); without it a PAC-only desktop goes direct.
class LinuxProxyResolver implements SystemProxyResolver {
  LinuxProxyResolver({
    TextSource? gsettings,
    TextSource? kioslaverc,
    PacEvaluator? pac,
    bool? pacAvailable,
  }) : _gsettings = gsettings ?? _runGsettings,
       _kioslaverc = kioslaverc ?? _readKioslaverc,
       _pac = pac ?? LibProxy.resolve,
       _pacAvailable = pacAvailable ?? (pac != null || LibProxy.available);

  final TextSource _gsettings, _kioslaverc;
  final PacEvaluator _pac;
  final bool _pacAvailable;

  static Future<String?> _runGsettings() async {
    try {
      final result = await Process.run('gsettings', [
        'list-recursively',
        'org.gnome.system.proxy',
      ]).timeout(const Duration(seconds: 2));
      return result.exitCode == 0 ? result.stdout as String : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readKioslaverc() async {
    final env = Platform.environment;
    final home =
        env['XDG_CONFIG_HOME'] ??
        (env['HOME'] == null ? null : '${env['HOME']}/.config');
    if (home == null) return null;
    final file = File('$home/kioslaverc');
    try {
      return await file.exists() ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SystemProxySnapshot> snapshot() async {
    final gnome = await _gsettings();
    final fromGnome = gnome == null ? null : gnomeSnapshot(gnome);
    // GNOME's schema exists on every GTK desktop, KDE included, where it
    // stays at `none`: an explicit KDE configuration wins in that case.
    if (fromGnome != null && fromGnome.mode != SnapshotMode.none) {
      return fromGnome;
    }
    final kde = await _kioslaverc();
    final fromKde = kde == null ? null : kdeSnapshot(kde);
    return fromKde ?? fromGnome ?? SystemProxySnapshot.none;
  }

  @override
  bool get canResolvePac => _pacAvailable;

  @override
  Future<List<ProxyEntry>> resolve(Uri url) => _pac(url);

  @override
  Stream<void> get changes => const Stream<void>.empty();
}

/// Optional libproxy (`libproxy.so.1`), found at run time. The call can block
/// on a PAC download, so it runs in a short-lived isolate.
class LibProxy {
  static const _names = ['libproxy.so.1', 'libproxy.so.0', 'libproxy.so'];

  static ffi.DynamicLibrary? _open() {
    for (final name in _names) {
      try {
        return ffi.DynamicLibrary.open(name);
      } catch (_) {}
    }
    return null;
  }

  static bool? _available;
  static bool get available => _available ??= _probe();

  static bool _probe() {
    final lib = _open();
    if (lib == null) return false;
    return lib.providesSymbol('px_proxy_factory_new') &&
        lib.providesSymbol('px_proxy_factory_get_proxies');
  }

  static Future<List<ProxyEntry>> resolve(Uri url) async {
    if (!available) return const [];
    final text = await Isolate.run(() => _query(url.toString()));
    return parsePacResult(text);
  }

  /// libproxy answers `http://host:port`, `socks5://h:p` or `direct://`.
  static String _query(String url) {
    final lib = _open();
    if (lib == null) return '';
    final create = lib
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(),
          ffi.Pointer<ffi.Void> Function()
        >('px_proxy_factory_new');
    final get = lib
        .lookupFunction<
          ffi.Pointer<ffi.Pointer<Utf8>> Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<Utf8>,
          ),
          ffi.Pointer<ffi.Pointer<Utf8>> Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<Utf8>,
          )
        >('px_proxy_factory_get_proxies');
    final free = lib
        .lookupFunction<
          ffi.Void Function(ffi.Pointer<ffi.Void>),
          void Function(ffi.Pointer<ffi.Void>)
        >('px_proxy_factory_free');
    final factory = create();
    if (factory == ffi.nullptr) return '';
    final native = url.toNativeUtf8();
    final out = StringBuffer();
    try {
      final list = get(factory, native);
      if (list == ffi.nullptr) return '';
      for (var i = 0; list[i] != ffi.nullptr; i++) {
        final entry = list[i].toDartString();
        if (entry.startsWith('direct://')) {
          out.write('DIRECT;');
        } else if (entry.startsWith('socks')) {
          out.write('SOCKS ${entry.substring(entry.indexOf('://') + 3)};');
        } else if (entry.startsWith('https://')) {
          out.write('HTTPS ${entry.substring(8)};');
        } else if (entry.startsWith('http://')) {
          out.write('PROXY ${entry.substring(7)};');
        }
      }
    } finally {
      calloc.free(native);
      free(factory);
    }
    return out.toString();
  }
}
