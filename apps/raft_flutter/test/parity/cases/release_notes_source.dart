import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';

/// Gives the native release-notes reader the same DTO the Web fixture serves.
/// The product continues to use its client release asset, not the server API.
class ParityReleaseNotesSource extends StatefulWidget {
  const ParityReleaseNotesSource({
    super.key,
    required this.load,
    required this.version,
    required this.now,
    required this.platform,
    required this.builder,
  });

  final Future<Object?> Function() load;
  final String version;
  final DateTime now;
  final TargetPlatform platform;
  final Widget Function(AppUpdateService service) builder;

  @override
  State<ParityReleaseNotesSource> createState() =>
      _ParityReleaseNotesSourceState();
}

class _ParityReleaseNotesSourceState extends State<ParityReleaseNotesSource> {
  final storage = _ReleaseNotesMemory();
  late final service = AppUpdateService(
    currentVersion: widget.version,
    currentBuild: 1,
    platformKey: widget.platform == TargetPlatform.android
        ? 'android-arm64'
        : 'linux-x64',
    target: widget.platform,
    storage: storage,
    clock: () => widget.now,
    scheduleTimer: false,
    fetch: (_) async => null,
    releaseNotes: ClientReleaseNotes(
      storage: storage,
      clock: () => widget.now,
      fetch: (_) async => jsonEncode(await widget.load()),
    ),
  );

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(service);
}

class _ReleaseNotesMemory implements SearchMemoryStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
