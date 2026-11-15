// Option sources in the runtime form, Web v1.24: the stale status line, the
// unavailable group, hint links, the refresh action and the dependents that
// follow their parent source.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_form_wire.dart';

const _stale =
    'This Computer did not answer in time, so these options may be out of date.';
const _reason = 'This model is not installed on this computer yet.';

void main() {
  late RuntimeFormRig rig;
  setUp(() => rig = RuntimeFormRig());
  tearDown(() => rig.dispose());

  final base = runtimeFormBase('codex');

  /// The Codex form with its model source from [model] (a function of the
  /// read's query, so a test can answer differently after a Retry).
  void serve({
    Map<String, dynamic> Function(Map<String, dynamic>? query)? model,
    Map<String, dynamic> Function(Map<String, dynamic> form)? shape,
    String formFile = 'codex.form.v3.json',
  }) {
    final form = runtimeFormFixture(formFile);
    rig.workspace.routes[base] = (_) => shape == null ? form : shape(form);
    rig.workspace.routes['$base/option-sources/model'] = (query) =>
        model?.call(query) ??
        runtimeFormFixture('codex.option-source.live.json');
    rig.workspace.routes['$base/option-sources/reasoningEffort'] = (_) =>
        runtimeFormFixture('codex.option-source.reasoning-effort.v3.json');
  }

  Future<RuntimeFormController> mount(
    WidgetTester t, {
    List<Uri>? opened,
    String? agentId,
  }) async {
    final c = rig.controller('codex', agentId: agentId);
    await t.runAsync(c.load);
    await t.pumpWidget(rig.page(c, opened: opened));
    await settle(t);
    return c;
  }

  Map<String, dynamic> staleSource({bool retryable = true}) => {
    ...runtimeFormFixture('codex.option-source.fallback.json'),
    'reason': 'probe_timeout',
    'retryable': retryable,
    'state': 'stale',
    'fetchedAt': '2026-10-21T08:00:00.000Z',
  };

  group('status line', () {
    testWidgets(
      'a stale list says so instead of the timeout reason; Retry asks again with refresh=1 and the line goes',
      (t) async {
        var asked = 0;
        serve(
          model: (query) {
            asked++;
            return query?['refresh'] == 1
                ? runtimeFormFixture('codex.option-source.live.json')
                : staleSource();
          },
        );
        await mount(t);
        expect(find.textContaining(_stale), findsOneWidget);
        expect(
          find.textContaining('took too long to list the options'),
          findsNothing,
        );
        expect(find.textRange.ofSubstring('Retry'), findsOneWidget);
        // The header refresh would only repeat Retry.
        expect(runtimeKey('runtime-model-refresh-source'), findsNothing);
        await t.tapOnText(find.textRange.ofSubstring('Retry'));
        await settle(t);
        expect(asked, 2);
        expect(
          rig.workspace.reads
              .where((r) => r.path.endsWith('/option-sources/model'))
              .last
              .query?['refresh'],
          1,
        );
        expect(find.textContaining(_stale), findsNothing);
        expect(find.textRange.ofSubstring('Retry'), findsNothing);
      },
    );

    testWidgets('a live list shows no status line', (t) async {
      serve();
      await mount(t);
      expect(find.textContaining(_stale), findsNothing);
      expect(find.textRange.ofSubstring('Retry'), findsNothing);
    });

    testWidgets('an unknown state is not stale: the reason line shows', (
      t,
    ) async {
      serve(model: (_) => {...staleSource(), 'state': 'brand_new_state'});
      await mount(t);
      expect(find.textContaining(_stale), findsNothing);
      expect(
        find.textContaining('took too long to list the options'),
        findsOneWidget,
      );
    });
  });

  group('refresh action', () {
    testWidgets(
      'refreshing a live list re-asks it with refresh=1 and the effort list that follows without it',
      (t) async {
        serve();
        await mount(t);
        expect(runtimeKey('runtime-model-refresh-source'), findsOneWidget);
        final before = rig.workspace.reads.length;
        await t.tap(runtimeKey('runtime-model-refresh-source'));
        await settle(t);
        final after = rig.workspace.reads.skip(before).toList();
        final model = after.where(
          (r) => r.path.endsWith('/option-sources/model'),
        );
        final effort = after.where(
          (r) => r.path.endsWith('/option-sources/reasoningEffort'),
        );
        expect(model, hasLength(1));
        expect(model.single.query?['refresh'], 1);
        expect(effort, hasLength(1), reason: 'the dependent source follows');
        expect(effort.single.query?.containsKey('refresh') ?? false, isFalse);
      },
    );
  });

  group('unavailable options', () {
    Map<String, dynamic> withUnavailable({
      bool custom = false,
      String? group,
    }) => {
      ...runtimeFormFixture('codex.option-source.live.json'),
      'customValueAllowed': custom,
      'unavailableOptions': [
        {
          'value': 'gpt-old',
          'label': 'GPT Old',
          'reason': _reason,
          'group': ?group,
        },
      ],
    };

    testWidgets(
      'are listed in a disabled group after the list, the reason wrapped, and cannot be chosen',
      (t) async {
        serve(model: (_) => withUnavailable());
        final c = await mount(t);
        await t.tap(runtimeKey('runtime-model'));
        await settle(t);
        expect(find.text('Not available on this computer'), findsOneWidget);
        expect(find.text('GPT Old'), findsOneWidget);
        final reason = find.text(_reason);
        expect(reason, findsOneWidget);
        final text = t.widget<Text>(reason);
        expect(text.maxLines, isNull, reason: 'wrapped, not truncated');
        // After the listed models.
        expect(
          t.getTopLeft(find.text('GPT Old')).dy,
          greaterThan(t.getTopLeft(find.text('gpt-5.5').first).dy),
        );
        await t.tap(find.text('GPT Old'), warnIfMissed: false);
        await settle(t);
        expect(c.values['model'], isNot('gpt-old'));
      },
    );

    testWidgets('the server group names the group', (t) async {
      serve(model: (_) => withUnavailable(group: 'saved'));
      await mount(t);
      await t.tap(runtimeKey('runtime-model'));
      await settle(t);
      expect(find.text('Saved providers'), findsOneWidget);
      expect(find.text('Not available on this computer'), findsNothing);
    });

    testWidgets(
      'a stored unavailable value stays selected by its label and reason, and blocks the save on a list-only source',
      (t) async {
        final edit = runtimeFormFixture('codex.edit.v3.json');
        (edit['values'] as Map)['model'] = 'gpt-old';
        rig.workspace.routes['/agents/a1/runtime-form'] = (_) => edit;
        rig.workspace.routes['$base/option-sources/model'] = (_) =>
            withUnavailable();
        rig.workspace.routes['$base/option-sources/reasoningEffort'] = (_) =>
            runtimeFormFixture('codex.option-source.reasoning-effort.v3.json');
        final c = rig.controller('codex', agentId: 'a1');
        await t.runAsync(c.load);
        await t.pumpWidget(rig.page(c));
        await settle(t);
        // Shown by its own label, never the raw id.
        expect(
          t
              .widget<TextField>(
                find.descendant(
                  of: runtimeKey('runtime-model'),
                  matching: find.byType(TextField),
                ),
              )
              .controller!
              .text,
          'GPT Old',
        );
        expect(c.values['model'], 'gpt-old', reason: 'the value is kept');
        expect(c.validate(), {'model': 'option_unavailable'});
        await settle(t);
        expect(
          find.text('Choose one of the available options.'),
          findsOneWidget,
        );
        // Picking a listed model resolves it.
        await t.tap(runtimeKey('runtime-model'));
        await settle(t);
        await t.tap(find.text('gpt-5.5').first);
        await settle(t);
        expect(c.validate(), isEmpty);
        expect(find.text('Choose one of the available options.'), findsNothing);
      },
    );

    testWidgets(
      'on a source that takes typed values the same value is accepted',
      (t) async {
        final edit = runtimeFormFixture('codex.edit.v3.json');
        (edit['values'] as Map)['model'] = 'gpt-old';
        rig.workspace.routes['/agents/a1/runtime-form'] = (_) => edit;
        rig.workspace.routes['$base/option-sources/model'] = (_) =>
            withUnavailable(custom: true);
        rig.workspace.routes['$base/option-sources/reasoningEffort'] = (_) =>
            runtimeFormFixture('codex.option-source.reasoning-effort.v3.json');
        final c = rig.controller('codex', agentId: 'a1');
        await t.runAsync(c.load);
        expect(c.validate()['model'], isNull);
      },
    );
  });

  group('hint links', () {
    const hint =
        'Read [the docs](https://docs.example.test/models) first. Not a link: '
        '[http](http://plain.example.test), [login](https://user:pw@example.test/x).';

    testWidgets(
      'https links are links, opened outside the app; other targets stay text',
      (t) async {
        serve(
          shape: (form) {
            ((form['uiSchema'] as Map)['localization']
                    as Map)['model']['hint'] =
                hint;
            return form;
          },
        );
        final opened = <Uri>[];
        await mount(t, opened: opened);
        expect(find.widgetWithText(RaftTextLink, 'the docs'), findsOneWidget);
        expect(find.textRange.ofSubstring('Not a link'), findsOneWidget);
        expect(
          find.textRange.ofSubstring('[http](http://plain.example.test)'),
          findsOneWidget,
        );
        expect(
          find.textRange.ofSubstring('[login](https://user:pw@example.test/x)'),
          findsOneWidget,
        );
        expect(find.widgetWithText(RaftTextLink, 'http'), findsNothing);
        expect(find.widgetWithText(RaftTextLink, 'login'), findsNothing);
        await t.tap(find.widgetWithText(RaftTextLink, 'the docs'));
        await settle(t);
        expect(opened, [Uri.parse('https://docs.example.test/models')]);
      },
    );

    testWidgets('a hint without links is the plain text it was', (t) async {
      serve();
      await mount(t);
      expect(find.byType(RaftTextLink), findsNothing);
      expect(
        find.textContaining("Models available from this computer's Codex CLI."),
        findsOneWidget,
      );
    });

    test('the parser keeps text between links and drops nothing', () {
      final parts = parseRuntimeFormHint(hint);
      expect(parts.map((p) => p.text).join(), contains('Read the docs first.'));
      expect(parts.where((p) => p.href != null).map((p) => p.href), [
        'https://docs.example.test/models',
      ]);
    });
  });
}
