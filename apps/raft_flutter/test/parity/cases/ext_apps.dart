import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../parity_harness.dart';
import 'ext_settings.dart';

final _appsSettings = ParityCase(
  widgets: const [
    'raft_flutter:WorkspaceSettings',
    'raft_flutter:IntegrationsView',
    'raft_ui:RaftConnectedAppDetailCard',
  ],
  settle: const Duration(milliseconds: 600),
  build: extSettingsPage,
  interact: (tester, context) async {
    final key = context.props['verifyKey'] as String;
    final text = context.props['verifyText'] as String;
    final absent = context.props['absentText'] as String;
    await tester.pump(const Duration(milliseconds: 400));
    if (key.isNotEmpty) expect(find.byKey(ValueKey(key)), findsOneWidget);
    if (text.isNotEmpty) expect(find.text(text), findsWidgets);
    if (absent.isNotEmpty) expect(find.text(absent), findsNothing);
  },
);

final Map<String, ParityCase> extAppsCases = {
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
        'dialog.review-permissions',
        'dialog.developer-edit',
        'dialog.reject-prompt-text',
        'dialog.link-previews',
        'dialog.link-previews-revoke',
        'page.link-previews-loading',
        'page.link-previews-empty',
        'page.link-previews-error',
        'bridge.healthy',
        'bridge.delivery-recovery',
        'bridge.provider-unavailable',
      ])
        'components.apps.$state.$platform.$theme': _appsSettings,
};
