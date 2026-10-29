import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'proxy_types.dart';
import 'resolver.dart';

// winhttp.h layouts. dart:ffi lays the structs out with the platform ABI, so
// the BOOL/DWORD (4 byte) and pointer (8 byte) members get the same padding the
// C compiler gives them.
final class _IeProxyConfig extends ffi.Struct {
  @ffi.Int32()
  external int autoDetect; // BOOL fAutoDetect
  external ffi.Pointer<Utf16> autoConfigUrl; // LPWSTR lpszAutoConfigUrl
  external ffi.Pointer<Utf16> proxy; // LPWSTR lpszProxy
  external ffi.Pointer<Utf16> proxyBypass; // LPWSTR lpszProxyBypass
}

final class _AutoProxyOptions extends ffi.Struct {
  @ffi.Uint32()
  external int flags; // dwFlags
  @ffi.Uint32()
  external int autoDetectFlags; // dwAutoDetectFlags
  external ffi.Pointer<Utf16> autoConfigUrl; // LPCWSTR lpszAutoConfigUrl
  external ffi.Pointer<ffi.Void> reserved; // LPVOID lpvReserved
  @ffi.Uint32()
  external int reserved2; // DWORD dwReserved
  @ffi.Int32()
  external int autoLogonIfChallenged; // BOOL fAutoLogonIfChallenged
}

final class _ProxyInfo extends ffi.Struct {
  @ffi.Uint32()
  external int accessType; // dwAccessType
  external ffi.Pointer<Utf16> proxy; // LPWSTR lpszProxy
  external ffi.Pointer<Utf16> proxyBypass; // LPWSTR lpszProxyBypass
}

const _autoproxyAutoDetect = 0x1, _autoproxyConfigUrl = 0x2;
const _autoDetectDhcp = 0x1, _autoDetectDnsA = 0x2;
const _accessTypeNoProxy = 1;

/// The raw WinHTTP answer for [WindowsProxyResolver.snapshot].
class WindowsIeProxy {
  const WindowsIeProxy({
    this.autoDetect = false,
    this.pacUrl,
    this.proxy,
    this.bypass,
  });
  final bool autoDetect;
  final String? pacUrl, proxy, bypass;
}

/// Turns the IE / Windows "Proxy settings" into a snapshot. Pure, so it is
/// tested on every host.
SystemProxySnapshot windowsSnapshot(WindowsIeProxy ie) {
  final parsed = ie.proxy == null || ie.proxy!.isEmpty
      ? (http: null, https: null, socks: null)
      : parseWinHttpProxy(ie.proxy!);
  final bypassText = ie.bypass ?? '';
  final pac = ie.pacUrl != null && ie.pacUrl!.isNotEmpty ? ie.pacUrl : null;
  final hasStatic =
      parsed.http != null || parsed.https != null || parsed.socks != null;
  return SystemProxySnapshot(
    mode: ie.autoDetect || pac != null
        ? SnapshotMode.pac
        : hasStatic
        ? SnapshotMode.staticProxy
        : SnapshotMode.none,
    http: parsed.http,
    https: parsed.https,
    socks: parsed.socks,
    pacUrl: pac,
    autoDetect: ie.autoDetect,
    bypass: ProxyBypass(
      parseBypassList(bypassText),
      excludeSimpleHostnames: bypassText.toLowerCase().contains('<local>'),
    ),
  );
}

/// Windows: `WinHttpGetIEProxyConfigForCurrentUser` for the configuration and
/// `WinHttpGetProxyForUrl` for auto-detect / PAC. Both run in a short-lived
/// isolate, so a slow WPAD lookup never blocks the UI isolate.
class WindowsProxyResolver implements SystemProxyResolver {
  @override
  bool get canResolvePac => true;

  @override
  Future<SystemProxySnapshot> snapshot() async {
    final ie = await Isolate.run(_readIeConfig);
    return windowsSnapshot(ie);
  }

  @override
  Future<List<ProxyEntry>> resolve(Uri url) async {
    final text = await Isolate.run(() => _proxyForUrl(url.toString()));
    return parsePacResult(text);
  }

  @override
  Stream<void> get changes => const Stream<void>.empty();

  static WindowsIeProxy _readIeConfig() {
    final winhttp = ffi.DynamicLibrary.open('winhttp.dll');
    final kernel = ffi.DynamicLibrary.open('kernel32.dll');
    final read = winhttp
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<_IeProxyConfig>),
          int Function(ffi.Pointer<_IeProxyConfig>)
        >('WinHttpGetIEProxyConfigForCurrentUser');
    final globalFree = kernel
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
        >('GlobalFree');
    final config = calloc<_IeProxyConfig>();
    try {
      if (read(config) == 0) return const WindowsIeProxy();
      String? text(ffi.Pointer<Utf16> p) =>
          p == ffi.nullptr ? null : p.toDartString();
      final ie = WindowsIeProxy(
        autoDetect: config.ref.autoDetect != 0,
        pacUrl: text(config.ref.autoConfigUrl),
        proxy: text(config.ref.proxy),
        bypass: text(config.ref.proxyBypass),
      );
      // The three strings are allocated by WinHTTP with GlobalAlloc.
      for (final p in [
        config.ref.autoConfigUrl,
        config.ref.proxy,
        config.ref.proxyBypass,
      ]) {
        if (p != ffi.nullptr) globalFree(p.cast());
      }
      return ie;
    } finally {
      calloc.free(config);
    }
  }

  /// Runs WPAD / the PAC script for [url]; returns a PAC-style result
  /// (`PROXY a:1;b:2`, `DIRECT`). An empty string means "not decided".
  static String _proxyForUrl(String url) {
    final winhttp = ffi.DynamicLibrary.open('winhttp.dll');
    final kernel = ffi.DynamicLibrary.open('kernel32.dll');
    final open = winhttp
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(
            ffi.Pointer<Utf16>,
            ffi.Uint32,
            ffi.Pointer<Utf16>,
            ffi.Pointer<Utf16>,
            ffi.Uint32,
          ),
          ffi.Pointer<ffi.Void> Function(
            ffi.Pointer<Utf16>,
            int,
            ffi.Pointer<Utf16>,
            ffi.Pointer<Utf16>,
            int,
          )
        >('WinHttpOpen');
    final close = winhttp
        .lookupFunction<
          ffi.Int32 Function(ffi.Pointer<ffi.Void>),
          int Function(ffi.Pointer<ffi.Void>)
        >('WinHttpCloseHandle');
    final forUrl = winhttp
        .lookupFunction<
          ffi.Int32 Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<Utf16>,
            ffi.Pointer<_AutoProxyOptions>,
            ffi.Pointer<_ProxyInfo>,
          ),
          int Function(
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<Utf16>,
            ffi.Pointer<_AutoProxyOptions>,
            ffi.Pointer<_ProxyInfo>,
          )
        >('WinHttpGetProxyForUrl');
    final globalFree = kernel
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>),
          ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Void>)
        >('GlobalFree');

    final agent = 'Raft'.toNativeUtf16();
    final session = open(
      agent,
      _accessTypeNoProxy,
      ffi.nullptr,
      ffi.nullptr,
      0,
    );
    calloc.free(agent);
    if (session == ffi.nullptr) return '';
    final ie = _readIeConfig();
    final options = calloc<_AutoProxyOptions>();
    final info = calloc<_ProxyInfo>();
    final target = url.toNativeUtf16();
    ffi.Pointer<Utf16> pacNative = ffi.nullptr;
    try {
      var flags = 0;
      if (ie.autoDetect) {
        flags |= _autoproxyAutoDetect;
        options.ref.autoDetectFlags = _autoDetectDhcp | _autoDetectDnsA;
      }
      if (ie.pacUrl != null && ie.pacUrl!.isNotEmpty) {
        flags |= _autoproxyConfigUrl;
        pacNative = ie.pacUrl!.toNativeUtf16();
        options.ref.autoConfigUrl = pacNative;
      }
      if (flags == 0) return '';
      options.ref.flags = flags;
      options.ref.autoLogonIfChallenged = 1;
      if (forUrl(session, target, options, info) == 0) return '';
      final proxy = info.ref.proxy == ffi.nullptr
          ? ''
          : info.ref.proxy.toDartString();
      final direct = info.ref.accessType == _accessTypeNoProxy || proxy.isEmpty;
      for (final p in [info.ref.proxy, info.ref.proxyBypass]) {
        if (p != ffi.nullptr) globalFree(p.cast());
      }
      if (direct) return 'DIRECT';
      // `a:1;b:2` or `http=a:1;https=b:2`: PAC-style entries for the parser.
      final parsed = parseWinHttpProxy(proxy);
      final secure = url.startsWith('https');
      final chosen = secure ? (parsed.https ?? parsed.http) : parsed.http;
      if (chosen != null) return 'PROXY ${chosen.authority}';
      if (parsed.socks != null) return 'SOCKS ${parsed.socks!.authority}';
      return 'DIRECT';
    } finally {
      if (pacNative != ffi.nullptr) calloc.free(pacNative);
      calloc.free(target);
      calloc.free(options);
      calloc.free(info);
      close(session);
    }
  }
}
