import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _agent = {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': 'inactive',
  'activity': 'offline',
  'runtime': 'codex',
  'model': 'gpt-5-codex',
  'machineId': 'm1',
  'reasoningEffort': 'medium',
  'creatorType': 'user',
  'creatorId': 'alice',
};

const _form = {
  'protocolVersion': 2,
  'runtimeId': 'codex',
  'schemaVersion': 'codex.edit.fixture.v1',
  'dataSchema': {
    'type': 'object',
    'required': ['model'],
    'properties': {
      'model': {
        'type': 'string',
        'title': 'Model from Computer',
        'x-optionSource': 'model',
      },
      'command': {'type': 'string', 'title': 'Command from Computer'},
    },
  },
  'uiSchema': {
    'order': ['model', 'command'],
  },
  'optionSources': {
    'model': {
      'protocolVersion': 1,
      'runtimeId': 'codex',
      'schemaVersion': 'codex.edit.fixture.v1',
      'sourceId': 'model',
      'kind': 'select',
      'pointer': '/model',
    },
  },
  'values': {'model': 'loaded-model', 'command': 'loaded-command'},
};

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.test',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  bool v2 = true, formFails = false;
  var admissions = Completer<void>();
  final models = Completer<void>();
  final definition = Completer<void>();
  final optionSource = Completer<void>();
  final calls = <(String, String, dynamic)>[];
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    calls.add((method, path, data));
    if (path == '/agents') return [_agent];
    if (path == '/agents/a1') return _agent;
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/agents/a1/migration') return {'migration': null};
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Fixture Computer',
            'status': 'online',
            'runtimes': ['codex'],
          },
        ],
      };
    }
    if (path == '/agents/a1/runtime-options') {
      await admissions.future;
      return {
        'options': [
          {
            'runtimeId': 'codex',
            'canSelectInThisContext': true,
            if (v2) 'runtimeFormV2': {'protocolVersion': 2},
          },
        ],
      };
    }
    if (path.endsWith('/runtime-models/codex')) {
      await models.future;
      return {
        'kind': 'live',
        'value': {
          'models': [
            {
              'id': 'gpt-5-codex',
              'label': 'GPT-5 Codex',
              'verified': 'launchable',
            },
          ],
        },
      };
    }
    if (path == '/agents/a1/runtime-form') {
      await definition.future;
      if (formFails) throw const RaftApiException('fixture unavailable');
      return _form;
    }
    if (path.endsWith('/option-sources/model')) {
      await optionSource.future;
      return {
        ...(_form['optionSources'] as Map)['model'] as Map,
        'options': [
          {'value': 'loaded-model', 'label': 'Loaded Model'},
        ],
      };
    }
    throw StateError('Unexpected fixture endpoint: $method $path');
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _editor => _key('agent-runtime-editor');

bool _saveEnabled(WidgetTester t) =>
    t
        .widget<RaftButton>(
          find.descendant(
            of: _key('runtime-editor-save'),
            matching: find.byType(RaftButton),
          ),
        )
        .onPressed !=
    null;

Future<_Client> _mount(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(900, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = _Client();
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'role': 'owner'})
    ..runtimeFormV2WebEnabled = true;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    for (final gate in [c.admissions, c.models, c.definition, c.optionSource]) {
      if (!gate.isCompleted) gate.complete();
    }
    await t.pump();
    w.dispose();
    await c.stream.close();
    await c.dispose();
  });
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: FleetDetail(
          controller: w,
          computers: false,
          initial: const {'id': 'a1'},
          onClose: () {},
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

Future<void> _openFirstFrame(WidgetTester t) async {
  await t.tap(_key('agent-edit-runtime'));
  await t.pump();
}

void _expectLoading(WidgetTester t) {
  expect(_editor, findsOneWidget);
  expect(find.text('Loading runtime configuration…'), findsOneWidget);
  expect(_key('runtime-editor-runtime'), findsNothing);
  expect(_key('runtime-editor-model'), findsNothing);
  expect(_key('runtime-model'), findsNothing);
  expect(find.byType(RuntimeFormFields), findsNothing);
  expect(_saveEnabled(t), isFalse);
  expect(t.takeException(), isNull);
}

Future<void> _loadingFrames(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 16));
    _expectLoading(t);
  }
}

void main() {
  testWidgets(
    'first route frame waits for admission, form and option sources',
    (t) async {
      final c = await _mount(t);
      await _openFirstFrame(t);
      _expectLoading(t);
      await _loadingFrames(t);

      c.admissions.complete();
      await _loadingFrames(t);
      expect(
        c.calls.where((call) => call.$2.endsWith('/runtime-form')),
        hasLength(1),
      );

      c.definition.complete();
      await _loadingFrames(t);
      expect(
        c.calls.where((call) => call.$2.endsWith('/option-sources/model')),
        hasLength(1),
      );

      c.optionSource.complete();
      await t.pumpAndSettle();
      expect(find.text('Loading runtime configuration…'), findsNothing);
      expect(_key('runtime-editor-runtime'), findsNothing);
      expect(find.text('Command from Computer'), findsOneWidget);
      final command = find.descendant(
        of: _key('runtime-command'),
        matching: find.byType(TextField),
      );
      expect(t.widget<TextField>(command).controller!.text, 'loaded-command');
      await t.enterText(command, 'updated-command');
      await t.pump();
      expect(_saveEnabled(t), isTrue);
      await t.tap(_key('runtime-editor-save'));
      await t.pumpAndSettle();
      expect(_editor, findsNothing);
      final patch = c.calls.singleWhere((call) => call.$1 == 'PATCH');
      expect((patch.$3 as Map)['formValues']['command'], 'updated-command');
    },
  );

  testWidgets('legacy fields wait for the initial Computer model read', (
    t,
  ) async {
    final c = (await _mount(t))..v2 = false;
    await _openFirstFrame(t);
    _expectLoading(t);
    c.admissions.complete();
    await _loadingFrames(t);
    c.models.complete();
    await t.pumpAndSettle();
    expect(find.text('Loading runtime configuration…'), findsNothing);
    expect(_key('runtime-editor-runtime'), findsOneWidget);
    expect(_key('runtime-editor-model'), findsOneWidget);
    expect(c.calls.where((call) => call.$2.endsWith('/runtime-form')), isEmpty);
  });

  testWidgets(
    'reopening revalidates cached legacy admission before v2 fields',
    (t) async {
      final c = (await _mount(t))..v2 = false;
      c.admissions.complete();
      c.models.complete();
      await _openFirstFrame(t);
      await t.pumpAndSettle();
      expect(_key('runtime-editor-runtime'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();

      c.v2 = true;
      c.admissions = Completer<void>();
      await _openFirstFrame(t);
      _expectLoading(t);
      c.admissions.complete();
      await _loadingFrames(t);
      c.definition.complete();
      c.optionSource.complete();
      await t.pumpAndSettle();
      expect(_key('runtime-editor-runtime'), findsNothing);
      expect(_key('runtime-model'), findsOneWidget);
    },
  );

  testWidgets('a failed v2 load can retry and reveal only complete values', (
    t,
  ) async {
    final c = (await _mount(t))..formFails = true;
    await _openFirstFrame(t);
    _expectLoading(t);
    c.admissions.complete();
    c.definition.complete();
    await t.pumpAndSettle();
    expect(_key('runtime-editor-form-error'), findsOneWidget);
    expect(_key('runtime-editor-runtime'), findsNothing);
    expect(_key('runtime-command'), findsNothing);

    c.formFails = false;
    await t.tapOnText(find.textRange.ofSubstring('Retry'));
    await _loadingFrames(t);
    c.optionSource.complete();
    await t.pumpAndSettle();
    expect(_key('runtime-editor-form-error'), findsNothing);
    expect(_key('runtime-command'), findsOneWidget);
    expect(find.text('Loading runtime configuration…'), findsNothing);
  });
}
