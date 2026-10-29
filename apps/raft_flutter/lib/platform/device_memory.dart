import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Device capacity, not the app's current free memory or an allocation promise.
class DeviceMemoryInfo {
  const DeviceMemoryInfo(this.totalBytes, {this.lowRam = false});
  final int totalBytes;
  final bool lowRam;
}

/// One startup read. Unavailable/invalid information selects the low tier.
Future<DeviceMemoryInfo?> readDeviceMemory({
  TargetPlatform? platform,
  MethodChannel channel = const MethodChannel('app.raft/device-memory'),
  Future<String> Function()? readMeminfo,
}) async {
  try {
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.linux) {
      final text =
          await (readMeminfo?.call() ?? File('/proc/meminfo').readAsString());
      final match = RegExp(
        r'^MemTotal:\s+(\d+)\s+kB$',
        multiLine: true,
      ).firstMatch(text);
      final kib = int.tryParse(match?.group(1) ?? '');
      return kib != null && kib > 0 ? DeviceMemoryInfo(kib * 1024) : null;
    }
    final value = await channel.invokeMapMethod<String, dynamic>('snapshot');
    final bytes = value?['totalBytes'];
    if (bytes is! int || bytes <= 0) return null;
    return DeviceMemoryInfo(bytes, lowRam: value?['lowRam'] == true);
  } catch (_) {
    return null;
  }
}
