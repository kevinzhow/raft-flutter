import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/app_icon_settings_section.dart';
import 'package:raft_flutter/platform/app_icon.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

/// Pumps frames and yields to the real event loop until [done], failing after
/// [timeout] of wall-clock time. A fixed delay or frame count is not enough:
/// the answers come from the real event loop, which a loaded machine starves.
Future<void> settleUntil(
  WidgetTester t,
  bool Function() done, {
  required String what,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final clock = Stopwatch()..start();
  while (!done()) {
    if (clock.elapsed > timeout) {
      fail('Timed out after ${timeout.inSeconds}s waiting for $what');
    }
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pump();
  }
}

void main() {
  const channel = MethodChannel('flutter_dynamic_icon_plus');
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} mounted mobile setting uses its standard header and returns to settings root',
      (t) async {
        String? actual = defaultTargetPlatform == TargetPlatform.iOS
            ? null
            : 'app.raft.raft_flutter.IconYellow';
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'supportsAlternateIcons') return true;
          if (call.method == 'setAlternateIconName') {
            actual = (call.arguments as Map)['iconName'] as String?;
            return null;
          }
          return actual;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        // `select` also tells the native splash (Android) through this
        // channel. Unanswered it falls through to the real engine, whose
        // reply can arrive after the test ended and leave the process-wide
        // NativeAppIcon busy for the next test.
        const launchTheme = MethodChannel('app.raft/launch-theme');
        messenger.setMockMethodCallHandler(launchTheme, (_) async => null);
        addTearDown(
          () => messenger.setMockMethodCallHandler(launchTheme, null),
        );
        final icon = NativeAppIcon.instance;
        final (w, _) = await pageFixture(t, section: 'settings');
        w.navigation.navigate(RaftLocation.parse('/s/demo/settings'));
        await mountShell(t, w, dark, width: 390);
        final destination = find.byKey(
          const ValueKey('workspace-settings-nav-appearance'),
        );
        await t.ensureVisible(destination);
        await t.tap(destination);
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/demo/settings/appearance');
        expect(find.byType(RaftSettingsPanelHeader), findsOneWidget);
        expect(find.byType(AppIconSettingsSection), findsOneWidget);
        final blue = find.byKey(const ValueKey('app-icon-blue'));
        await t.ensureVisible(blue);
        await t.pumpAndSettle();
        // The service is a process-wide singleton: wait for this test's refresh
        // to replace what the previous test left (a chosen blue icon).
        await settleUntil(
          t,
          () =>
              icon.loaded &&
              icon.supported &&
              !icon.busy &&
              icon.selected == RaftAppIconPalette.yellow,
          what: 'the app icon service to read the yellow icon',
        );
        expect(blue.hitTestable(), findsOneWidget);
        await t.tap(blue);
        await settleUntil(
          t,
          () => !icon.busy && icon.selected == RaftAppIconPalette.blue,
          what: 'the icon change to finish',
        );
        await t.pumpAndSettle();
        expect(
          actual,
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'AppIconBlue'
              : 'app.raft.raft_flutter.IconBlue',
        );
        await t.tap(find.byKey(const Key('mobile-settings-back')));
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/demo/settings');
        expect(find.byType(AppIconSettingsSection), findsNothing);
        expect(t.takeException(), isNull);
        await retire(t);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
