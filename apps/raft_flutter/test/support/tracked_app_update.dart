import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:raft_flutter/platform/app_update.dart';

import 'memory_storage.dart';

/// Exercises the real service while recording consumer ownership and order.
class TrackedAppUpdate extends AppUpdateService {
  TrackedAppUpdate(this.name, this.events)
    : super(
        currentVersion: '0.1.0',
        currentBuild: 20,
        platformKey: 'android-arm64',
        scheduleTimer: false,
        storage: MemoryStorage(),
        fetch: (_) async => jsonEncode([
          {
            'platform': 'android',
            'arch': 'arm64',
            'version': '0.1.0',
            'buildNumber': '37',
            'releaseTag': 'v0.1.0+5',
            'artifact': 'raft-flutter-android-arm64.apk',
          },
        ]),
      );

  final String name;
  final List<String> events;
  final listeners = <VoidCallback>{};
  int disposals = 0;

  void publish() => notifyListeners();

  @override
  void addListener(VoidCallback listener) {
    events.add('$name:add');
    listeners.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    events.add('$name:remove');
    listeners.remove(listener);
    super.removeListener(listener);
  }

  @override
  void dispose() {
    events.add('$name:dispose:${listeners.length}');
    disposals++;
    super.dispose();
  }
}
