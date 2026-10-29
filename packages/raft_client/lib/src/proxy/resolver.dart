import 'proxy_types.dart';

/// The thin per-platform query. Implementations answer asynchronously and may
/// be slow (a PAC download, a Process spawn); [SystemProxy] never waits on them
/// while a request is being made, it keeps their answers in a cache.
abstract interface class SystemProxyResolver {
  /// The OS configuration, independent of any URL.
  Future<SystemProxySnapshot> snapshot();

  /// True when [resolve] can run PAC / auto-detect for one URL. Without it a
  /// PAC-only configuration cannot be honoured and requests go direct.
  bool get canResolvePac;

  /// The OS decision for one URL (PAC evaluated). Only called for URLs whose
  /// path and query were already stripped.
  Future<List<ProxyEntry>> resolve(Uri url);

  /// Fires when the OS says the proxy configuration changed (Android
  /// PROXY_CHANGE). May be empty: caches also expire by age.
  Stream<void> get changes;
}

/// A resolver for platforms and tests without a system proxy.
class NoSystemProxyResolver implements SystemProxyResolver {
  const NoSystemProxyResolver();
  @override
  Future<SystemProxySnapshot> snapshot() async => SystemProxySnapshot.none;
  @override
  bool get canResolvePac => false;
  @override
  Future<List<ProxyEntry>> resolve(Uri url) async => const [];
  @override
  Stream<void> get changes => const Stream<void>.empty();
}
