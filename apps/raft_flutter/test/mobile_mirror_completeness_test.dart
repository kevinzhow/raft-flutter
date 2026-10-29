// Phone settings, tasks, saved, and chat read the workspace controller.
// There is no second page controller and no presentation copy step.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone pages use the host controller', () {
    final route = File('lib/features/mobile_workspace_route.dart')
        .readAsStringSync();
    final settings = File('lib/features/mobile_settings_route.dart')
        .readAsStringSync();
    final controller = File('lib/data/workspace_controller.dart')
        .readAsStringSync();
    for (final source in [route, settings, controller]) {
      expect(source.contains('_MobilePageController'), isFalse);
      expect(source.contains('_MobilePageNavigation'), isFalse);
      expect(source.contains('synchronizePagePresentation'), isFalse);
    }
    expect(route.contains('WorkspaceController('), isFalse);
    expect(settings.contains('controller: source'), isTrue);
  });
}
