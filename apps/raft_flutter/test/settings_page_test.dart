import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/account_settings.dart';
import 'package:raft_flutter/features/settings_page.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      );
  Completer<dynamic>? acknowledgement;
  final patches = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'PATCH') {
      patches.add(Map<String, dynamic>.from(data));
      return acknowledgement?.future ?? {};
    }
    return {};
  }

  @override
  Future<void> reloadUser() async {
    user = RaftRecord({
      ...user!.json,
      'displayName': patches.last['displayName'],
    });
  }
}

void main() {
  testWidgets(
    '360px settings selects appearance and keeps both axes actionable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      RaftAppearance? accepted;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftSettingsPage(
              destinations: [
                RaftSettingsDestination(
                  'account',
                  'Account',
                  RaftGlyph.user,
                  (_) => const Text('Account body'),
                ),
                RaftSettingsDestination(
                  'appearance',
                  'Appearance',
                  RaftGlyph.palette,
                  (_) => RaftAppearancePicker(
                    appearance: const RaftAppearance(mode: ThemeMode.light),
                    onChanged: (v) => accepted = v,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workspace-settings-nav-appearance')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').first);
      await tester.pumpAndSettle();
      expect(accepted?.mode, ThemeMode.dark);
      await tester.tap(find.text('System').first);
      await tester.pumpAndSettle();
      expect(accepted?.mode, ThemeMode.system);
      // Both axes are offered at 360px and both are actionable: the theme row
      // carries all three built-in looks, and the mode row still switches.
      for (final theme in builtInAppearanceThemes) {
        expect(find.text(theme.en), findsOneWidget, reason: theme.id);
      }
      // "Actionable" means the tap reaches the callback, not merely that the text
      // is painted. The picker is a pure function of the appearance it is given,
      // so each tap reports its own change against the mode it was built with
      // (light): that is what tells the two axes apart.
      await tester.tap(find.text('Brutal').first);
      await tester.pumpAndSettle();
      expect(accepted?.themeId, brutalThemePackId);
      expect(accepted?.mode, ThemeMode.light,
          reason: 'choosing a theme must not change the mode');
      await tester.tap(find.text('Dark').first);
      await tester.pumpAndSettle();
      expect(accepted?.mode, ThemeMode.dark);
      expect(accepted?.themeId, raftThemePackId,
          reason: 'choosing a mode must not change the theme');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inline profile keeps an edit made during save acknowledgement', (
    tester,
  ) async {
    final client = _Client()
      ..user = RaftRecord({
        'id': 'u',
        'name': 'handle',
        'displayName': 'Before',
        'email': 'fixture@example.invalid',
        'emailVerified': true,
      });
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    addTearDown(client.dispose);
    client.acknowledgement = Completer<dynamic>();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: AccountSettings(controller: w)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final name = find.byKey(const Key('account-profile-display-name'));
    await tester.enterText(name, 'Submitted');
    await tester.pump();
    await tester.tap(find.byKey(const Key('account-save-profile')));
    await tester.pump();
    expect(client.patches.single, {'displayName': 'Submitted'});
    await tester.enterText(name, 'Newer draft');
    client.acknowledgement!.complete({});
    await tester.pumpAndSettle();
    expect(client.patches.single, {'displayName': 'Submitted'});
    expect(tester.widget<TextField>(name).controller!.text, 'Newer draft');
    expect(find.text('Saved'), findsNothing);
  });
  testWidgets(
    'old profile save cannot refresh or overwrite the next principal',
    (tester) async {
      final client = _Client()..user = RaftRecord({'id': 'old', 'name': 'Old'});
      final w = WorkspaceController(client);
      addTearDown(w.dispose);
      addTearDown(client.dispose);
      client.acknowledgement = Completer<dynamic>();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: SingleChildScrollView(child: AccountSettings(controller: w)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('account-profile-display-name')),
        'Old edit',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('account-save-profile')));
      await tester.pump();
      expect(client.patches.single, {'displayName': 'Old edit'});
      client.user = RaftRecord({'id': 'new', 'name': 'New'});
      w.notifyListeners();
      await tester.pump();
      client.acknowledgement!.complete({});
      await tester.pumpAndSettle();
      expect(client.user!.id, 'new');
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('account-profile-display-name')),
            )
            .controller!
            .text,
        'New',
      );
      expect(find.text('Saved'), findsNothing);
    },
  );
}
