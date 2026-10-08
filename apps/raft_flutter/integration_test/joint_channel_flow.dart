import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/joint_channel_views.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  final errors = tester
      .widgetList<Text>(find.byKey(const ValueKey('joint-create-error')))
      .map((text) => text.data ?? '')
      .where((value) => value.isNotEmpty)
      .join(' ');
  throw TestFailure(
    errors.isEmpty
        ? 'Timed out waiting for native joint channel UI.'
        : 'Joint channel form rejected: $errors',
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder.last);
  await tester.pumpAndSettle();
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _text(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(finder, value);
}

Future<void> _closeManagement(WidgetTester tester) async {
  final finder = find.byType(JointChannelManagementView);
  if (finder.evaluate().isEmpty) return;
  final context = tester.element(finder.first);
  final route = ModalRoute.of(context);
  if (route != null && route.isActive) Navigator.of(context).removeRoute(route);
  await tester.pumpAndSettle();
}

/// Run only on the isolated mounted-source fixture with its mailer disabled.
/// Invites address the fixture human's handle; no external users are invited.
/// Parent owns serialization with the aggregate Linux/Android native runner.
Future<void> verifyJointChannelFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required Future<void> Function(String) section,
  required Future<void> Function(String) capture,
  required bool fixtureEmailDisabled,
}) async {
  if (!fixtureEmailDisabled) {
    throw StateError(
      'Joint native verification requires the fixture mailer to be disabled.',
    );
  }
  final original = w.server!;
  final marker = DateTime.now().microsecondsSinceEpoch;
  final hostSlug = 'native-joint-host-$marker';
  final targetSlug = 'native-joint-peer-$marker';
  final name = 'joint_$marker';
  final handle = w.client.user?.string('name') ?? '';
  if (handle.isEmpty) throw StateError('The fixture human must have a handle.');
  final owned = <String>[];
  String? hostId, targetId, hostChannelId;
  Future<void> switchTo(String id) async {
    await w.recoverMembership();
    await w.selectServer(w.servers.singleWhere((s) => s.id == id));
    await tester.pumpAndSettle();
    await section('joint-channels');
    await _until(
      tester,
      () => find.byType(JointChannelsView).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
  }

  try {
    for (final slug in [hostSlug, targetSlug]) {
      final row = await w.client.post(
        '/servers',
        data: {
          'name': slug == hostSlug ? 'Native joint host' : 'Native joint peer',
          'slug': slug,
        },
      );
      owned.add('${row['id']}');
    }
    hostId = owned[0];
    targetId = owned[1];
    await switchTo(hostId);
    await _tap(tester, find.text('Create joint channel'));
    await _text(tester, 'joint-name', name);
    await _text(
      tester,
      'joint-description',
      'Native cross-workspace collaboration',
    );
    await _text(tester, 'joint-slug-0', targetSlug);
    await _text(tester, 'joint-people-0', '@$handle');
    await _tap(tester, find.byKey(const ValueKey('joint-create-submit')));
    await _until(
      tester,
      () =>
          find.byKey(const ValueKey('joint-create-submit')).evaluate().isEmpty,
    );
    await section('joint-channels');
    await _until(tester, () => find.text('#$name').evaluate().isNotEmpty);
    final hostRows = await w.client.channels();
    final hostChannel = hostRows.singleWhere(
      (c) => c.name == name && c.type == 'joint',
    );
    hostChannelId = hostChannel.id;
    final initial = await w.client.get('/channels/$hostChannelId');
    expect((initial['jointPendingInvites'] as List).length, 1);
    await _tap(tester, find.text('Manage'));
    await _tap(tester, find.text('Resend invitations'));
    await _tap(tester, find.text('Resend invitations'));
    await _until(
      tester,
      () => find.byType(JointChannelManagementView).evaluate().isNotEmpty,
    );
    await _closeManagement(tester);
    await capture('joint-host-pending-invitation');
    await switchTo(targetId);
    final pending = await w.client.get('/channels/joint-invites');
    expect(
      (pending['invites'] as List)
          .where((dynamic i) => i['channelName'] == name)
          .length,
      1,
    );
    await _tap(tester, find.text('Accept invitation'));
    await _tap(tester, find.text('Accept invitation'));
    await _until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    await section('joint-channels');
    await _until(tester, () => find.text('#$name').evaluate().isNotEmpty);
    await _until(
      tester,
      () =>
          find.text('Manage').evaluate().isNotEmpty &&
          find.byType(RaftFormDialog).evaluate().isEmpty &&
          find.text('Accept invitation').evaluate().isEmpty,
    );
    final targetRows = await w.client.channels();
    final projection = targetRows.singleWhere(
      (c) => c.name == name && c.type == 'joint',
    );
    expect(projection.id, isNot(hostChannelId));
    final joined = await w.client.get('/channels/${projection.id}');
    expect(
      (joined['jointServers'] as List)
          .where((dynamic s) => s['status'] == 'active')
          .length,
      2,
    );
    await _tap(tester, find.text('Manage'));
    await _until(
      tester,
      () => find.text('Native joint host').evaluate().isNotEmpty,
    );
    await capture('joint-participating-workspaces');
    await _tap(tester, find.text('Disconnect workspace'));
    await _tap(tester, find.text('Disconnect workspace'));
    await _until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    await _closeManagement(tester);
    final disconnected = await w.client.channels();
    expect(disconnected.where((c) => c.id == projection.id), isEmpty);
    await capture('joint-peer-disconnected');
    await switchTo(hostId);
    final remaining = await w.client.get('/channels/$hostChannelId');
    expect(
      (remaining['jointServers'] as List)
          .where((dynamic s) => s['status'] == 'active')
          .length,
      1,
    );
    await _tap(tester, find.text('Manage'));
    await _tap(tester, find.text('Invite workspace'));
    await _text(tester, 'field-targetServerSlug', targetSlug);
    await _text(tester, 'field-invitedPeople', '@$handle');
    await _tap(tester, find.text('Send invitation'));
    await _until(tester, () => find.byType(RaftFormDialog).evaluate().isEmpty);
    await _closeManagement(tester);
    final reinvited = await w.client.get('/channels/$hostChannelId');
    expect((reinvited['jointPendingInvites'] as List).length, 1);
  } finally {
    await _closeManagement(tester);
    for (final id in owned.reversed) {
      w.client.selectServer(id);
      await w.client.exitServer(id, delete: true);
      w.revokeServer(id);
    }
    await w.recoverMembership();
    final prior = w.servers.where((s) => s.id == original.id).firstOrNull;
    if (prior != null) await w.selectServer(prior);
    await tester.pumpAndSettle();
  }
}
