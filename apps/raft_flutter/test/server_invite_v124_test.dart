import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/close_support.dart';

void main() {
  testWidgets('server invites offer Member access even with Guest enabled', (
    tester,
  ) async {
    final (workspace, api) = await mountWorkspace(
      tester,
      const Size(1280, 800),
    );
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'server_guest_v0', 'enabled': true},
      ],
    };
    api.routes['GET /servers/s1/join-links'] = (_) => [
      {'id': 'link', 'token': 'example'},
    ];
    final invites = <Object?>[];
    api.routes['POST /servers/s1/invites'] = (request) {
      invites.add(request.data);
      return {};
    };
    unawaited(
      showWorkspaceMenuInvite(
        tester.element(find.byType(Scaffold).first),
        workspace,
      ),
    );
    await frames(tester, 20);
    expect(find.byKey(const ValueKey('invite-dialog')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invite-dialog')),
        matching: find.byType(RaftSelectField<String>),
      ),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('invite-email-0')),
      ' person@example.com ',
    );
    await tester.tap(find.text('Send Invites'));
    await frames(tester, 20);
    expect(invites, [
      {'email': 'person@example.com', 'role': 'member'},
    ]);
    expect(find.byKey(const ValueKey('invite-dialog')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('link rotation confirms and preserves untouched limits', (
    tester,
  ) async {
    final (workspace, api) = await mountWorkspace(
      tester,
      const Size(1280, 800),
    );
    const expiry = '2099-11-27T12:00:00Z';
    var link = <String, Object?>{
      'id': 'old',
      'token': 'fixture-old',
      'maxUses': 25,
      'expiresAt': expiry,
    };
    api.routes['GET /servers/s1/join-links'] = (_) => [link];
    api.routes['DELETE /servers/s1/join-links/old'] = (_) => {};
    api.routes['POST /servers/s1/join-links'] = (request) {
      expect(request.data, {'maxUses': 25, 'expiresAt': expiry});
      link = {...link, 'id': 'new', 'token': 'fixture-new'};
      return {'link': link};
    };
    api.routes['DELETE /servers/s1/join-links/new'] = (_) {
      link = {};
      return {};
    };
    unawaited(
      showWorkspaceMenuInvite(
        tester.element(find.byType(Scaffold).first),
        workspace,
      ),
    );
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('invite-tab-link')));
    await frames(tester);
    await tester.tap(find.byKey(const ValueKey('invite-link-apply')));
    await frames(tester);
    expect(api.calls.where((call) => call.method == 'DELETE'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('invite-link-update-confirm')));
    await frames(tester);
    expect(
      find.byKey(const ValueKey('invite-link-update-dialog')),
      findsNothing,
    );
    expect(find.textContaining('fixture-new'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invite-link-revoke')));
    await frames(tester);
    expect(link['id'], 'new');
    await tester.tap(find.byKey(const ValueKey('invite-link-revoke-confirm')));
    await frames(tester);
    expect(link, isEmpty);
    expect(find.textContaining('fixture-new'), findsNothing);
    expect(find.byKey(const ValueKey('invite-link-revoke')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
