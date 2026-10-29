import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_permissions.dart';

const localNetworkPermissionError =
    'Allow nearby devices access in system settings to connect to this local server.';

bool isLocalNetworkAddress(InternetAddress address) {
  // Loopback remains on this device and does not access the LAN.
  if (address.isLoopback) return false;
  final bytes = address.rawAddress;
  if (bytes.length == 4) {
    return bytes[0] == 10 ||
        bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31 ||
        bytes[0] == 192 && bytes[1] == 168 ||
        bytes[0] == 169 && bytes[1] == 254 ||
        bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127 ||
        bytes[0] >= 224;
  }
  if (bytes.take(10).every((b) => b == 0) &&
      bytes[10] == 255 &&
      bytes[11] == 255) {
    return isLocalNetworkAddress(
      InternetAddress.fromRawAddress(bytes.sublist(12)),
    );
  }
  return bytes[0] & 0xfe == 0xfc ||
      bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80 ||
      bytes[0] == 0xff;
}

/// Android LAN access is checked before connecting to a self-hosted server.
/// Passive restoration never opens a system prompt; explicit sign-in may do so.
/// Once the system stops asking ("don't ask again"), an explicit request opens
/// the app's settings page instead, the only place the person can still allow it.
class LocalNetworkAccess {
  const LocalNetworkAccess({
    this.lookup = InternetAddress.lookup,
    this.permissions = const AndroidPermissions(),
  });

  /// Android runtime-permission facts and the app's settings page.
  final AndroidPermissions permissions;

  /// Device record that the permission was requested at least once. Android
  /// answers "should show rationale" false both before the first request and
  /// after "don't ask again"; this record tells them apart.
  static const askedKey = 'raft.local-network.asked.v1';

  /// Tests provide their fixture's addresses without querying the host DNS.
  final Future<List<InternetAddress>> Function(String host) lookup;
  static const _channel = MethodChannel('app.raft/local-network');

  Future<void> ensure(String origin, {bool request = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final host = Uri.parse(origin.trim()).host
        .toLowerCase()
        .replaceAll(RegExp(r'^\[|\]$'), '');
    final literal = InternetAddress.tryParse(host);
    bool local = host.endsWith('.local') || host.endsWith('.local.');
    if (literal != null) {
      local = isLocalNetworkAddress(literal);
    } else if (!local && host != 'localhost') {
      try {
        local = (await lookup(host).timeout(const Duration(seconds: 5)))
            .any(isLocalNetworkAddress);
      } on SocketException {
        return; // The client reports DNS failures through normal request errors.
      } on TimeoutException {
        return;
      }
    }
    if (!local) return;
    final granted = request
        ? await allow()
        : await _channel.invokeMethod<bool>('ensure', {'request': false}) ==
              true;
    if (!granted) throw const RaftApiException(localNetworkPermissionError);
  }

  /// An explicit request: the system prompt, or the app's settings page once
  /// the system stops asking. True when access is granted.
  Future<bool> allow() async {
    if (await _settingsOnly()) {
      await permissions.openAppSettings();
      return false;
    }
    return await _channel.invokeMethod<bool>('ensure', {'request': true}) ==
        true;
  }

  /// True when asking would show nothing (the system will not ask again).
  /// Records the request otherwise. Unknown status (no bridge) means "ask".
  Future<bool> _settingsOnly() async {
    final status = await permissions.status(
      AndroidPermissions.accessLocalNetwork,
    );
    if (status == null || status.sdk < 37 || status.granted) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final asked = prefs.getBool(askedKey) == true;
      if (!status.canPrompt(asked: asked)) return true;
      await prefs.setBool(askedKey, true);
    } catch (_) {}
    return false;
  }

  /// Whether a saved session cannot reach its self-hosted server because the
  /// system has not granted local network access. Never prompts.
  Future<bool> blocked(String origin) async {
    try {
      await ensure(origin);
      return false;
    } on RaftApiException {
      return true;
    }
  }

  /// Restore-time gate: a saved session for a local server that the system
  /// would silently time out on is reported as [SessionRestoreException] of
  /// kind localNetwork, so the person gets an actionable screen instead of
  /// requests that hang. Nothing else about the session is touched.
  Future<void> gateRestore(RaftClient client) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (await client.sessionStore.read(client.origin) == null) return;
    } catch (_) {
      return; // restore reports unreadable storage itself
    }
    if (await blocked(client.origin)) {
      throw const SessionRestoreException(
        SessionRestoreFailureKind.localNetwork,
      );
    }
  }
}
