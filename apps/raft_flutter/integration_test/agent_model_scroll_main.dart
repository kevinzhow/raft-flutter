// Native input acceptance of the production managed-agent form. The fixture
// supplies only synthetic protocol responses; it never creates a real agent.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/platform/system_fonts.dart';
import 'package:raft_ui/raft_ui.dart';

import '../test/fixtures/long_model_form.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://model-scroll.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s');
  }

  final stream = StreamController<RaftEvent>.broadcast(sync: true);

  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client) {
    server = RaftRecord({'id': 's', 'role': 'owner'});
  }

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'fixture-computer',
            'name': 'Fixture Computer',
            'status': 'online',
            'runtimes': ['opencode'],
          },
        ],
      };
    }
    if (path.endsWith('/runtime-options')) {
      return {
        'options': [
          {'runtimeId': 'opencode', 'canSelectInThisContext': true},
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/opencode')) return longModelForm;
    if (path.endsWith('/runtime-forms/v2/opencode/option-sources/model')) {
      return longModelSource;
    }
    if (path == '/billing/subscription') return <String, dynamic>{};
    throw RaftApiException('Unknown fixture route: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    if (method != 'POST' || path != '/agents') {
      throw StateError('Unexpected command: $method $path');
    }
    // Read-only stdout receipt of the actual production form submission.
    debugPrint('MODEL_SCROLL_SUBMISSION ${jsonEncode(data)}');
    return {'id': 'fixture-agent', 'name': data['name']};
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativeSystemFonts.instance.initialize();
  runApp(const _Harness());
}

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final client = _Client();
  late final workspace = _Workspace(client);
  String result = 'Ready';

  @override
  void dispose() {
    workspace.dispose();
    unawaited(client.stream.close());
    unawaited(client.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: raftTheme(),
    builder: (context, child) => RaftTextScaling(child: child!),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result),
              TextButton(
                onPressed: () async {
                  final created = await showManagedAgentForm(
                    context,
                    workspace,
                    initialName: 'Model-Scroll-Check',
                  );
                  if (mounted && created != null) {
                    setState(() => result = 'Created ${created['name']}');
                  }
                },
                child: const Text('Open Create Agent'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
