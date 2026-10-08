import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  List<Map<String, dynamic>> machines = [];
  List<String> runtimes = [];
  Map<String, dynamic>? billing;
  final posts = <Map<String, dynamic>>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/servers/s/machines') return {'machines': machines};
    if (path == '/billing/subscription' && billing != null) return billing;
    if (path.endsWith('/runtime-options') && runtimes.isNotEmpty) {
      return {
        'options': [
          for (final r in runtimes)
            {'runtimeId': r, 'canSelectInThisContext': true},
        ],
      };
    }
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path.endsWith('/runtime-forms/v2/codex/option-sources/model')) {
      return {
        ...(msRuntimeForms['forms']['codex']['optionSources']['model'] as Map),
        'options': [
          {'value': 'gpt-5', 'label': 'GPT-5'},
        ],
        'defaultValue': 'gpt-5',
        'customValueAllowed': true,
      };
    }
    throw RaftApiException('Not found: $path', status: 404);
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    posts.add({'method': method, 'path': path, 'data': data});
    return {'id': 'agent-new', 'name': data['name']};
  }
}

const _machine = {
  'id': 'mbp',
  'name': 'Jiachengs-MacBook-Pro',
  'status': 'online',
  'runtimes': ['codex', 'claude'],
};

void main() {
  late _Client c;
  late _Workspace w;
  setUp(() {
    c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });

  Future<Future<Map<String, dynamic>?>> open(
    WidgetTester t, {
    String? name,
    String? description,
  }) async {
    late Future<Map<String, dynamic>?> result;
    await t.binding.setSurfaceSize(const Size(390, 1400));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showManagedAgentForm(
                context,
                w,
                initialName: name,
                initialDescription: description,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return result;
  }

  testWidgets('zero computers shows the connect-a-computer branch', (t) async {
    await open(t);
    expect(find.text('CREATE AGENT'), findsOneWidget);
    expect(find.text('Connect a computer first'), findsOneWidget);
    expect(find.text('Connect a Computer'), findsOneWidget);
    expect(find.text('COMPUTER'), findsNothing);
  });

  testWidgets('capacity banner, invalid prefilled name and pre-admission model', (
    t,
  ) async {
    w
      ..machines = [_machine]
      ..billing = {
        'displayName': 'Free',
        'capacity': {'maxAgents': 2, 'maxUniversalSeats': -1},
        'usage': {'agents': 2, 'universalSeats': 0},
      };
    await open(t, name: 'bad name!!', description: 'Watches screens');
    expect(
      find.textContaining('Agent limit reached (2/2 on Free plan).'),
      findsOneWidget,
    );
    expect(
      find.text('Start with a letter, then letters, numbers, - or _'),
      findsOneWidget,
    );
    expect(find.text('15/3000'), findsOneWidget);
    // No runtime catalog: runtime unselected, declared Claude picker shown.
    expect(find.text('Select…'), findsOneWidget);
    expect(find.text('Claude Opus'), findsOneWidget);
    expect(
      find.textContaining('Could not load models from this Computer.'),
      findsOneWidget,
    );
    await t.tap(find.text('Create Agent'));
    await t.pump();
    expect(w.posts, isEmpty);
  });

  testWidgets('selected runtime submits the v2 form in one dialog', (t) async {
    w
      ..machines = [_machine]
      ..runtimes = ['codex'];
    final result = await open(t, name: 'Product-QA-Bot', description: 'QA');
    expect(find.text('Codex CLI'), findsOneWidget);
    expect(find.text('GPT-5'), findsOneWidget);
    expect(find.text('MORE'), findsOneWidget);
    await t.tap(find.text('Create Agent'));
    await t.pumpAndSettle();
    expect(w.posts, hasLength(1));
    final data = w.posts.single['data'] as Map;
    expect(w.posts.single['path'], '/agents');
    expect(data['name'], 'Product-QA-Bot');
    expect(data['description'], 'QA');
    expect(data['machineId'], 'mbp');
    expect(data['runtime'], 'codex');
    expect(data['formDefinitionRef'], {
      'protocolVersion': 2,
      'runtimeId': 'codex',
    });
    expect((data['formValues'] as Map)['model'], 'gpt-5');
    expect(await result, {'id': 'agent-new', 'name': 'Product-QA-Bot'});
    expect(find.text('CREATE AGENT'), findsNothing);
  });
}
