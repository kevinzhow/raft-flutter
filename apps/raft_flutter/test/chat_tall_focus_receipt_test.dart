import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/test_themes.dart';

import 'chat_tall_focus_scenario.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '[P01] ${dark ? 'dark' : 'light'} centered tall context publishes and releases its cache in a keyboard viewport',
      (tester) => checkTallFocusReceipt(tester, dark: dark),
    );
  }
}
