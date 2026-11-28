import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/close_support.dart';

void main() {
  testWidgets('InviteHumanDialog.tsx shows active join link usage and expiry', (
    tester,
  ) async {
    final (workspace, api) = await mountWorkspace(
      tester,
      const Size(1280, 900),
      platform: TargetPlatform.linux,
    );
    api.routes['GET /servers/s1/join-links'] = (_) => [
      {
        'id': 'link',
        'token': 'fixture',
        'maxUses': 10,
        'useCount': 3,
        'expiresAt': '2099-11-27T12:00:00',
      },
    ];
    api.routes['DELETE /servers/s1/join-links/link'] = (_) => {};
    workspace.section = 'members';
    workspace.notifyListeners();
    await frames(tester);
    await tester.tap(
      find.byKey(const ValueKey('desktop-directory-invite-human')),
    );
    await frames(tester);
    final status = find.byKey(const ValueKey('invite-link-status'));
    expect(status, findsNothing);
    await tester.tap(find.byKey(const ValueKey('invite-tab-link')));
    await frames(tester);
    expect(status, findsOneWidget);
    expect(find.text('Used 3/10 · Expires 11/27/2099'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-link-revoke')));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('invite-link-revoke-confirm')));
    await frames(tester);
    expect(status, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
