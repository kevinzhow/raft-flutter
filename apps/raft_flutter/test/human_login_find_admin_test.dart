// Web v1.24.0 pages/HumanLoginSetupPage.tsx:746-753: when the chosen Server
// has not installed the app and only an owner or admin can install it, the
// page offers "Find a server admin", a link to that Server's members page
// (`/s/{slug}/members`). Without it a member is at a dead end.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart' show frames;
import 'support/human_login_fake.dart';

void main() {
  const callback = 'https://artifacts.example.com/auth/callback';
  final link = find.byKey(const ValueKey('human-login-find-admin'));
  final sheet = find.byKey(const ValueKey('human-login-sheet'));
  late List<Uri> opened;

  Future<void> open(
    WidgetTester t,
    FakeHumanLoginApi api, {
    Locale locale = const Locale('en'),
  }) async {
    opened = [];
    t.view
      ..physicalSize = const Size(390, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => TextButton(
            key: const Key('go'),
            onPressed: () => showHumanLoginSheet(
              context,
              api: api,
              openExternal: (uri) async {
                opened.add(uri);
                return true;
              },
              request: HumanLoginRequest.fromSetupUri(
                Uri.parse(
                  'https://app.example.com/login-with-raft/setup'
                  '?client_id=artifact-share'
                  '&return_to=${Uri.encodeComponent(callback)}&state=st-1'
                  '&scope=openid+profile&server=srv-1',
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('go')));
    await frames(t, 25);
  }

  FakeHumanLoginApi waiting({required bool canInstall}) => FakeHumanLoginApi(
    servers: const [
      HumanLoginServer(id: 'srv-1', slug: 'acme team', name: 'Acme'),
    ],
    client: FakeHumanLoginApi.app(
      installRequired: true,
      canInstall: canInstall,
    ),
  );

  // Inside the app shell the link opens the app's own Members page
  // (human_login_find_admin_in_app_test.dart); without one, Web's page.
  testWidgets('a member who cannot install gets Find a server admin; with no '
      'app shell it opens Web\'s members page and the sign-in stays', (
    t,
  ) async {
    final api = waiting(canInstall: false);
    await open(t, api);
    expect(
      find.textContaining('Only an owner or admin of this Server can install'),
      findsOneWidget,
    );
    expect(link, findsOneWidget);
    expect(t.getSize(link).height, 44);
    expect(find.text('Install and continue'), findsNothing);
    await t.ensureVisible(link);
    await t.tap(link);
    await frames(t, 10);
    expect(opened, [
      Uri.parse('https://app.example.com/s/acme%20team/members'),
    ]);
    expect(api.installs, isEmpty);
    expect(sheet, findsOneWidget);
  });

  testWidgets('an owner or admin who can install sees no such link', (t) async {
    await open(t, waiting(canInstall: true));
    expect(find.text('Install and continue'), findsOneWidget);
    expect(link, findsNothing);
  });

  testWidgets('it reads in Chinese with the Web zh-cn text', (t) async {
    await open(t, waiting(canInstall: false), locale: const Locale('zh', 'CN'));
    expect(
      find.descendant(of: link, matching: find.text('查找服务器管理员')),
      findsOneWidget,
    );
  });
}
