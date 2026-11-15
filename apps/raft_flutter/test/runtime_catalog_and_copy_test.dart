import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_metadata_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_models.dart';
import 'package:raft_flutter/features/agent_runtime_labels.dart';
import 'package:raft_flutter/features/runtime_form_dialog.dart';
import 'package:raft_flutter/features/runtime_form_status_copy.dart';
import 'package:raft_ui/raft_ui.dart';

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    ),
  );
  return context;
}

void main() {
  group('catalogs generated at Web v1.21.12', () {
    test(
      'Copilot CLI is deprecated by data, Claude and Codex gained models',
      () {
        expect(isRuntimeDeprecated('copilot'), isTrue);
        expect(creatableRuntimeIds, isNot(contains('copilot')));
        expect(
          runtimeModelCatalog['claude']!.map((m) => m.id),
          contains('claude-haiku-5-5'),
        );
        expect(runtimeModelCatalog['codex']!.take(4).map((m) => m.id), [
          'gpt-6.1-sol',
          'gpt-6-astra',
          'gpt-6-sol',
          'gpt-6-luna',
        ]);
      },
    );

    test('the default Codex model is GPT-6.1 Sol', () {
      expect(defaultRuntimeModel('codex'), 'gpt-6.1-sol');
    });

    test('the model label catalog knows the new ids', () {
      expect(sourceRuntimeModelLabels['codex']!['gpt-6.1-sol'], 'GPT-6.1 Sol');
      expect(
        sourceRuntimeModelLabels['claude']!['claude-haiku-5-5'],
        'Claude Haiku 5.5',
      );
    });
  });

  group('runtime form v2 copy follows Web', () {
    testWidgets('field errors', (tester) async {
      final c = await _context(tester);
      expect(
        runtimeFieldError(c, 'invalid_url'),
        'Base URL must start with http:// or https://.',
      );
      expect(
        runtimeFieldError(c, 'not_a_choice'),
        'Choose one of the available options.',
      );
      expect(
        runtimeFieldError(c, 'unsupported_required'),
        'Update Raft to edit this setting.',
      );
      // The source status line says why, with its retry.
      expect(runtimeFieldError(c, 'source_unavailable'), isNull);
    });

    testWidgets('option source status per reason', (tester) async {
      final c = await _context(tester);
      String text(String status, Object? reason) =>
          runtimeSourceStatusText(c, status: status, reason: reason);
      expect(
        text('unavailable', 'probe_timeout'),
        'This Computer took too long to list the options.',
      );
      expect(
        text('unavailable', 'machine_offline'),
        'This Computer is offline.',
      );
      expect(
        text('unavailable', 'something_new'),
        'The options could not be loaded.',
      );
      expect(
        text('fallback', 'no_models'),
        'This Computer reported no available options. Showing the standard list instead.',
      );
      expect(
        text('fallback', null),
        'The options could not be loaded. Showing the standard list instead.',
      );
    });
  });
}
