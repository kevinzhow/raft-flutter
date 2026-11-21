import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/human_login.dart';
import 'package:raft_flutter/features/human_login_sheet.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../support/human_login_fake.dart';
import '../parity_harness.dart';
import 'ext_settings.dart';
import 'members_settings/fixture_client.dart';

Widget _appsPage(ParityContext context) {
  final page = extSettingsPage(context);
  return Builder(
    builder: (contextTheme) => Theme(
      data: Theme.of(contextTheme).copyWith(
        platform: context.props['platform'] == 'desktop'
            ? TargetPlatform.linux
            : TargetPlatform.android,
      ),
      child: page,
    ),
  );
}

final _appsSettings = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceSettings',
    'raft_flutter:IntegrationsView',
    'raft_ui:RaftConnectedAppDetailCard',
  ],
  settle: const Duration(milliseconds: 600),
  build: _appsPage,
  interact: (tester, context) async {
    final key = context.props['verifyKey'] as String;
    final text = context.props['verifyText'] as String;
    final absent = context.props['absentText'] as String;
    await tester.pump(const Duration(milliseconds: 400));
    if (key.isNotEmpty) expect(find.byKey(ValueKey(key)), findsOneWidget);
    if (text.isNotEmpty) expect(find.text(text), findsWidgets);
    if (absent.isNotEmpty) expect(find.text(absent), findsNothing);
    if (context.props['appsShell'] == 'settings/applications') {
      expect(find.byKey(const ValueKey('apps-page')), findsOneWidget);
    }
    if (context.props['routeSet'] == 'server-popover') {
      final workspace = tester.widget<WorkspaceView>(
        find.byType(WorkspaceView),
      );
      expect(workspace.controller.location.route, RaftRoute.tasks);
      final popover = find.byKey(const ValueKey('mobile-server-tab-popover'));
      Finder dot(String key) =>
          find.descendant(of: popover, matching: find.byKey(ValueKey(key)));
      expect(dot('apps-attention-dot'), findsOneWidget);
      expect(dot('computers-attention-dot'), findsNothing);
      expect(dot('settings-attention-dot'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mobile-server-tab-pages')),
          matching: find.byWidgetPredicate(
            (widget) => widget is RaftInteractive && widget.selected == true,
          ),
        ),
        findsNothing,
      );
    }
  },
);

final _appsLogin = ParityCase(
  widgets: const ['raft_flutter:HumanLoginSheet'],
  settle: const Duration(milliseconds: 600),
  build: _appsPage,
  interact: (tester, context) async {
    final fixture = MsFixture(context);
    final server = fixture.server;
    final apps = context.fixtures['ext:apps'] as Map;
    final routes = (apps['routeSets'] as Map)[context.props['routeSet']] as Map;
    final client = Map<String, Object?>.from(
      routes['GET /oauth/clients/lookup'] as Map,
    );
    final status = client[r'$status'] as int?;
    final serverId = server['id'] as String;
    final api = FakeHumanLoginApi(
      clients: {if (status == null) serverId: client},
      lookupGate: client[r'$pending'] == true ? Completer<void>() : null,
      servers: [
        HumanLoginServer(
          id: serverId,
          slug: server['slug'] as String,
          name: server['name'] as String,
        ),
      ],
      signedInAs: fixture.user['email'] as String,
    )..promptTextConsentOn = context.props['flags'] == 'prompt-text';
    if (status != null) {
      api.lookupFailures[serverId] = RaftApiException(
        'Fixture error',
        status: status,
      );
    }
    unawaited(
      showHumanLoginSheet(
        tester.element(find.byType(WorkspaceView)),
        api: api,
        request: HumanLoginRequest(
          clientId: 'fixture-login',
          returnUrl: 'https://app.example.invalid/complete',
          scopes: const ['openid', 'profile'],
          state: '',
          serverHint: context.props['server'] as String? ?? '',
        ),
      ),
    );
    await tester.pump();
    if (client[r'$pending'] == true) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    if (context.props['loginDisclosure'] == true) {
      final disclosure = find.byKey(
        const ValueKey('human-login-identity-disclosure'),
      );
      await tester.ensureVisible(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(disclosure.hitTestable());
      await tester.pumpAndSettle();
    }
    final key = context.props['verifyKey'] as String;
    expect(find.byKey(ValueKey(key)), findsOneWidget);
    if (key != 'human-login-continue') {
      expect(find.byKey(const ValueKey('human-login-continue')), findsNothing);
    }
    expect(api.authorizations, isEmpty);
    expect(api.installs, isEmpty);
    final text = context.props['verifyText'] as String;
    if (text.isNotEmpty) expect(find.text(text), findsWidgets);
  },
);

final _externalBotAvatar = '/api/external-avatars/visual-deploy-bot.png';

final _appsExternal = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceView',
    'raft_flutter:ExternalIdentityDetailPanel',
  ],
  settle: const Duration(milliseconds: 600),
  build: (context) {
    final apps = context.fixtures['ext:apps'] as Map;
    final routes = (apps['routeSets'] as Map)['external-bot'] as Map;
    final image = routes['GET ${_externalBotAvatar.substring(4)}'] as Map;
    final bytes = File('../../tool/parity-ext/fixtures/${image[r'$file']}')
        .readAsBytesSync();
    final previous = RaftImageBytes.instance;
    RaftImageBytes.instance = RaftImageBytes(
      fetcher: (url) => Uri.parse(url).path == _externalBotAvatar
          ? Future.value(RaftFetchedImage(bytes))
          : previous.fetcher(url),
    );
    context.onDispose(() => RaftImageBytes.instance = previous);
    return _appsPage(context);
  },
  interact: (tester, context) async {
    await tester.pumpAndSettle();
    final header = find.byKey(const ValueKey('external-identity-header'));
    expect(header, findsOneWidget);
    expect(find.text('Posted as Slack bot · ture'), findsOneWidget);
    expect(find.text('From Slack · Deployer'), findsOneWidget);
    expect(
      tester
          .widget<RaftAvatarContent>(
            find.descendant(
              of: header,
              matching: find.byType(RaftAvatarContent),
            ),
          )
          .uploadedUrl,
      endsWith(_externalBotAvatar),
    );
    final profileImages = find.descendant(
      of: find.byKey(const ValueKey('profile-panel')),
      matching: find.byType(Image),
    );
    expect(profileImages, findsNWidgets(2));
    await tester.runAsync(() async {
      for (final image in profileImages.evaluate()) {
        await precacheImage(
          (image.widget as Image).image,
          image,
          onError: (error, _) => fail('External avatar did not decode: $error'),
        );
      }
    });
    await tester.pump();
  },
);

final Map<String, ParityCase> extAppsCases = {
  for (final platform in ['desktop', 'mobile'])
    for (final theme in ['raft', 'raft-dark'])
      for (final mode in [
        'person',
        'loading',
        'unavailable',
        'outage',
        'account',
        'account-identity-expanded',
        'install',
        'account-suspended',
        'account-server-issuer',
        'admin-needed',
      ])
        'components.apps.login.$mode.$platform.$theme': _appsLogin,
  for (final platform in ['desktop', 'mobile'])
    for (final theme in ['raft', 'raft-dark'])
      'components.apps.profile.external-bot.$platform.$theme': _appsExternal,
  for (final platform in ['desktop', 'mobile'])
    for (final theme in ['raft', 'raft-dark'])
      for (final state in [
        'page.installed',
        'page.loading',
        'page.empty',
        'page.error',
        'page.partial',
        'page.marketplace',
        'page.my-apps',
        'dialog.marketplace-detail',
        'dialog.installed-permissions',
        'dialog.uninstall',
        'dialog.review-permissions',
        'dialog.developer-edit',
        'dialog.add-app-menu',
        'dialog.reject-prompt-text',
        'dialog.link-previews',
        'dialog.link-previews-revoke',
        'page.link-previews-loading',
        'page.link-previews-empty',
        'page.link-previews-error',
        'page.guest-link-previews-loading',
        'page.guest-link-previews-empty',
        'page.guest-link-previews-error',
        'dialog.guest-link-previews',
        'bridge.healthy',
        'bridge.delivery-recovery',
        'bridge.provider-unavailable',
        'bridge.retry-requested',
        'bridge.replayed',
      ])
        'components.apps.$state.$platform.$theme': _appsSettings,
  for (final platform in ['desktop', 'mobile'])
    for (final theme in ['raft', 'raft-dark'])
      for (final state in [
        'installed',
        'recommended',
        'recommended-detail',
        'loading',
        'empty',
        'error',
        'partial',
        'marketplace',
        'marketplace-loading',
        'marketplace-empty',
        'marketplace-error',
        'marketplace-paging',
        'marketplace-more-error',
        'marketplace-more-loaded',
        'developer',
        'installed-permissions',
        'uninstall',
        'uninstall-pending',
        'uninstall-error',
        'uninstall-success',
        'uninstall-from-marketplace',
        'uninstall-from-marketplace-error',
        'review-permissions',
        'marketplace-detail',
        'developer-edit',
        'developer-app-identity',
        'developer-app-identity-installed',
        'share-created',
        'share-revoked',
        'publish-withdrawn',
        'reject-prompt-text',
        'stale-prompt-text',
        'install-step-up',
        'install-permissions-changed',
        'install-setup',
        'install-success',
        'bot-step-up',
        'bot-granted',
        'bot-remove',
        'bot-removed',
        'bot-link',
        'bot-link-unavailable',
        'link-previews',
        'link-previews-revoke',
        'add-app',
        'create-raft-app',
        'type-menu',
        'category-menu',
        if (platform == 'mobile') 'scope-menu',
        if (platform == 'desktop') 'rail-entry',
        if (platform == 'mobile') 'server-popover',
        if (platform == 'mobile') 'server-popover-surface',
        if (platform == 'mobile') 'server-popover-entry',
      ])
        'components.apps.route.$state.$platform.$theme': _appsSettings,
};
