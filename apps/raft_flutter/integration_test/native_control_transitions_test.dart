import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../../packages/raft_ui/test/control_transition_paint_test.dart'
    as transitions;

import '../../../packages/raft_ui/test/agent_menu_anchor_test.dart' as menus;
import '../../../packages/raft_ui/test/recipe_button_interaction_test.dart'
    as recipe_buttons;

// Actual native renderer evidence for the shared product controls. These
// controlled fixtures do not establish authentication or full-page parity.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  transitions.main();
  menus.main();
  recipe_buttons.main();
  tearDownAll(() async {
    if (!Platform.isAndroid || transitions.evidencePath.isEmpty) return;
    final dir = Directory(
      transitions.evidencePath == 'cache'
          ? '${Directory.systemTemp.path}/raft-transition-proof'
          : transitions.evidencePath,
    );
    await File('${dir.path}/native-receipt.json').writeAsString(
      jsonEncode({
        'sourceHash': const String.fromEnvironment('RAFT_TEST_SOURCE_HASH'),
        'platform': 'android',
        'scope': 'shared-control-native-renderer',
        'results': binding.results,
        'frames': transitions.frameSequence,
      }),
    );
    // Flutter removes the test APK on exit. Let the host collect only this
    // public fixture evidence before its cache disappears.
    final acknowledgement = File('${dir.path}/collected');
    for (var i = 0; i < 150 && !await acknowledgement.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(
      await acknowledgement.exists(),
      true,
      reason: 'Host must collect the Android transition evidence.',
    );
  });
}
