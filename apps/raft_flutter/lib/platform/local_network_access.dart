import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';

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
class LocalNetworkAccess {
  const LocalNetworkAccess();
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
        local = (await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 5))).any(isLocalNetworkAddress);
      } on SocketException {
        return; // The client reports DNS failures through normal request errors.
      } on TimeoutException {
        return;
      }
    }
    if (!local) return;
    if (await _channel.invokeMethod<bool>('ensure', {'request': request}) !=
        true) {
      throw const RaftApiException(localNetworkPermissionError);
    }
  }
}
