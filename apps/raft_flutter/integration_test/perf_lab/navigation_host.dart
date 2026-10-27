import 'dart:io';

import 'package:drift/native.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

/// Only OS link/push delivery is excluded from the navigation replay. The
/// actual RaftApp owns session restore, app routing and WorkspaceController.
class LabNavigationContent extends NativeContentCoordinator {
  WorkspaceController? workspace;
  @override
  Future<void> init({List<String> initialArguments = const []}) async {}
  @override
  void bindWorkspace(WorkspaceController? value) => workspace = value;
  @override
  Future<void> dispose() async {
    await super.dispose();
    notifications.dispose();
  }
}

/// A fresh named database per theme/run. Uses production background SQLite,
/// serialization and coalesced cache writes, without warming the next build
/// from a previous run or touching the formal App's cache.
class LabNavigationCache extends DriftWorkspaceCache {
  LabNavigationCache(File file)
    : super(NativeDatabase.createInBackground(file));
  int reads = 0, writesStarted = 0, writesCompleted = 0;

  @override
  Future<dynamic> read(o, p, s, String kind, String id) {
    reads++;
    return super.read(o, p, s, kind, id);
  }

  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    writesStarted++;
    await super.write(o, p, s, kind, id, value);
    writesCompleted++;
  }
}
