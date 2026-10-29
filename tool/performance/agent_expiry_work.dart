// Isolated native profile benchmark for the live-work expiry publication path.
// Copy into apps/raft_flutter/tool and build with --profile --target=<copy>.
// It uses synthetic entities and an injected clock; it does not measure frames,
// CPU idle, sockets, or the complete workspace. Widget tests cover timer-driven
// bar rebuilding; the combined native workload separately measures idle frames.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents'
      ? [
          {'id': 'older', 'name': 'Older'},
          {'id': 'latest', 'name': 'Latest'},
        ]
      : [];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const out = String.fromEnvironment('RAFT_AGENT_EXPIRY_OUT');
  const revision = String.fromEnvironment('RAFT_AGENT_EXPIRY_REVISION');
  final client = RaftClient(
    origin: 'https://agent-expiry-profile.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'fixture-user'});
  client.selectServer('fixture-server');
  final workspace = _Workspace(client)
    ..server = RaftRecord({'id': 'fixture-server', 'role': 'owner'});
  final directory = MessageReferenceDirectory(workspace);
  await workspace.entityDirectory.preload();
  var now = DateTime.utc(2026, 10, 17);
  final activity = ChatAgentPresentation(
    workspace,
    directory,
    clock: () => now,
  );
  var notifications = 0;
  activity.addListener(() => notifications++);
  final samples = <Map<String, int>>[];
  final errors = <String>[];
  void signal(String id) => activity.event(
    RaftEvent('agent:activity', {
      'agentId': id,
      'serverId': 'fixture-server',
      'activity': 'working',
      'detail': '$id task',
    }),
  );
  Map<String, int> measure() {
    final before = notifications;
    final watch = Stopwatch()..start();
    activity.prune();
    watch.stop();
    return {
      'us': watch.elapsedMicroseconds,
      'notifications': notifications - before,
    };
  }

  for (var i = -100; i < 1000; i++) {
    signal('older');
    now = now.add(const Duration(seconds: 30));
    signal('latest');
    now = now.add(const Duration(seconds: 61));
    final older = measure();
    if (activity.items.length != 1 ||
        activity.working.map((i) => i.agentId).join() != 'latest') {
      errors.add('cycle $i: only the older work should have expired');
    }
    now = now.add(const Duration(seconds: 30));
    final latest = measure();
    if (activity.working.isNotEmpty || activity.items.isNotEmpty) {
      errors.add('cycle $i: expired latest work was not cleared');
    }
    final empty = measure();
    if (i >= 0) {
      samples.add({
        'olderUs': older['us']!,
        'olderNotifications': older['notifications']!,
        'latestUs': latest['us']!,
        'latestNotifications': latest['notifications']!,
        'emptyUs': empty['us']!,
        'emptyNotifications': empty['notifications']!,
      });
    }
  }
  final result = {
    'revision': revision,
    'pid': pid,
    'warmupCycles': 100,
    'measuredCycles': samples.length,
    'scope': 'ChatAgentPresentation.prune with a synthetic directory and clock; no frame or CPU-idle claim',
    'samples': samples,
    'errors': errors,
  };
  activity.dispose();
  directory.dispose();
  workspace.dispose();
  await client.dispose();
  File(out).writeAsStringSync('${jsonEncode(result)}\n');
  exit(errors.isEmpty ? 0 : 1);
}
