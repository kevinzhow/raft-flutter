// Runtime form protocol v3 in the app: the loaded form's protocol is echoed on
// submit, the unavailable form blocks create and save without a Retry, the
// edit defaults write nothing the person did not choose, and the Advanced
// disclosure follows Web (label, opens once per appearance).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_form_wire.dart';

void main() {
  late RuntimeFormRig rig;
  setUp(() => rig = RuntimeFormRig());
  tearDown(() => rig.dispose());

  void serveCodex({
    required Map<String, dynamic> form,
    String? agentId,
    Map<String, dynamic>? model,
  }) {
    final base = runtimeFormBase('codex');
    rig.workspace.routes[agentId == null
        ? base
        : '/agents/$agentId/runtime-form'] = (_) =>
        form;
    rig.workspace.routes['$base/option-sources/model'] = (_) =>
        model ?? runtimeFormFixture('codex.option-source.live.json');
    rig.workspace.routes['$base/option-sources/reasoningEffort'] = (_) =>
        runtimeFormFixture('codex.option-source.reasoning-effort.v3.json');
  }

  group('protocol', () {
    testWidgets('a v3 form is submitted with protocolVersion 3', (t) async {
      serveCodex(form: runtimeFormFixture('codex.form.v3.json'));
      final c = rig.controller('codex');
      await t.runAsync(c.load);
      expect(c.definition!.protocolVersion, 3);
      expect(c.submission['formDefinitionRef'], {
        'protocolVersion': 3,
        'runtimeId': 'codex',
      });
    });

    testWidgets('a v2 form still echoes protocolVersion 2', (t) async {
      serveCodex(form: runtimeFormFixture('codex.form.json'));
      final c = rig.controller('codex');
      await t.runAsync(c.load);
      expect(c.submission['formDefinitionRef'], {
        'protocolVersion': 2,
        'runtimeId': 'codex',
      });
    });

    testWidgets(
      'an untouched Save of an agent with no stored effort writes no effort',
      (t) async {
        final edit = runtimeFormFixture('codex.edit.v3.json');
        (edit['values'] as Map)
          ..['model'] = 'gpt-5.6-sol'
          ..['reasoningEffort'] = null;
        serveCodex(form: edit, agentId: 'a1');
        final c = rig.controller('codex', agentId: 'a1');
        await t.runAsync(c.load);
        expect(c.definition, isNotNull);
        expect(c.values['reasoningEffort'], '');
        expect(c.valuesChanged, isFalse);
        expect(c.validate(), isEmpty);
        final body = c.submission['formValues'] as Map;
        // Default stays Default: the model's own default effort is not written.
        expect(body['reasoningEffort'], '');
        expect(body['model'], 'gpt-5.6-sol');
        // Changing the model hands the effort over to the new model's default.
        final model = c.definition!.fields.firstWhere((f) => f.key == 'model');
        c.change(model, 'gpt-7-preview');
        expect(c.values['reasoningEffort'], 'high');
      },
    );

    testWidgets('a stored effort is kept and saved as stored', (t) async {
      final edit = runtimeFormFixture('codex.edit.v3.json');
      (edit['values'] as Map)
        ..['model'] = 'gpt-5.6-sol'
        ..['reasoningEffort'] = 'low';
      serveCodex(form: edit, agentId: 'a1');
      final c = rig.controller('codex', agentId: 'a1');
      await t.runAsync(c.load);
      expect(c.values['reasoningEffort'], 'low');
      expect((c.submission['formValues'] as Map)['reasoningEffort'], 'low');
    });
  });

  group('unavailable form', () {
    Future<void> pumpFields(WidgetTester t, RuntimeFormController c) async {
      await t.pumpWidget(rig.page(c));
      await settle(t);
    }

    testWidgets(
      'a form that needs a capability this client lacks is unavailable: no retry, create blocked, none after reopen',
      (t) async {
        final form = runtimeFormFixture('codex.form.v3.json')
          ..['requiredClientCapabilities'] = ['future.capability'];
        serveCodex(form: form);
        final c = rig.controller('codex');
        await t.runAsync(c.load);
        await pumpFields(t, c);
        expect(c.unavailable, isTrue);
        expect(c.definition, isNull);
        expect(c.error, isNull);
        expect(c.loading, isFalse);
        expect(
          find.text('Runtime configuration is unavailable.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        // Nothing may be edited or submitted: no option source was read either.
        expect(
          rig.workspace.reads.where((r) => r.path.contains('option-sources')),
          isEmpty,
        );
        // A client that supports the form later (reopened) shows the form and
        // not the notice.
        serveCodex(form: runtimeFormFixture('codex.form.v3.json'));
        final reopened = rig.controller('codex');
        await t.runAsync(reopened.load);
        await t.pumpWidget(rig.page(reopened));
        await settle(t);
        expect(reopened.unavailable, isFalse);
        expect(
          find.text('Runtime configuration is unavailable.'),
          findsNothing,
        );
        expect(runtimeKey('runtime-model'), findsOneWidget);
      },
    );

    testWidgets('a v3 rule this client cannot evaluate is unavailable', (
      t,
    ) async {
      final form = runtimeFormFixture('claude.form.v3.json');
      (form['uiSchema'] as Map)['rules'][0]['condition']['schema'] = {
        'minLength': 1,
      };
      rig.workspace.routes[runtimeFormBase('claude')] = (_) => form;
      final c = rig.controller('claude');
      await t.runAsync(c.load);
      await pumpFields(t, c);
      expect(c.unavailable, isTrue);
      expect(
        find.text('Runtime configuration is unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a runtime row without the v2 marker is unavailable without any request',
      (t) async {
        final c = rig.controller('legacy');
        c.markUnavailable();
        await pumpFields(t, c);
        expect(c.unavailable, isTrue);
        expect(c.loading, isFalse);
        expect(rig.workspace.reads, isEmpty);
        expect(
          find.text('Runtime configuration is unavailable.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets(
      'a failed load shows Retry in the dialog; Retry loads the form and the notice is gone',
      (t) async {
        serveCodex(form: runtimeFormFixture('codex.form.v3.json'));
        rig.workspace.failWith = const RaftApiException('offline');
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: RuntimeFormDialog(
                controller: rig.workspace,
                machineId: 'm',
                runtimeId: 'codex',
                agentId: 'a1',
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(runtimeKey('runtime-form-load-error'), findsOneWidget);
        expect(
          find.textContaining(
            'Runtime configuration is unavailable. Refresh and try again.',
          ),
          findsOneWidget,
        );
        expect(find.textRange.ofSubstring('Retry'), findsOneWidget);
        expect(find.text('Try again'), findsNothing);
        expect(runtimeKey('runtime-model'), findsNothing);
        // The edit form is served now: Retry resolves the condition.
        rig.workspace.failWith = null;
        rig.workspace.routes['/agents/a1/runtime-form'] = (_) =>
            runtimeFormFixture('codex.edit.v3.json');
        await t.tapOnText(find.textRange.ofSubstring('Retry'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(runtimeKey('runtime-form-load-error'), findsNothing);
        expect(find.textRange.ofSubstring('Retry'), findsNothing);
        expect(runtimeKey('runtime-model'), findsOneWidget);
      },
    );
  });

  group('Advanced disclosure', () {
    testWidgets('is labelled Advanced, not More', (t) async {
      serveCodex(form: runtimeFormFixture('codex.form.v3.json'));
      final c = rig.controller('codex');
      await t.runAsync(c.load);
      await t.pumpWidget(rig.page(c));
      await settle(t);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('More'), findsNothing);
    });

    testWidgets(
      'stays closed with no value, opens once when one is set, and the person may close it',
      (t) async {
        serveCodex(form: runtimeFormFixture('codex.form.v3.json'));
        final c = rig.controller('codex');
        await t.runAsync(c.load);
        await t.pumpWidget(rig.page(c));
        await settle(t);
        expect(runtimeKey('runtime-envVars'), findsNothing);
        // A value arrives (the person types one, or a field it belongs to is
        // seeded): the section opens by itself.
        final env = c.definition!.fields.firstWhere((f) => f.key == 'envVars');
        c.change(env, {'A': '1'});
        await settle(t);
        expect(runtimeKey('runtime-envVars'), findsOneWidget);
        // The person closes it: further edits do not reopen it.
        await t.tap(find.text('Advanced'));
        await settle(t);
        expect(runtimeKey('runtime-envVars'), findsNothing);
        c.change(env, {'A': '2'});
        await settle(t);
        expect(runtimeKey('runtime-envVars'), findsNothing);
        // Emptied, then a value again: a new appearance opens it again.
        c.change(env, <String, String>{});
        await settle(t);
        c.change(env, {'B': '1'});
        await settle(t);
        expect(runtimeKey('runtime-envVars'), findsOneWidget);
      },
    );

    testWidgets('an edit with a stored advanced value starts open', (t) async {
      serveCodex(form: runtimeFormFixture('codex.edit.v3.json'), agentId: 'a1');
      final c = rig.controller('codex', agentId: 'a1');
      await t.runAsync(c.load);
      await t.pumpWidget(rig.page(c));
      // The first frame is final: open at once.
      expect(runtimeKey('runtime-envVars'), findsOneWidget);
    });
  });

  testWidgets('v3 rules show and hide fields as the provider changes', (
    t,
  ) async {
    final base = runtimeFormBase('claude');
    rig.workspace.routes[base] = (_) =>
        runtimeFormFixture('claude.form.v3.json');
    for (final (id, file) in [
      ('provider', 'claude.option-source.provider.json'),
      ('authType', 'claude.option-source.auth-type.json'),
      ('model', 'claude.option-source.live.json'),
      ('reasoningEffort', 'claude.option-source.reasoning-effort.v3.json'),
    ]) {
      rig.workspace.routes['$base/option-sources/$id'] = (_) =>
          runtimeFormFixture(file);
    }
    final c = rig.controller('claude');
    await t.runAsync(c.load);
    await t.pumpWidget(rig.page(c));
    await settle(t);
    expect(runtimeKey('runtime-apiUrl'), findsNothing);
    expect(runtimeKey('runtime-apiKey'), findsNothing);
    final provider = c.definition!.fields.firstWhere(
      (f) => f.key == 'provider',
    );
    c.change(provider, 'custom');
    await settle(t);
    expect(runtimeKey('runtime-apiUrl'), findsOneWidget);
    expect(runtimeKey('runtime-apiKey'), findsOneWidget);
    // Switching back hides them again and leaves them out of the submission.
    c.change(provider, 'default');
    await settle(t);
    expect(runtimeKey('runtime-apiUrl'), findsNothing);
    final body = c.submission['formValues'] as Map;
    expect(body.containsKey('apiUrl'), isFalse);
    expect(body.containsKey('apiKey'), isFalse);
  });
}
