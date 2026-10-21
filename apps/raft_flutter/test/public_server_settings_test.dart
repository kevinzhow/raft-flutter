// The public server page, v1.21.12: Settings tabs for a signed-in non-member
// (Web PublicServerPage.tsx `publicSettingsGroups`, `SettingsPanel`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/public_server_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('settings tabs', () {
    testWidgets('a signed-in non-member gets the personal and resource tabs', (
      t,
    ) async {
      await mountPublicServer(t, account: nonMemberAccount());
      await openPublicSettings(t);
      for (final label in [
        'Account',
        'Language & Region',
        'Appearance',
        'About',
        'Documentation',
        'Feedback',
        'Release Notes',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Web order: Personal (Account, Language & Region, Appearance), then
      // Resources (About, Documentation, Feedback, Release Notes).
      double top(String label) => t.getTopLeft(find.text(label).first).dy;
      expect(top('Account'), lessThan(top('Language & Region')));
      expect(top('Language & Region'), lessThan(top('Appearance')));
      expect(top('Appearance'), lessThan(top('About')));
      expect(top('About'), lessThan(top('Documentation')));
      expect(top('Documentation'), lessThan(top('Feedback')));
      expect(top('Feedback'), lessThan(top('Release Notes')));
      // Opens on Account (`useState(authenticated ? "account" : "about")`).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('public-server-settings-surface')),
          matching: find.byType(RaftSettingsPanelHeader),
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<RaftSettingsPanelHeader>(
              find.byType(RaftSettingsPanelHeader),
            )
            .title,
        'Account',
      );
    });

    testWidgets('each tab opens its page without a current server', (t) async {
      await mountPublicServer(t, account: nonMemberAccount());
      await openPublicSettings(t);
      String title() => t
          .widget<RaftSettingsPanelHeader>(find.byType(RaftSettingsPanelHeader))
          .title;
      for (final (label, header) in [
        ('Language & Region', 'Language & Region'),
        ('Appearance', 'Appearance'),
        ('About', 'About'),
      ]) {
        await t.tap(find.text(label).first);
        await t.pumpAndSettle();
        expect(title(), header);
        expect(t.takeException(), isNull);
      }
      await t.tap(find.text('Feedback').first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(RaftSettingsPanelHeader), findsOneWidget);
      await t.tap(find.text('Release Notes').first);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('signed out keeps About and Documentation only', (t) async {
      await mountPublicServer(t);
      await openPublicSettings(t);
      expect(find.text('About'), findsWidgets);
      expect(find.text('Documentation'), findsOneWidget);
      for (final label in [
        'Account',
        'Language & Region',
        'Appearance',
        'Feedback',
        'Release Notes',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets('the Help menu opens Feedback and the Mobile app (About)', (
      t,
    ) async {
      await mountPublicServer(t, account: nonMemberAccount());
      await t.tap(find.byKey(const ValueKey('public-rail-help')));
      await t.pumpAndSettle();
      await t.tap(find.text('Feedback'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-server-settings-surface')),
        findsOneWidget,
      );
      expect(
        t
            .widget<RaftSettingsPanelHeader>(
              find.byType(RaftSettingsPanelHeader),
            )
            .title,
        'Feedback',
      );
    });
  });
}
