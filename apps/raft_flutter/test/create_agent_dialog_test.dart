import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/cases/members_settings/runtime_forms.dart';
import 'fixtures/long_model_form.dart';

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
  Object? claudeModels;
  bool longOpenCodeModels = false;
  Completer<dynamic>? runtimeOptionsRead;
  bool failRuntimeOptions = false;
  final posts = <Map<String, dynamic>>[];
  final reads = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    reads.add(path);
    if (path == '/servers/s/machines') return {'machines': machines};
    if (path == '/billing/subscription' && billing != null) return billing;
    if (path.endsWith('/runtime-models/claude') && claudeModels != null) {
      return claudeModels;
    }
    if (longOpenCodeModels) {
      if (path.endsWith('/runtime-forms/v2/opencode')) return longModelForm;
      if (path.endsWith('/runtime-forms/v2/opencode/option-sources/model')) {
        return longModelSource;
      }
    }
    if (path.endsWith('/runtime-options') && runtimes.isNotEmpty) {
      if (failRuntimeOptions) {
        throw RaftApiException.response(
          'Runtime discovery failed.',
          status: 503,
          body: {'error': 'Runtime discovery failed.'},
        );
      }
      if (runtimeOptionsRead case final pending?) return pending.future;
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
    bool settle = true,
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
    if (settle) {
      await t.pumpAndSettle();
    } else {
      await t.pump(const Duration(milliseconds: 300));
    }
    return result;
  }

  testWidgets('runtime discovery shows loading until its options arrive', (
    t,
  ) async {
    w
      ..machines = [
        {
          ..._machine,
          'runtimes': ['codex'],
        },
      ]
      ..runtimes = ['codex'];
    final pending = w.runtimeOptionsRead = Completer<dynamic>();
    try {
      await open(t, name: 'Alice', settle: false);
      await t.pump();
      expect(find.byKey(const Key('runtime-options-loading')), findsOneWidget);
    } finally {
      pending.complete({
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
        ],
      });
      await t.pumpAndSettle();
    }
    expect(find.byKey(const Key('runtime-options-loading')), findsNothing);
    expect(find.text('Codex CLI'), findsOneWidget);
  });

  testWidgets('runtime discovery failure offers a working retry', (t) async {
    w
      ..machines = [
        {
          ..._machine,
          'runtimes': ['codex'],
        },
      ]
      ..runtimes = ['codex']
      ..failRuntimeOptions = true;
    await open(t, name: 'Alice');
    expect(find.textContaining('Runtime discovery failed.'), findsOneWidget);
    w.failRuntimeOptions = false;
    await t.tapOnText(find.textRange.ofSubstring('Retry'));
    await t.pumpAndSettle();
    expect(find.textContaining('Runtime discovery failed.'), findsNothing);
    expect(find.text('Codex CLI'), findsOneWidget);
    expect(w.posts, isEmpty);
    expect(
      w.reads.where((path) => path.endsWith('/runtime-options')),
      hasLength(2),
    );
    await t.tap(find.text('Create Agent'));
    await t.pumpAndSettle();
    expect(w.posts, hasLength(1));
    await open(t, name: 'Alice-Retry');
    expect(find.textContaining('Runtime discovery failed.'), findsNothing);
    expect(find.text('Codex CLI'), findsOneWidget);
  });

  testWidgets('zero computers shows the connect-a-computer branch', (t) async {
    await open(t);
    expect(find.text('CREATE AGENT'), findsOneWidget);
    expect(find.text('Connect a computer first'), findsOneWidget);
    expect(find.text('Connect a Computer'), findsOneWidget);
    expect(find.text('COMPUTER'), findsNothing);
  });

  testWidgets(
    'capacity banner, invalid prefilled name and pre-admission model',
    (t) async {
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
    },
  );

  testWidgets('a live model row without an id does not break the dialog', (
    t,
  ) async {
    w
      ..machines = [_machine]
      ..claudeModels = {
        'kind': 'live',
        'value': {
          'models': [
            {'label': 'Unnamed model'},
          ],
        },
      };
    await open(t);
    expect(t.takeException(), isNull);
    expect(find.text('Unnamed model'), findsOneWidget);
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

  testWidgets('OpenCode creation scrolls to and submits the last live model', (
    t,
  ) async {
    w
      ..machines = [
        {
          ..._machine,
          'runtimes': ['opencode'],
        },
      ]
      ..runtimes = ['opencode'];
    w.longOpenCodeModels = true;
    final result = await open(t, name: 'Model-Scroll-Check');
    await t.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpAndSettle();
    final trigger = find.byKey(const ValueKey('runtime-model'));
    await t.ensureVisible(trigger);
    await t.pumpAndSettle();
    await t.tap(trigger);
    await t.pumpAndSettle();
    final popup = find.byType(RaftComboboxPanel);
    final list = find.descendant(of: popup, matching: find.byType(Scrollable));
    final last = find.descendant(
      of: popup,
      matching: find.text('Fixture Model 39'),
    );
    await t.scrollUntilVisible(
      last,
      200,
      scrollable: list.first,
      maxScrolls: 40,
    );
    await t.tap(last);
    await t.pumpAndSettle();
    expect(find.text('Fixture Model 39'), findsOneWidget);
    await t.ensureVisible(find.text('Create Agent'));
    await t.tap(find.text('Create Agent'));
    await t.pumpAndSettle();
    expect(w.posts.single['data']['formValues']['model'], 'fixture-model-39');
    expect(await result, {'id': 'agent-new', 'name': 'Model-Scroll-Check'});
  });

  testWidgets('a model list is searched, and a typed model is used as is', (
    t,
  ) async {
    w
      ..machines = [_machine]
      ..runtimes = ['codex'];
    final result = await open(t, name: 'Custom-Model');
    // The search input is the field itself (Web RuntimeChoiceCombobox).
    final search = find.descendant(
      of: find.byKey(const ValueKey('runtime-model')),
      matching: find.byType(TextField),
    );
    await t.tap(find.byKey(const ValueKey('runtime-model')));
    await t.pumpAndSettle();
    expect(find.byType(RaftComboboxPanel), findsOneWidget);
    await t.enterText(search, 'gpt');
    await t.pump();
    expect(find.text('Use “gpt”'), findsOneWidget);
    await t.enterText(search, 'my-org/custom-model');
    await t.pump();
    await t.tap(find.text('Use “my-org/custom-model”'));
    await t.pumpAndSettle();
    expect(find.byType(RaftComboboxPanel), findsNothing);
    // The typed value is the field's value, shown in the trigger.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('runtime-model')),
        matching: find.text('my-org/custom-model'),
      ),
      findsOneWidget,
    );
    await t.tap(find.text('Create Agent'));
    await t.pumpAndSettle();
    expect(
      (w.posts.single['data'] as Map)['formValues']['model'],
      'my-org/custom-model',
    );
    expect(await result, isNotNull);
  });

  testWidgets('searching a long live list finds a model by any word', (
    t,
  ) async {
    w
      ..machines = [
        {
          ..._machine,
          'runtimes': ['opencode'],
        },
      ]
      ..runtimes = ['opencode'];
    w.longOpenCodeModels = true;
    await open(t, name: 'Model-Search');
    await t.tap(find.byKey(const ValueKey('runtime-model')));
    await t.pumpAndSettle();
    // The search input is the field itself (Web RuntimeChoiceCombobox).
    final search = find.descendant(
      of: find.byKey(const ValueKey('runtime-model')),
      matching: find.byType(TextField),
    );
    await t.enterText(search, 'fixture 39');
    await t.pump();
    expect(find.text('Fixture Model 39'), findsOneWidget);
    expect(find.text('Fixture Model 38'), findsNothing);
    await t.tap(find.text('Fixture Model 39'));
    await t.pumpAndSettle();
    await t.tap(find.text('Create Agent'));
    await t.pumpAndSettle();
    expect(w.posts.single['data']['formValues']['model'], 'fixture-model-39');
  });
}
