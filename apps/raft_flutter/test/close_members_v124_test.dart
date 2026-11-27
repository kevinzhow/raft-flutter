import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/workspace_menu_invite.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'close_dialogs_test.dart' show anyX;
import 'member_profile_self_edit_test.dart' show openRoleConfirmation;
import 'support/close_registry_members_v124.dart';
import 'support/close_runner.dart';
import 'support/close_support.dart';
import 'support/close_surface.dart';

void main() {
  final harnesses = <String, OpenSurface>{
    'members-directory-page': (tester, size) async {
      final (workspace, _) = await mountWorkspace(
        tester,
        size,
        platform: closePlatform(size),
      );
      workspace.section = 'members';
      workspace.notifyListeners();
      await frames(tester);
      final back = find.byKey(const ValueKey('members-mobile-back'));
      return SurfaceProbe(isOpen: () => back.evaluate().isNotEmpty, back: back);
    },
    'member-promote-guest': (tester, size) => _open(
      tester,
      size,
      action: 'human-promote-guest',
      dialog: 'human-promote-guest-dialog',
    ),
    'member-removal-impact': (tester, size) =>
        _open(tester, size, action: 'member-remove', dialog: 'agent-dialog'),
    'member-owner-grant': (tester, size) =>
        openRoleConfirmation(tester, size, self: false),
    'member-self-demote': (tester, size) =>
        openRoleConfirmation(tester, size, self: true),
    'invite-link-update': (tester, size) => _inviteLink(tester, size, 'update'),
    'invite-link-revoke': (tester, size) => _inviteLink(tester, size, 'revoke'),
    'members-usage-filter': _usageFilter,
    'members-create-agent-options': _creationOptions,
  };
  registerCloseTests(membersV124Surfaces, harnesses);
}

Future<SurfaceProbe> _creationOptions(WidgetTester tester, Size size) async {
  await mountWorkspace(
    tester,
    size,
    platform: closePlatform(size),
    section: 'members',
  );
  const key = ValueKey('members-add-agent-options');
  await tester.tap(find.byKey(key));
  await frames(tester);
  final option = find.text('Connect an external agent').hitTestable();
  return SurfaceProbe(
    isOpen: () => option.evaluate().isNotEmpty,
    scrim: Offset(size.width - 10, size.height - 10),
  );
}

Future<SurfaceProbe> _inviteLink(
  WidgetTester tester,
  Size size,
  String action,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final (workspace, api) = await mountWorkspace(
    tester,
    size,
    platform: closePlatform(size),
  );
  api.routes['GET /servers/s1/join-links'] = (_) => [
    {'id': 'fixture', 'token': 'fixture-link', 'maxUses': 5},
  ];
  final context = tester.element(find.byType(WorkspaceView));
  unawaited(showWorkspaceMenuInvite(context, workspace));
  await frames(tester);
  await tester.tap(find.byKey(const ValueKey('invite-tab-link')));
  await frames(tester);
  await tester.tap(
    find.byKey(
      ValueKey('invite-link-${action == 'update' ? 'apply' : action}'),
    ),
  );
  await frames(tester);
  final dialog = find.byKey(ValueKey('invite-link-$action-dialog'));
  return SurfaceProbe(
    isOpen: () => dialog.evaluate().isNotEmpty,
    x: find.descendant(of: dialog, matching: anyX),
    scrim: const Offset(6, 6),
  );
}

Future<SurfaceProbe> _usageFilter(WidgetTester tester, Size size) async {
  final (workspace, api) = await mountWorkspace(
    tester,
    size,
    platform: closePlatform(size),
  );
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'agent_usage_v0', 'enabled': true},
    ],
  };
  api.routes['GET /servers/s1/agent-usage'] = (request) => {
    'from': request.queryParameters['from'],
    'to': request.queryParameters['to'],
    'as_of': '${request.queryParameters['to']}T12:00:00Z',
    'agents': [
      {'agent_id': 'a1', 'usage_reported': true},
    ],
    'rows': [],
  };
  workspace.section = 'members';
  workspace.notifyListeners();
  await frames(tester);
  final agentTab = find.byKey(const ValueKey('members-tab-agent'));
  if (agentTab.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('members-scope-select')));
    await frames(tester);
    await tester.tap(find.text('Agents').last);
  } else {
    await tester.tap(agentTab);
  }
  await frames(tester);
  final usage = find.byKey(const ValueKey('members-view-usage'));
  if (usage.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('members-toolbar-more')));
    await frames(tester);
    await tester.tap(find.text('Usage').hitTestable());
  } else {
    await tester.tap(usage);
  }
  await frames(tester);
  await tester.tap(find.byKey(const ValueKey('members-usage-filter')));
  await frames(tester);
  final menu = find.byKey(const ValueKey('members-usage-filter-menu'));
  return SurfaceProbe(
    isOpen: () => menu.evaluate().isNotEmpty,
    scrim: Offset(size.width - 10, size.height - 10),
  );
}

Future<SurfaceProbe> _open(
  WidgetTester tester,
  Size size, {
  required String action,
  required String dialog,
}) async {
  final (workspace, api) = await mountWorkspace(
    tester,
    size,
    platform: closePlatform(size),
  );
  const bob = {
    'userId': 'bob',
    'name': 'bob',
    'displayName': 'Bob',
    'role': 'guest',
    'membershipStatus': 'active',
  };
  api.routes['GET /servers/s1/members'] = (_) => [bob];
  api.routes['GET /servers/s1/members/bob/profile'] = (_) => bob;
  api.routes['GET /servers/s1/members/bob/removal-impact'] = (_) => {
    'computers': 0,
    'computerNames': [],
    'othersAgents': 0,
  };
  workspace.client.singleFlightWindow = Duration.zero;
  await tester.runAsync(
    () => workspace.entityDirectory.refresh(
      WorkspaceEntityKind.members,
      force: true,
    ),
  );
  workspace.section = 'members';
  workspace.notifyListeners();
  await frames(tester);
  await tester.tap(find.byKey(const ValueKey('desktop-directory-human-bob')));
  await frames(tester);
  final button = find.byKey(ValueKey(action));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await frames(tester);
  final panel = find.byKey(ValueKey(dialog));
  return SurfaceProbe(
    isOpen: () => panel.evaluate().isNotEmpty,
    x: anyX,
    scrim: const Offset(6, 6),
  );
}
