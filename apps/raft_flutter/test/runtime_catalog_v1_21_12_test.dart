import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/agent_runtime_draft.dart';
import 'package:raft_flutter/features/agent_runtime_labels.dart';
import 'package:raft_flutter/features/computer_detail_view.dart';

/// Web v1.21.12 runtimeCatalog: Copilot CLI is deprecated for new agents and
/// hidden from detection display (`getMachineRuntimeDisplayOptions`), so the
/// Computer detail's Detected Runtimes row has no Copilot chip.
void main() {
  test('Copilot CLI is deprecated and not a detected-runtime chip', () {
    expect(isRuntimeDeprecated('copilot'), isTrue);
    expect(computerRuntimeOptions.map((r) => r.$1), isNot(contains('copilot')));
    // The display options are exactly the supported, non-deprecated runtimes.
    expect(
      computerRuntimeOptions.map((r) => r.$1).toList(),
      runtimeInfos
          .where((r) => r.supported && !isRuntimeDeprecated(r.id))
          .map((r) => r.id)
          .toList(),
    );
  });

  test('Copilot CLI is not creatable but stays visible for its own agents', () {
    // getCreatableRuntimeOptions(): supported and not deprecated.
    expect(creatableRuntimeIds, isNot(contains('copilot')));
    expect(creatableRuntimeIds, containsAll(['claude', 'codex', 'pi']));
    // getExistingAgentRuntimeOptions(current): a deprecated runtime is listed
    // only as the agent's own current runtime.
    List<String> ids(String current) =>
        existingAgentRuntimeOptions(current).map((r) => r.id).toList();
    expect(ids('copilot'), contains('copilot'));
    expect(ids('claude'), isNot(contains('copilot')));
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
