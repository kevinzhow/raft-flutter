import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/source_mobile_app_badge.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_shell_contract_test.dart' show mountShell, openHelp, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;
import 'flutter_test_config.dart' show leakDebt;

Future<void> shellFonts(WidgetTester t) => t.runAsync(() async {
  for (final family in [
    'SpaceGrotesk',
    'SpaceMono',
    'HankenGrotesk',
    'Inter',
    'Geist',
    'GeistMono',
  ]) {
    final data = await rootBundle.load(
      'packages/raft_ui/assets/fonts/$family.ttf',
    );
    await (FontLoader(
      'packages/raft_ui/$family',
    )..addFont(Future.value(data))).load();
  }
});

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<bool>']);
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '[K08b] ${dark ? 'dark' : 'light'} native bell moves to global row; footer Help/Settings retain geometry and unseen lifecycle',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await shellFonts(t);
        await mountShell(t, w, dark);
        final help = find.byKey(const Key('rail-help'));
        final settings = find.byKey(const Key('rail-settings'));
        final bell = find.byType(RaftMobileNotificationButton);
        // Notifications move into the 48px global row. Help and Settings keep
        // their 40px footer slots, 6px gap and 8px bottom inset.
        expect(
          find.ancestor(of: bell, matching: find.byType(RaftWorkspaceTopBar)),
          findsOneWidget,
        );
        expect(t.getRect(bell).top, 5.5);
        expect(t.getRect(help).top, 706);
        expect(t.getRect(settings).top, 752);
        expect(t.getSize(bell), const Size(36, 36));
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
      '[K08d] ${dark ? 'dark' : 'light'} actual Pinned and Joint groups reserve measured Source empty drag areas',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await shellFonts(t);
        final presentation = PersonalPresentationStore(desktop: false);
        addTearDown(presentation.dispose);
        await mountShell(t, w, dark, presentation: presentation);
        final pinned = find.byKey(
          const ValueKey('sidebar-group-system:pinned'),
        );
        final joint = find.byKey(const ValueKey('sidebar-group-system:joint'));
        Rect groupRect(Finder group) {
          final sliver = t.renderObject<RenderSliver>(group);
          final header = find.descendant(
            of: group,
            matching: find.byType(RaftSidebarSectionHeader),
          );
          final top = t.getTopLeft(header);
          return Rect.fromLTWH(
            top.dx,
            top.dy,
            t.getSize(header).width,
            sliver.geometry!.scrollExtent,
          );
        }

        expect(groupRect(pinned).height, 89);
        expect(groupRect(joint).height, 68);
        expect(groupRect(joint).top, groupRect(pinned).bottom);
        expect(find.text('Drag channels or DMs here to pin'), findsOneWidget);
        expect(find.text('No joint channels yet'), findsOneWidget);
        await t.tap(
          find.byKey(const ValueKey('sidebar-disclosure-system:pinned')),
        );
        await t.pumpAndSettle();
        expect(groupRect(pinned).height, 40);
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
