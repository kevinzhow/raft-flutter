import 'dart:async';

import 'package:flutter/services.dart';
import 'package:raft_client/system_proxy.dart';

/// Android, iOS and macOS answer through the `app.raft/system-proxy` channel:
/// `snapshot` (the static OS configuration) and `resolve` (one URL, PAC run by
/// the OS). A host without the bridge (a background engine) answers "no system
/// proxy", which leaves the environment override and DIRECT in charge.
class ChannelProxyResolver implements SystemProxyResolver {
  ChannelProxyResolver({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('app.raft/system-proxy') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _changes.add(null);
    });
  }

  final MethodChannel _channel;
  // ignore: raft_lints/avoid_unreleased_resource -- Process-wide channel owned by the proxy bootstrap for the lifetime of the app; never torn down.
  final _changes = StreamController<void>.broadcast();
  static const _timeout = Duration(seconds: 8);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  bool get canResolvePac => true;

  @override
  Future<SystemProxySnapshot> snapshot() async {
    try {
      final map = await _channel
          .invokeMapMethod<Object?, Object?>('snapshot')
          .timeout(_timeout);
      return map == null
          ? SystemProxySnapshot.none
          : SystemProxySnapshot.fromMap(map);
    } on MissingPluginException {
      return SystemProxySnapshot.none;
    }
  }

  @override
  Future<List<ProxyEntry>> resolve(Uri url) async {
    try {
      final lines = await _channel
          .invokeListMethod<String>('resolve', {'url': url.toString()})
          .timeout(_timeout);
      return parsePacResult((lines ?? const []).join(';'));
    } on MissingPluginException {
      return const [];
    }
  }
}
