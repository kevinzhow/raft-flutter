import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_labels.dart';
import 'package:raft_flutter/features/computer_runtime_chip_groups.dart';

/// Web v1.21.12 runtimeCatalog: Copilot CLI is deprecated for new agents and
/// hidden from detection display (`getMachineRuntimeDisplayOptions`), so the
/// Computer detail's Detected Runtimes row has no Copilot chip.
void main() {
  test('Copilot CLI is deprecated and not a detected-runtime chip', () {
    expect(isRuntimeDeprecated('copilot'), isTrue);
    expect(computerRuntimeOptions.map((r) => r.id), isNot(contains('copilot')));
    // The display options are the supported, non-deprecated runtimes; v1.24
    // adds the OAR-only Qwen Code, Qoder and CodeBuddy after them (the
    // generated v1.21 catalog does not carry those three).
    expect(computerRuntimeOptions.map((r) => r.id).toList(), [
      ...runtimeInfos
          .where((r) => r.supported && !isRuntimeDeprecated(r.id))
          .map((r) => r.id),
      'qwen',
      'qoder',
      'codebuddy',
    ]);
  });

  test('Copilot CLI is not creatable', () {
    // getCreatableRuntimeOptions(): supported and not deprecated.
    expect(creatableRuntimeIds, isNot(contains('copilot')));
    expect(creatableRuntimeIds, containsAll(['claude', 'codex', 'pi']));
    // Which runtimes an agent may switch to is the server's runtime-options
    // answer (getExistingAgentRuntimeOptions runs there); the bundled entry
    // only names the runtime and marks it deprecated.
    expect(
      runtimeInfos.firstWhere((r) => r.id == 'copilot').deprecated,
      isTrue,
    );
  });

  testWidgets('formatRuntimeLabelWithStatus: only deprecated runtimes get it', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    expect(runtimeLabelWithStatus(context, 'claude'), 'Claude Code');
    expect(
      runtimeLabelWithStatus(context, 'copilot'),
      'Copilot CLI (deprecated)',
    );
    expect(runtimeLabelWithStatus(context, 'kimi'), 'Kimi CLI (deprecated)');
    expect(
      runtimeLabelWithStatus(context, 'gemini'),
      'Gemini CLI (deprecated)',
    );
    expect(runtimeLabelWithStatus(context, 'kimi-sdk'), 'Kimi Code');
    // Unknown ids fall back to the id itself, no status.
    expect(runtimeLabelWithStatus(context, 'mystery'), 'mystery');
  });
}
