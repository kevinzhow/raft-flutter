import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('About lists Version, Mobile app (with QR) and Workspace', (
    t,
  ) async {
    var android = 0;
    await t.pumpWidget(
      _host(
        RaftSettingsAbout(
          version: '1.17.5',
          mobileApp: RaftAboutMobileApp(
            onAndroid: () => android++,
            onIos: () {},
            qrUrl: 'https://raft.build/download',
          ),
          workspaceName: 'Visual Server',
          workspaceDetail: '/visual',
        ),
      ),
    );
    for (final section in ['version', 'mobile-app', 'workspace']) {
      expect(find.byKey(ValueKey('settings-about-$section')), findsOneWidget);
    }
    expect(find.text('1.17.5'), findsOneWidget);
    expect(find.text('Or, Scan with your phone'), findsOneWidget);
    await t.tap(find.text('Download for Android'));
    expect(android, 1);
  });

  testWidgets('About Updates card: one row per state, buttons by state', (
    t,
  ) async {
    var checks = 0, updates = 0;
    Future<void> mount(RaftAboutUpdate update) => t.pumpWidget(
      _host(RaftSettingsAbout(version: '1.0.0', update: update)),
    );
    final check = find.byKey(const ValueKey('settings-about-update-check'));
    final action = find.byKey(const ValueKey('settings-about-update-action'));

    await mount(
      RaftAboutUpdate(
        state: RaftAboutUpdateState.upToDate,
        message: 'Latest',
        detail: 'Last checked: today',
        onCheck: () => checks++,
      ),
    );
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Last checked: today'), findsOneWidget);
    expect(action, findsNothing);
    await t.tap(check);
    expect(checks, 1);

    await mount(
      RaftAboutUpdate(
        state: RaftAboutUpdateState.available,
        message: 'New',
        actionLabel: 'Update Now',
        onAction: () => updates++,
        onCheck: () => checks++,
      ),
    );
    expect(find.byType(RaftAttentionDot), findsOneWidget);
    await t.tap(action);
    expect(updates, 1);
    expect(check, findsOneWidget);

    await mount(
      const RaftAboutUpdate(
        state: RaftAboutUpdateState.checking,
        message: 'Checking',
      ),
    );
    expect(find.byType(RaftSpinner), findsOneWidget);
    expect(t.widget<RaftButton>(check).onPressed, isNull);

    await mount(
      const RaftAboutUpdate(
        state: RaftAboutUpdateState.unsupported,
        message: 'No checks',
        detail: 'Reason',
      ),
    );
    expect(check, findsNothing);
    expect(action, findsNothing);
    expect(find.text('Reason'), findsOneWidget);
  });

  testWidgets(
    'About Updates card: installing shows progress, restart offers the action',
    (t) async {
      var cancels = 0, restarts = 0;
      Future<void> mount(RaftAboutUpdate update) => t.pumpWidget(
        _host(RaftSettingsAbout(version: '1.0.0', update: update)),
      );
      final progress = find.byKey(
        const ValueKey('settings-about-update-progress'),
      );
      final action = find.byKey(const ValueKey('settings-about-update-action'));
      final check = find.byKey(const ValueKey('settings-about-update-check'));

      await mount(
        RaftAboutUpdate(
          state: RaftAboutUpdateState.installing,
          message: 'Updating',
          detail: 'Downloading… 40%',
          progress: 0.4,
          actionLabel: 'Cancel',
          onAction: () => cancels++,
        ),
      );
      expect(find.byType(RaftSpinner), findsOneWidget);
      expect(progress, findsOneWidget);
      expect(t.widget<RaftProgressBar>(progress).value, closeTo(40, 1e-9));
      expect(t.widget<RaftButton>(check).onPressed, isNull);
      await t.tap(action);
      expect(cancels, 1);

      await mount(
        RaftAboutUpdate(
          state: RaftAboutUpdateState.restart,
          message: 'Installed',
          actionLabel: 'Restart to Finish',
          onAction: () => restarts++,
        ),
      );
      expect(progress, findsNothing);
      expect(find.byType(RaftSpinner), findsNothing);
      await t.tap(action);
      expect(restarts, 1);
    },
  );

  testWidgets('About without a mobile app or workspace keeps Version only', (
    t,
  ) async {
    await t.pumpWidget(_host(const RaftSettingsAbout(version: 'development')));
    expect(
      find.byKey(const ValueKey('settings-about-mobile-app')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings-about-workspace')),
      findsNothing,
    );
  });

  testWidgets('Release notes: categories in Web order, badges and states', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        const RaftReleaseNotesView(
          status: RaftReleaseNotesStatus.ready,
          releases: [
            RaftReleaseNote(
              id: 'a',
              version: '1.2.0',
              date: '2026-10-08',
              current: true,
              entries: [
                RaftReleaseNoteEntry(RaftReleaseNoteKind.fix, 'Fixed'),
                RaftReleaseNoteEntry(RaftReleaseNoteKind.feature, 'Added'),
              ],
            ),
            RaftReleaseNote(id: 'b', date: '2026-10-01', retracted: true),
          ],
        ),
      ),
    );
    expect(find.text('1.2.0 (2026-10-08)'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Retracted'), findsOneWidget);
    expect(find.text('2026-10-01'), findsOneWidget);
    // RELEASE_CATEGORY_ORDER: New before Fix regardless of entry order.
    expect(
      t.getTopLeft(find.text('New')).dy,
      lessThan(t.getTopLeft(find.text('Fix')).dy),
    );

    var retried = 0;
    await t.pumpWidget(
      _host(
        RaftReleaseNotesView(
          status: RaftReleaseNotesStatus.error,
          onRetry: () => retried++,
        ),
      ),
    );
    expect(
      find.text('Release notes are unavailable right now.'),
      findsOneWidget,
    );
    await t.tap(find.text('Try Again'));
    expect(retried, 1);

    await t.pumpWidget(
      _host(const RaftReleaseNotesView(status: RaftReleaseNotesStatus.loading)),
    );
    expect(find.text('Loading release notes…'), findsOneWidget);
  });
}
