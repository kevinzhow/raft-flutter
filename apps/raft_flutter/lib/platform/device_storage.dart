import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Free bytes available to this user on the database's volume. Unknown space
/// never authorizes a full database rewrite.
Future<int?> availableDeviceStorage(
  String databasePath, {
  TargetPlatform? platform,
  MethodChannel channel = const MethodChannel('app.raft/device-memory'),
}) async {
  try {
    final directory = File(databasePath).parent.path;
    if ((platform ?? defaultTargetPlatform) == TargetPlatform.linux) {
      final reply = await Process.run(
        'df',
        ['-Pk', '--', directory],
        environment: {'LC_ALL': 'C'},
        includeParentEnvironment: true,
      );
      if (reply.exitCode != 0) return null;
      final columns = '${reply.stdout}'
          .trim()
          .split('\n')
          .last
          .trim()
          .split(RegExp(r'\s+'));
      final available = columns.length >= 4 ? int.tryParse(columns[3]) : null;
      return available == null || available < 0 ? null : available * 1024;
    }
    final bytes = await channel.invokeMethod<int>('availableStorageBytes', {
      'path': directory,
    });
    return bytes != null && bytes >= 0 ? bytes : null;
  } catch (_) {
    return null;
  }
}
