import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'create_joint_channel_dialog.dart';
import 'management_support.dart';

String? jointNameError(String value) {
  final name = value.trim();
  if (name.isEmpty || name.length > 32) {
    return 'Use a name between 1 and 32 characters.';
  }
  if (name == 'all') return 'The name all is reserved.';
  if (!RegExp(r'^[\p{L}][\p{L}\p{N}_-]*$', unicode: true).hasMatch(name)) {
    return 'Start with a letter; use letters, numbers, underscores or hyphens.';
  }
  return null;
}

String? jointTargetError(String value) =>
    RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(value.trim())
    ? null
    : 'Enter the existing workspace slug in lowercase.';
List<String> jointPeople(String value) => value
    .split(RegExp(r'[\n,]+'))
    .map((v) => v.trim())
    .where((v) => v.isNotEmpty)
    .toSet()
    .toList();

abstract class _JointState<T extends StatefulWidget>
    extends ManagementState<T> {
  int _channelRevision = 0;
  StreamSubscription<RaftEvent>? _events;
  BuildContext? _dialog;
  bool _sharedForm = false;
  String? _deniedScope;
  Map<String, String> _access = {};
  Map<String, String> accessSnapshot() => {
    for (final c in w.channels)
      c.id: jsonEncode([
        c.type,
        c.joined,
        c.archived,
        c.json['channelCapabilities'],
        c.json['channelRole'],
      ]),
  };
  @override
  String get authority => '${super.authority}|$_channelRevision';

  /// Snapshots outlive the mount-local revision; [restoreSnapshot] instead
  /// rejects one accepted before any channel's access changed.
  @override
  String get snapshotIdentity => pageIdentity(w);
  Map<String, Object?> captureJoint();
  void restoreJoint(Map<String, Object?> fields);
  @override
  Map<String, Object?> captureSnapshot() => {
    ...captureJoint(),
    'access': Map<String, String>.of(_access),
  };
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    final accepted = fields['access'] as Map<String, String>;
    final now = accessSnapshot();
    if (accepted.entries.any((entry) => now[entry.key] != entry.value)) {
      return false;
    }
    restoreJoint(fields);
    return true;
  }

  bool get manager => w.can('federateChannels') && _deniedScope != authority;
  void _workspaceAccessChanged() {
    final next = accessSnapshot();
    final changed = _access.entries.any(
      (entry) => next[entry.key] != entry.value,
    );
    _access = next;
    if (changed) _invalidateAccess();
  }

  void _invalidateAccess() {
    _channelRevision++;
    final dialog = _dialog;
    if (dialog != null && dialog.mounted) {
      final route = ModalRoute.of(dialog);
      if (route != null && route.isActive) {
        Navigator.of(dialog).removeRoute(route);
      }
    }
    refreshAuthority();
  }

  void startJoint() {
    _access = accessSnapshot();
    startManagement();
    w.addListener(_workspaceAccessChanged);
    _events = w.client.events.listen((event) {
      if (!{
        'channel:removed',
        'channel:updated',
        'channel:members-updated',
        'channel:authority-updated',
      }.contains(event.name)) {
        return;
      }
      if (event.name == 'channel:updated') {
        final row = managementMap(managementMap(event.payload)['channel']);
        if (row.isNotEmpty) {
          final old = w.channels.where((c) => c.id == row['id']).firstOrNull;
          final policyChanged =
              old != null &&
              [
                'type',
                'joined',
                'archivedAt',
                'channelCapabilities',
                'channelRole',
              ].any(
                (key) =>
                    row.containsKey(key) &&
                    jsonEncode(row[key]) != jsonEncode(old.json[key]),
              );
          if (!policyChanged) {
            // Metadata publication also precedes successful create/accept receipts.
            // Refresh those facts without treating an access grant as revocation.
            reload();
            return;
          }
        }
      }
      _invalidateAccess();
    });
  }

  @override
  Future<V?> scopedDialog<V>(
    Widget Function(BuildContext) builder, {
    bool form = false,
  }) async {
    try {
      return await super.scopedDialog<V>(form: form, (context) {
        _dialog = context;
        final child = builder(context);
        _sharedForm = child is RaftFormDialog;
        return child;
      });
    } finally {
      _dialog = null;
    }
  }

  /// Product dialogs on the Web `Modal` layer track their route the same way.
  @override
  Future<V?> scopedRaftModal<V>(
    Widget Function(BuildContext) builder, {
    bool form = false,
    double dialogMaxWidth = 560,
  }) async {
    try {
      return await super.scopedRaftModal<V>(
        form: form,
        dialogMaxWidth: dialogMaxWidth,
        (context) {
          _dialog = context;
          return builder(context);
        },
      );
    } finally {
      _dialog = null;
    }
  }

  bool current(String scope) => mounted && scope == authority && manager;
  VoidCallback guarded(Future<void> Function() callback) {
    final scope = authority;
    return () {
      if (current(scope)) run(callback, refresh: false);
    };
  }

  Future<Map<String, dynamic>> mutate(
    String path,
    Map<String, dynamic>? data,
    String scope,
  ) async {
    if (!current(scope)) {
      throw StateError('Workspace access changed. Reopen this form.');
    }
    try {
      final result = managementMap(await w.client.post(path, data: data));
      if (!current(scope)) return {};
      return result;
    } catch (e) {
      if (scope == authority && invalidateDeniedMutation(e)) {
        _deniedScope = scope;
        final dialog = _dialog;
        if (!_sharedForm && dialog != null && dialog.mounted) {
          final route = ModalRoute.of(dialog);
          if (route != null && route.isActive) {
            Navigator.of(dialog).removeRoute(route);
          }
        }
      }
      rethrow;
    }
  }

  Future<void> refreshScope(String scope) async {
    if (!current(scope)) return;
    await w.refreshChannels();
    if (!mounted || w.server == null) return;
  }

  @override
  void dispose() {
    _events?.cancel();
    w.removeListener(_workspaceAccessChanged);
    super.dispose();
  }
}

class JointChannelsView extends StatefulWidget {
  const JointChannelsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<JointChannelsView> createState() => _JointChannelsState();
}

class _JointChannelsState extends _JointState<JointChannelsView> {
  @override
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> invites = [], channels = [];
  @override
  void initState() {
    super.initState();
    startJoint();
  }

  @override
  void clearData() {
    invites = [];
    channels = [];
  }

  @override
  String get snapshotKey => 'joint-channels';
  @override
  Map<String, Object?> captureJoint() => {
    'invites': invites,
    'channels': channels,
  };
  @override
  void restoreJoint(Map<String, Object?> fields) {
    invites = fields['invites'] as List<Map<String, dynamic>>;
    channels = fields['channels'] as List<Map<String, dynamic>>;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (!manager) {
      clearData();
      return;
    }
    final values = await Future.wait([
      w.client.get('/channels/joint-invites'),
      w.client.get('/channels', query: {'archived': 'include'}),
    ]);
    if (!accepts(generation, request)) return;
    invites = managementRows(managementMap(values[0])['invites']);
    channels = managementRows(values[1])
        .where((c) => c['type'] == 'joint')
        .toList();
  }

  Future<void> create() async {
    final scope = authority;
    // The workspace directory already holds both lists (same endpoints), so
    // the dialog opens at once; only a directory that never loaded is fetched.
    final directory = w.services.entityDirectory;
    final loaded =
        directory.state(WorkspaceEntityKind.agents).loaded &&
        directory.state(WorkspaceEntityKind.members).loaded;
    final values = loaded
        ? [
            directory.rows(WorkspaceEntityKind.agents),
            directory.rows(WorkspaceEntityKind.members),
          ]
        : await Future.wait([
            w.client.get('/agents'),
            w.client.get('/servers/${w.server!.id}/members'),
          ]);
    if (!current(scope)) return;
    final agents = managementRows(values[0])
        .where((a) => a['deletedAt'] == null)
        .toList();
    final users = managementRows(values[1])
        .where((u) => (u['userId'] ?? u['id']) != w.client.user?.id)
        .toList();
    final created = await scopedRaftModal<Map<String, dynamic>>(
      form: true,
      (context) => CreateJointChannelDialog(
        agents: agents,
        users: users,
        freePlan: (w.server?.string('plan') ?? 'free') == 'free',
        origin: w.client.origin,
        currentServerSlug: w.server?.string('slug'),
        onCreate: (payload) => mutate('/channels', payload, scope),
        onUnarchive: (id) => mutate('/channels/$id/unarchive', null, scope),
        onViewBilling: () => w.setSection('billing'),
      ),
    );
    if (!current(scope) || created == null || created['id'] == null) return;
    await w.selectChannel(RaftChannel(created));
    if (!mounted) return;
    await w.refreshChannels();
    await reload();
  }

  Future<void> accept(Map<String, dynamic> invite) async {
    final scope = authority;
    Map<String, dynamic>? channel;
    final confirmed = await confirm(
      'Accept joint channel invitation',
      '${invite['fromServerName']} invites this workspace to #${invite['channelName']}. Members from participating workspaces share this conversation.',
      () async {
        channel = await mutate(
          '/channels/joint-invites/${invite['id']}/accept',
          null,
          scope,
        );
      },
      submit: 'Accept invitation',
    );
    if (!confirmed || !current(scope) || channel?['id'] == null) return;
    await w.selectChannel(RaftChannel(channel!));
    if (!mounted) return;
    await w.refreshChannels();
    await reload();
  }

  Future<void> unarchive(Map<String, dynamic> channel) async {
    final scope = authority;
    final saved = await confirm(
      'Unarchive joint channel',
      'Restore #${channel['name']} for its participating workspaces instead of creating another channel with this name.',
      () async {
        if (!w.can('archiveChannels')) {
          throw StateError('Channel archive permission is required.');
        }
        await mutate('/channels/${channel['id']}/unarchive', null, scope);
      },
      submit: 'Unarchive',
    );
    if (saved && current(scope)) {
      await refreshScope(scope);
      await reload();
    }
  }

  @override
  Widget build(BuildContext context) => page(
    'Joint channels',
    [
      if (!manager)
        Text(
          raftText(
            context,
            'An owner or admin manages connections between workspaces.',
          ),
        ),
      if (manager) ...[
        Text(
          raftText(
            context,
            'A joint channel can connect up to 30 workspaces, including at most two free workspaces.',
          ),
        ),
        heading('Pending invitations'),
        if (!loading && invites.isEmpty)
          Text(raftText(context, 'No pending invitations.')),
        for (final invite in invites)
          RaftPanel(
            child: ListTile(
              title: Text('#${invite['channelName']}'),
              subtitle: Text(
                '${invite['fromServerName']} / ${invite['fromServerSlug']}\n${invite['channelDescription'] ?? ''}\n${raftText(context, 'Expires')}: ${invite['expiresAt'] ?? ''}',
              ),
              trailing: action(
                'Accept invitation',
                guarded(() => accept(invite)),
              ),
            ),
          ),
        heading('Connected channels'),
        for (final channel in channels)
          RaftPanel(
            child: ListTile(
              title: Text('#${channel['name']}'),
              subtitle: Text(
                '${channel['description'] ?? ''}${channel['archivedAt'] != null ? '\n${raftText(context, 'Archived')}' : ''}',
              ),
              trailing:
                  channel['archivedAt'] != null && w.can('archiveChannels')
                  ? action('Unarchive', guarded(() => unarchive(channel)))
                  : action(
                      'Manage',
                      guarded(() async {
                        await scopedDialog<void>(
                          (context) => Dialog(
                            child: SizedBox(
                              width: 640,
                              height: 600,
                              child: JointChannelManagementView(
                                controller: w,
                                channelId: '${channel['id']}',
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
            ),
          ),
      ],
    ],
    actions: [
      if (manager)
        action('Create joint channel', guarded(create), glyph: RaftGlyph.plus),
    ],
  );
}

class JointChannelManagementView extends StatefulWidget {
  const JointChannelManagementView({
    super.key,
    required this.controller,
    required this.channelId,
  });
  final WorkspaceController controller;
  final String channelId;
  @override
  State<JointChannelManagementView> createState() => _JointManagementState();
}

class _JointManagementState extends _JointState<JointChannelManagementView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> channel = {};
  String get base => '/channels/${widget.channelId}';
  @override
  void initState() {
    super.initState();
    startJoint();
  }

  @override
  void clearData() {
    channel = {};
  }

  @override
  String get snapshotKey => 'joint-channel:${widget.channelId}';
  @override
  Map<String, Object?> captureJoint() => {'channel': channel};
  @override
  void restoreJoint(Map<String, Object?> fields) {
    channel = fields['channel'] as Map<String, dynamic>;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    if (!manager) {
      clearData();
      return;
    }
    final value = managementMap(await w.client.get(base));
    if (!accepts(generation, request)) return;
    channel = value['type'] == 'joint' ? value : {};
  }

  Future<void> invite() async {
    final scope = authority;
    final saved = await form(
      'Invite workspace',
      [
        RaftFormField(
          'targetServerSlug',
          'Workspace slug',
          required: true,
          validator: jointTargetError,
        ),
        RaftFormField(
          'invitedPeople',
          'People to invite',
          required: true,
          multiline: true,
          help: 'Enter names, @handles or email addresses, separated by commas or new lines.',
          validator: (v) => jointPeople(v).isEmpty
              ? 'Invite at least one person.'
              : jointPeople(v).length > 20
              ? 'Invite at most 20 people per workspace.'
              : null,
        ),
      ],
      (values) async {
        await mutate('$base/joint-invites', {
          'targetServerSlug': values['targetServerSlug'],
          'invitedPeople': jointPeople(values['invitedPeople']!),
        }, scope);
      },
      submit: 'Send invitation',
    );
    if (saved && current(scope)) await reload();
  }

  Future<void> resend() async {
    final scope = authority;
    final saved = await confirm('Resend invitations', 'Send fresh invitations issued by this workspace and extend their expiry.', () async {
      await mutate('$base/joint-invite/resend', null, scope);
    }, submit: 'Resend invitations');
    if (saved && current(scope)) await reload();
  }

  Future<void> disconnect() async {
    final scope = authority;
    final done = await confirm(
      'Disconnect workspace',
      'Remove this workspace from the joint channel. Other participating workspaces retain their channel.',
      () async {
        await mutate('$base/disconnect', null, scope);
      },
      submit: 'Disconnect workspace',
      destructive: true,
    );
    if (!done || !current(scope)) return;
    clearData();
    await refreshScope(scope);
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final pending = managementRows(channel['jointPendingInvites']);
    final issuedHere = pending.any((i) => i['fromServerId'] == w.server?.id);
    return page(
      channel.isEmpty ? 'Joint channel' : '#${channel['name']}',
      [
        if (!manager)
          Text(
            raftText(
              context,
              'An owner or admin manages connections between workspaces.',
            ),
          ),
        if (channel.isNotEmpty) ...[
          Text('${channel['description'] ?? ''}'),
          if (channel['jointBillingLocked'] == true)
            Text(
              raftText(
                context,
                'This joint channel is read-only because its workspace plan limits were exceeded.',
              ),
            ),
          if (channel['jointOverLimitGraceEndsAt'] != null)
            Text(
              '${raftText(context, 'Plan limit grace period ends')}: ${channel['jointOverLimitGraceEndsAt']}',
            ),
          heading('Participating workspaces'),
          for (final server in managementRows(channel['jointServers']))
            ListTile(
              title: Text('${server['serverName']}'),
              subtitle: Text(
                '${server['serverSlug']} · ${server['status']} · ${server['role'] ?? ''} · ${server['plan'] ?? ''}',
              ),
            ),
          heading('Pending invitations'),
          for (final invite in pending)
            ListTile(
              title: Text('${invite['serverName']}'),
              subtitle: Text(
                '${invite['serverSlug']} · ${raftText(context, 'Pending')}',
              ),
            ),
          if (issuedHere) action('Resend invitations', guarded(resend)),
          action(
            'Disconnect workspace',
            guarded(disconnect),
            glyph: RaftGlyph.unplug,
          ),
        ],
      ],
      actions: [
        if (manager && channel.isNotEmpty)
          action('Invite workspace', guarded(invite), glyph: RaftGlyph.mail),
      ],
    );
  }
}
