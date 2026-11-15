// Web v1.24.0 pages/HumanLoginSetupPage.tsx:755-760: "Find a server admin" is
// a plain same-tab `<a href="/s/{slug}/members">`, and `/s/:serverSlug/*` is
// an app route (App.tsx:1502 ServerResolver). The person leaves the sign-in
// for that Server's Members page inside Raft, so the app does the same: the
// sheet and the artifact viewer close, and the app's root navigation opens
// the Members page (switching servers when it is another one). Nothing is
// installed, authorized or opened in the browser.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/custom_protocol_link.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_scope.dart';
import 'package:raft_flutter/features/private_app_invite.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'support/close_support.dart' show frames;
import 'support/fake_webview.dart';
import 'support/human_login_fake.dart';

void main() {
  const artifact = 'https://raft-artifacts.com/p/acme/report';
  const callback = 'https://raft-artifacts.com/auth/human/callback';
  final setup =
      'https://app.example.com/login-with-raft/setup?client_id=artifact-share'
      '&return_to=${Uri.encodeComponent(callback)}'
      '&state=st-1&scope=openid+profile&server=srv-1';

  setUpAll(() => WebViewPlatform.instance = FakeWebView());
  setUp(FakeWebView.reset);

  testWidgets('Find a server admin leaves the sign-in and the artifact for '
      'that Server\'s Members page in the app', (t) async {
    final launched = <String>[];
    final opened = <Uri>[];
    final api = FakeHumanLoginApi(
      servers: const [
        HumanLoginServer(id: 'srv-1', slug: 'acme team', name: 'Acme'),
      ],
      client: FakeHumanLoginApi.app(installRequired: true),
    );
    t.view
      ..physicalSize = const Size(390, 1800)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final messenger = t.binding.defaultBinaryMessenger;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    const privacy = MethodChannel('app.raft/html-preview-privacy');
    messenger
      ..setMockMethodCallHandler(launcher, (call) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      })
      ..setMockMethodCallHandler(privacy, (_) async => null);
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(launcher, null)
        ..setMockMethodCallHandler(privacy, null);
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        // The app shell's root navigation owner (app_viewport.dart).
        builder: (context, child) => PrivateAppInviteScope(
          coordinator: 'https://api.example.com',
          onOpen: (location) async => opened.add(location),
          child: child!,
        ),
        home: HumanLoginScope(
          api: api,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  key: const Key('open-link'),
                  onPressed: () =>
                      unawaited(openMessageLink(context, artifact)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('open-link')));
    await frames(t, 25);
    FakeWebView.finish(artifact);
    expect(await FakeWebView.navigate(setup), isFalse);
    await frames(t, 25);

    final link = find.byKey(const ValueKey('human-login-find-admin'));
    expect(link, findsOneWidget);
    await t.ensureVisible(link);
    await t.tap(link);
    await frames(t, 25);

    expect(opened, [Uri.parse('/s/acme%20team/members')]);
    expect(find.byKey(const ValueKey('human-login-sheet')), findsNothing);
    expect(find.byKey(const ValueKey('artifact-viewer')), findsNothing);
    expect(launched, isEmpty);
    expect(api.installs, isEmpty);
    expect(api.authorizations, isEmpty);
    // The viewer did not go back to the artifact's sign-in page first (it
    // blanks its WebView as it closes).
    expect(FakeWebView.loads.where((url) => url != 'about:blank'), [artifact]);
  });
}
