import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

void main() {
  testWidgets(
    'mounted account appearance switches to Chinese and remains actionable',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (w, _) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.section = 'settings';
      RaftAppearance? changed;
      final workspace = withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (value) async {
            changed = value;
          },
          onLogout: () async {},
        ),
      );
      Widget application(Locale locale) => MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        home: workspace,
      );
      await tester.pumpWidget(application(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(application(const Locale('zh', 'CN')));
      await tester.pumpAndSettle();
      // The current mode picker is three preview cards; its group label is
      // accessible semantics rather than a repeated visible heading.
      expect(find.bySemanticsLabel('明暗模式'), findsOneWidget);
      for (final label in ['浅色', '深色', '系统']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('appearance-theme-system')),
          matching: find.text('已保存到此设备。'),
        ),
        findsOneWidget,
      );
      expect(find.text('Appearance'), findsNothing);
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(changed?.mode, ThemeMode.dark);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
