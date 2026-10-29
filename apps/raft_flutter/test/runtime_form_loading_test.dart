import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
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
  final sourceGate = Completer<void>();
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/runtime-forms/v2/codex')) {
      return msRuntimeForms['forms']['codex'];
    }
    if (path.endsWith('/runtime-forms/v2/codex/option-sources/model')) {
      await sourceGate.future;
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
}

void main() {
  // A user hit "Null check operator used on a null value" in
  // _RuntimeFormFieldsState.field: the definition was published before its
  // option sources and text editors, and the dialog's entrance animation
  // rebuilt the fields while the sources were still loading.
  testWidgets('fields rebuilt while option sources load do not crash', (
    t,
  ) async {
    final c = _Client()..user = RaftRecord({'id': 'alice'});
    c.selectServer('s');
    final w = _Workspace(c)..server = RaftRecord({'id': 's', 'role': 'owner'});
    final form = RuntimeFormController(
      w,
      machineId: 'mbp',
      runtimeId: 'codex',
      valid: () => true,
    );
    final ticker = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(() async {
      ticker.dispose();
      form.dispose();
      w.dispose();
      await c.stream.close();
      await c.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: Listenable.merge([ticker, form]),
              builder: (context, _) => form.definition == null
                  ? const SizedBox.shrink()
                  : RuntimeFormFields(form: form),
            ),
          ),
        ),
      ),
    );
    unawaited(form.load());
    unawaited(ticker.repeat());
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(t.takeException(), isNull);
    expect(form.definition, isNull);

    w.sourceGate.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull);
    expect(form.definition, isNotNull);
    expect(find.byType(RuntimeFormFields), findsOneWidget);
    ticker.stop();
  });
}
