import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
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
}
