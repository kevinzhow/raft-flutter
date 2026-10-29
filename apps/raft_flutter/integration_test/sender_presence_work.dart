// Isolated native Profile benchmark of the production sender projection.
// Build this same entrypoint against both revisions, with a distinct native
// bundle ID; RAFT_PERF_OUT is an output file in the named lab environment.
// This measures sender-event/lookup work, not scrolling frames or user data.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_metadata_projection.dart';
import 'package:raft_flutter/features/message_agent_presentation.dart';
import 'package:raft_flutter/features/message_reference_directory.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final agents = [
    for (var i = 0; i < 200; i++)
      {
        'id': 'agent-$i',
        'name': 'Fixture $i',
        'status': 'active',
        'runtime': 'codex',
        'model': 'fixture-model',
        'config': {
          'tools': [
            for (var n = 0; n < 24; n++)
              {
                'name': 'tool-$n',
                'arguments': ['fixture', n, true],
              },
          ],
        },
      },
  ];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/agents' ? agents : [];
}

class _Presentation extends MessageAgentPresentation {
  _Presentation(super.workspace, super.directory);
  int reads = 0;
  @override
  AgentPresentationIdentity? identity(String id) {
    reads++;
    return super.identity(id);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = RaftClient(
    origin: 'https://sender-presence.invalid',
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({'id': 'fixture-user'});
  client.selectServer('fixture-server');
  final workspace = _Workspace(client)
    ..server = RaftRecord({'id': 'fixture-server', 'role': 'owner'});
  final directory = MessageReferenceDirectory(workspace);
  await workspace.entityDirectory.preload();
  final presentation = _Presentation(workspace, directory);
  var notifications = 0;
  for (var i = 0; i < 20; i++) {
    presentation.presenceOf('agent-$i').addListener(() => notifications++);
  }
  final samples = <Map<String, int>>[];
  for (var n = 0; n < 550; n++) {
    final reads = presentation.reads, before = notifications;
    final watch = Stopwatch()..start();
    presentation.event(
      RaftEvent('agent:activity', {
        'agentId': 'agent-3',
        'activity': n.isEven ? 'thinking' : 'working',
        'serverSeq': n + 1,
      }),
    );
    for (var i = 0; i < 20; i++) {
      presentation.identity('agent-$i');
      presentation.display('agent-$i');
    }
    watch.stop();
    if (n >= 50) {
      samples.add({
        'us': watch.elapsedMicroseconds,
        'identityReads': presentation.reads - reads,
        'notifications': notifications - before,
      });
    }
  }
  final result = {
    'scope':
        'Sender projection only; no scrolling/frame or whole-app CPU claim',
    'revision': Platform.environment['RAFT_PERF_REVISION'],
    'warmup': 50,
    'cycles': samples.length,
    'agents': 200,
    'observed': 20,
    'samples': samples,
  };
  presentation.dispose();
  directory.dispose();
  workspace.dispose();
  await client.dispose();
  File(Platform.environment['RAFT_PERF_OUT']!)
      .writeAsStringSync(jsonEncode(result));
  exit(samples.every((s) => s['notifications'] == 1) ? 0 : 1);
}
