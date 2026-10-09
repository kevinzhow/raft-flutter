import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_mobile_app_badge.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_shell_contract_test.dart' show mountShell, openHelp, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

Future<void> shellFonts(WidgetTester t) => t.runAsync(() async {
  for (final family in ['HankenGrotesk', 'Inter', 'Geist', 'GeistMono']) {
    final data = await rootBundle.load(
      'packages/raft_ui/assets/fonts/$family.ttf',
    );
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(data))).load();
  }
});

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K08b] $family/$dark actual four footer entries retain Source slot geometry and unseen Help lifecycle',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await shellFonts(t);
        await mountShell(t, w, family, dark);
        final help = find.byKey(const Key('rail-help'));
        final mode = find.byKey(const Key('workspace-mode-toggle'));
        final settings = find.byKey(const Key('rail-settings'));
        final bell = find.byType(RaftMobileNotificationButton);
        expect(t.getRect(bell).top, 592);
        expect(t.getRect(help).top, 642);
        expect(t.getRect(mode).top, 692);
        expect(t.getRect(settings).top, 742);
        expect(t.getSize(bell), const Size(40, 40));
        final glyphs = t.widgetList<RaftIcon>(
          find.descendant(of: mode, matching: find.byType(RaftIcon)),
        );
        expect(glyphs.first.size, family == RaftFamily.brutal ? 18 : 16);
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, true);
        final attention = find.descendant(
          of: help,
          matching: find.byType(RaftRailAttention),
        );
        expect(attention, findsOneWidget);
        final uri = w.location.toString();
        await openHelp(t);
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, true);
        expect(w.location.toString(), uri);
        await t.tap(
          find.descendant(
            of: find.byType(RaftMenuPanel),
            matching: find.text('Mobile App'),
          ),
        );
        await t.pumpAndSettle();
        expect(w.location.toString(), '/s/demo/settings/about');
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, false);
        expect(attention, findsNothing);
        final preferences = (await t.runAsync(SharedPreferences.getInstance))!;
        expect(
          preferences.getString(
            SourceMobileAppBadge.storageKey(w.client.origin, 'alice'),
          ),
          '1',
        );
        w.client.user = RaftRecord({'id': 'bob'});
        w.notifyListeners();
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, true);
        w.client.user = RaftRecord({'id': 'alice'});
        w.notifyListeners();
        await frames(t, () {});
        await t.pumpAndSettle();
        expect(t.widget<RaftWorkspaceHelpMenu>(help).attention, false);
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );

    testWidgets(
      '[K08d] $family/$dark actual Pinned and Joint groups reserve measured Source empty drag areas',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await shellFonts(t);
        final presentation = PersonalPresentationStore(desktop: false);
        addTearDown(presentation.dispose);
        await mountShell(t, w, family, dark, presentation: presentation);
        final pinned = find.byKey(
          const ValueKey('sidebar-group-system:pinned'),
        );
        final joint = find.byKey(const ValueKey('sidebar-group-system:joint'));
        expect(t.getSize(pinned).height, 89);
        expect(t.getSize(joint).height, 68);
        expect(t.getRect(joint).top, t.getRect(pinned).bottom);
        expect(find.text('Drag channels or DMs here to pin'), findsOneWidget);
        expect(find.text('No joint channels yet'), findsOneWidget);
        await t.tap(
          find.byKey(const ValueKey('sidebar-disclosure-system:pinned')),
        );
        await t.pumpAndSettle();
        expect(t.getSize(pinned).height, 40);
        expect(find.text('Drag channels or DMs here to pin'), findsNothing);
        expect(find.text('No joint channels yet'), findsOneWidget);
        presentation.update(presentation.key, hideEmptySections: true);
        await t.pumpAndSettle();
        expect(find.text('No joint channels yet'), findsNothing);
        expect(presentation.value.hideEmptySections, true);
        await retire(t);
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
  }
}
