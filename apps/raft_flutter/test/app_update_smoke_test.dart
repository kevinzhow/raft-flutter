import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/app_update_smoke.dart';
import 'package:raft_updater/raft_updater.dart';

class _Memory implements SearchMemoryStorage {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

AppUpdateService _service(int remoteBuild) => AppUpdateService(
  currentVersion: '0.1.0',
  currentBuild: 71,
  platformKey: 'appimage-x64',
  storage: _Memory(),
  scheduleTimer: false,
  fetch: (_) async => jsonEncode([
    {
      'platform': 'appimage',
      'arch': 'x64',
      'version': '0.1.0',
      'buildNumber': '$remoteBuild',
      'releaseTag': 'v0.1.0+$remoteBuild',
      'artifact': 'raft-flutter-0.1.0+$remoteBuild-appimage-x64.AppImage',
      'sha256': 'ab' * 32,
      'bytes': 10,
      'edSignature': '${'A' * 86}==',
    },
  ]),
);

void main() {
  final origin = Uri.parse('http://127.0.0.1:1');

  test(
    'stays silent without the test origin override, whatever the environment',
    () async {
      final lines = <String>[];
      await runAppImageUpdateSmoke(
        _service(72),
        AppUpdater(environment: const {}),
        origin: null,
        environment: const {'RAFT_UPDATE_SMOKE': '1'},
        write: lines.add,
      );
      expect(lines, isEmpty);
    },
  );

  test('stays silent unless asked to run', () async {
    final lines = <String>[];
    await runAppImageUpdateSmoke(
      _service(72),
      AppUpdater(environment: const {}),
      origin: origin,
      environment: const {},
      write: lines.add,
    );
    expect(lines, isEmpty);
  });

  test('reports an up-to-date build and an unavailable updater', () async {
    final lines = <String>[];
    await runAppImageUpdateSmoke(
      _service(71),
      AppUpdater(environment: const {}),
      origin: origin,
      environment: const {'RAFT_UPDATE_SMOKE': '1'},
      write: lines.add,
    );
    expect(lines.first, startsWith('RAFT_UPDATE_SMOKE running build=71'));
    expect(lines.last, 'RAFT_UPDATE_SMOKE uptodate build=71');
    lines.clear();
    await runAppImageUpdateSmoke(
      _service(72),
      AppUpdater(environment: const {}),
      origin: origin,
      environment: const {'RAFT_UPDATE_SMOKE': '1'},
      write: lines.add,
    );
    expect(lines.last, startsWith('RAFT_UPDATE_SMOKE unavailable '));
  });
}
