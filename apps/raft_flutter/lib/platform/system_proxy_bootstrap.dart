import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:raft_client/system_proxy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'proxy_settings_store.dart';
import 'system_proxy_channel.dart';

/// Installs the platform resolver, the process-wide `HttpOverrides` and the
/// saved Settings choice, then warms the cache for [origins]. Bounded: a slow
/// OS lookup delays start-up by at most a couple of seconds and never fails it.
Future<void> startSystemProxy({
  SharedPreferences? preferences,
  Iterable<String> origins = const [],
  SystemProxy? proxy,
  SystemProxyResolver? resolver,
}) async {
  final service = proxy ?? SystemProxy.instance;
  service.useResolver(resolver ?? platformProxyResolver());
  service.installGlobally();
  try {
    service.configure(
      await ProxySettingsStore(preferences: preferences)
          .load()
          .timeout(const Duration(seconds: 3)),
    );
  } catch (_) {
    // Unreadable settings leave "use the system proxy" in force.
  }
  await service.warm([
    for (final origin in origins)
      if (Uri.tryParse(origin) case final uri? when uri.host.isNotEmpty) uri,
  ]);
}

SystemProxyResolver platformProxyResolver() {
  if (kIsWeb) return const NoSystemProxyResolver();
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return ChannelProxyResolver();
  }
  if (Platform.isWindows) return WindowsProxyResolver();
  if (Platform.isLinux) return LinuxProxyResolver();
  return const NoSystemProxyResolver();
}
