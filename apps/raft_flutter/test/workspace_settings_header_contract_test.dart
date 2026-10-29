import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/account_settings.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/settings_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'desktop_footer_sidebar_page_test.dart' show shellFonts;
import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;
import 'support/app_services_fixture.dart';

// Actual Source MainLayout SettingsRoute -> SettingsPanel + Sidebar Settings
// composition. Native desktop content begins below the shared global row;
// WorkspaceView must not prepend another full-width Settings page header.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        '${dark ? 'dark' : 'light'} width$width actual Settings has only its own navigation/content header',
        (t) async {
          final (w, api) = await pageFixture(t, section: 'settings');
          api.routes['GET /auth/identities'] = (_) => {
            'passwordConfigured': true,
            'identities': [],
          };
          api.routes['GET /auth/providers'] = (_) => {'providers': []};
          w.navigation.navigate(RaftLocation.parse('/s/demo/settings/account'));
          await shellFonts(t);
          await mountShell(t, w, dark, width: width);
          final header = find.byType(RaftSettingsPanelHeader);
          expect(header, findsOneWidget);
          expect(t.getRect(header).top, width >= 768 ? 48 : 0);
          expect(find.byType(RaftPageHeader), findsNothing);
          expect(find.byType(AccountSettings), findsOneWidget);
          expect(w.location.toString(), '/s/demo/settings/account');
          if (width < 768) {
            await t.tap(find.byKey(const Key('mobile-settings-back')));
            await frames(t, () {});
            await t.pumpAndSettle();
            expect(w.location.toString(), '/s/demo/settings');
            expect(find.byType(RaftSettingsPanelHeader), findsNothing);
            expect(find.byType(RaftMobileRootHeader), findsOneWidget);
            expect(find.byType(RaftPageHeader), findsNothing);
          } else {
            await t.tap(
              find.byKey(
                const ValueKey('workspace-settings-nav-language-region'),
              ),
            );
            await frames(t, () {});
            await t.pumpAndSettle();
            expect(w.location.toString(), '/s/demo/settings/language-region');
            expect(t.getRect(find.byType(RaftSettingsPanelHeader)).top, 48);
            expect(find.byType(RaftPageHeader), findsNothing);
          }
          await retire(t);
        },
        variant: TargetPlatformVariant({TargetPlatform.linux}),
      );
    }

    testWidgets(
      '${dark ? 'dark' : 'light'} actual Account draft/focus and one header survive every theme-transition frame',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'settings');
        api.routes['GET /auth/identities'] = (_) => {
          'passwordConfigured': true,
          'identities': [],
        };
        api.routes['GET /auth/providers'] = (_) => {'providers': []};
        w.client.user = RaftRecord({
          'id': 'alice',
          'name': 'alice',
          'displayName': 'Alice',
        });
        w.navigation.navigate(RaftLocation.parse('/s/demo/settings/account'));
        await shellFonts(t);
        await mountShell(t, w, dark);
        final field = find.byKey(const Key('account-profile-display-name'));
        await t.tap(field);
        await t.enterText(field, 'Unsaved account draft');
        final input = t.widget<TextField>(field);
        input.controller!.value = const TextEditingValue(
          text: 'Unsaved account draft',
          selection: TextSelection(baseOffset: 3, extentOffset: 8),
          composing: TextRange(start: 3, end: 8),
        );
        final editing = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final state = t.state(editing);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: !dark),
            home: withAppServices(
              WorkspaceView(
                controller: w,
                appearance: RaftAppearance(),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          ),
        );
        for (var frame = 0; frame < 16; frame++) {
          await t.pump(const Duration(milliseconds: 16));
          expect(
            find.byType(RaftSettingsPanelHeader),
            findsOneWidget,
            reason: 'frame $frame',
          );
          expect(
            t.getRect(find.byType(RaftSettingsPanelHeader)).top,
            48,
            reason: 'frame $frame',
          );
          expect(
            find.byType(RaftPageHeader),
            findsNothing,
            reason: 'frame $frame',
          );
          expect(t.state(editing), same(state), reason: 'frame $frame');
          final current = t.widget<TextField>(field);
          expect(
            current.controller,
            same(input.controller),
            reason: 'frame $frame',
          );
          expect(current.controller!.text, 'Unsaved account draft');
          expect(
            current.controller!.selection,
            const TextSelection(baseOffset: 3, extentOffset: 8),
          );
          expect(
            current.controller!.value.composing,
            const TextRange(start: 3, end: 8),
          );
          expect(t.widget<EditableText>(editing).focusNode.hasFocus, true);
          expect(w.location.toString(), '/s/demo/settings/account');
          expect(t.takeException(), isNull);
        }
        expect(find.byType(RaftSettingsPage), findsOneWidget);
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
}
