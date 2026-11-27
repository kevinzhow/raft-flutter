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
    final (workspace, api) = await mountWorkspace(tester, const Size(1280, 800));
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
}
