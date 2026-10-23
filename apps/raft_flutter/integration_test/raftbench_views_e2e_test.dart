// RaftBench against a real Raft server (the local test stack), without
// enabling anything (no model call): the page in each appearance, display
// language and width, with the stack's own task and billing data. The language
// is the signed-in user's `displayLanguage` (restored at the end); the
// appearance is the device's.
//
//   flutter test integration_test/raftbench_views_e2e_test.dart -d linux --no-pub \
//     --dart-define=RAFT_TEST_CONFIG=<json: origin, email, password, serverId, channelId> \
//     --dart-define=RAFT_TEST_REPORT=<dir for the PNG captures and the run log>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('RaftBench in every appearance, language and width', (t) async {
    final cfg = raftbenchConfig();
    void size(Size logical, double ratio) {
      t.view.physicalSize = logical * ratio;
      t.view.devicePixelRatio = ratio;
    }

    size(const Size(1280, 800), 1);
    addTearDown(t.view.reset);
    addTearDown(() => writeRunLog('views-run.log'));
    final w = await signIn(t, cfg);
    final oldLanguage = w.client.user!.json['displayLanguage'];

    Future<void> language(String code) async {
      await t.runAsync(() async {
        await w.client.patch('/auth/me', data: {'displayLanguage': code});
        await w.client.reloadUser();
      });
      await t.pumpAndSettle();
      note('display language $code');
    }

    Future<void> appearance(ThemeMode mode) async {
      await openSettingsTab(t, 'appearance');
      final control = find.byKey(const Key('appearance-mode'));
      final label = raftText(t.element(control), switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      });
      final button = find.descendant(of: control, matching: find.text(label));
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      note('appearance $mode');
    }

    Future<void> capture(String name) async {
      await openRaftbench(t);
      await until(
        t,
        () => find
            .byKey(const ValueKey('raftbench-task-snapshot'))
            .evaluate()
            .isNotEmpty,
        what: 'the task snapshot',
      );
      await shot(t, name);
    }

    try {
      await appearance(ThemeMode.light);
      await capture('v01-desktop-light-en');
      await appearance(ThemeMode.dark);
      await capture('v02-desktop-dark-en');
      await language('zh-cn');
      await capture('v03-desktop-dark-zh');
      await appearance(ThemeMode.light);
      await capture('v04-desktop-light-zh');
      size(const Size(390, 844), 2);
      await t.pumpAndSettle();
      await capture('v05-phone-light-zh');
      await appearance(ThemeMode.dark);
      await capture('v06-phone-dark-zh');
      await language('en');
      await capture('v07-phone-dark-en');
      await appearance(ThemeMode.light);
      await capture('v08-phone-light-en');
      // The phone page scrolled to the insights.
      final scroll = find.byKey(const ValueKey('raftbench-scroll'));
      await t.drag(scroll, const Offset(0, -2600));
      await t.pumpAndSettle();
      await shot(t, 'v09-phone-light-en-insights');
      size(const Size(1280, 800), 1);
      await t.pumpAndSettle();
      await capture('v10-desktop-light-en');
    } finally {
      await t.runAsync(() async {
        try {
          await w.client.patch(
            '/auth/me',
            data: {'displayLanguage': oldLanguage},
          );
          note('display language restored to $oldLanguage');
        } catch (e) {
          note('language restore failed: $e');
        }
      });
    }
  });
}
