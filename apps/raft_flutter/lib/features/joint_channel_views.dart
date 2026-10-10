import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
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
        c.json['isPrivate'],
        c.json['capabilities'],
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
              ['type', 'joined', 'isPrivate', 'archivedAt', 'capabilities'].any(
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
  Future<V?> scopedDialog<V>(Widget Function(BuildContext) builder) async {
    try {
      return await super.scopedDialog<V>((context) {
        _dialog = context;
        final child = builder(context);
        _sharedForm = child is RaftFormDialog;
        return child;
      });
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
    final values = await Future.wait([
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
    Map<String, dynamic>? created;
    await scopedDialog<bool>(
      (context) => _JointCreateDialog(
        agents: agents,
        users: users,
        onCreate: (payload) async {
          created = await mutate('/channels', payload, scope);
        },
      ),
    );
    if (!current(scope) || created == null || created!['id'] == null) return;
    await w.selectChannel(RaftChannel(created!));
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

class _InviteDraft {
  final slug = TextEditingController(), people = TextEditingController();
  void dispose() {
    slug.dispose();
    people.dispose();
  }
}

class _JointCreateDialog extends StatefulWidget {
  const _JointCreateDialog({
    required this.agents,
    required this.users,
    required this.onCreate,
  });
  final List<Map<String, dynamic>> agents, users;
  final Future<void> Function(Map<String, dynamic>) onCreate;
  @override
  State<_JointCreateDialog> createState() => _JointCreateDialogState();
}

class _JointCreateDialogState extends State<_JointCreateDialog> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController(), description = TextEditingController();
  final targets = [_InviteDraft()];
  final agents = <String>{}, users = <String>{};
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    for (final target in targets) {
      target.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onCreate({
        'name': name.text.trim(),
        if (description.text.trim().isNotEmpty)
          'description': description.text.trim(),
        'visibility': 'joint',
        'agentIds': agents.toList(),
        'userIds': users.toList(),
        'jointInvites': [
          for (final target in targets)
            {
              'targetServerSlug': target.slug.text.trim(),
              'invitedPeople': jointPeople(target.people.text),
            },
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          busy = false;
        });
      }
    }
  }

  Widget field(
    String key,
    String label,
    TextEditingController controller,
    String? Function(String) validator, {
    int lines = 1,
  }) => TextFormField(
    key: ValueKey(key),
    controller: controller,
    enabled: !busy,
    maxLines: lines,
    decoration: InputDecoration(labelText: raftText(context, label)),
    validator: (v) => validator(v ?? ''),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(raftText(context, 'Create joint channel')),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field('joint-name', 'Channel name', name, jointNameError),
              field(
                'joint-description',
                'Description',
                description,
                (v) => v.length > 500 ? 'Use at most 500 characters.' : null,
                lines: 3,
              ),
              for (var i = 0; i < targets.length; i++) ...[
                const SizedBox(height: 16),
                Text('${raftText(context, 'Workspace')} ${i + 1}'),
                field(
                  'joint-slug-$i',
                  'Workspace slug',
                  targets[i].slug,
                  jointTargetError,
                ),
                field(
                  'joint-people-$i',
                  'People to invite',
                  targets[i].people,
                  (v) => jointPeople(v).isEmpty
                      ? 'Invite at least one person.'
                      : jointPeople(v).length > 20
                      ? 'Invite at most 20 people per workspace.'
                      : null,
                  lines: 3,
                ),
                if (targets.length > 1)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => targets.removeAt(i).dispose()),
                    child: Text(raftText(context, 'Remove workspace')),
                  ),
              ],
              Text(
                raftText(
                  context,
                  'Use existing workspace slugs and names, @handles or email addresses. Invitations expire and must be accepted by an owner or admin.',
                ),
              ),
              if (targets.length < 29)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() => targets.add(_InviteDraft())),
                  child: Text(raftText(context, 'Add workspace')),
                ),
              Text(raftText(context, 'Local members (optional)')),
              for (final agent in widget.agents)
                CheckboxListTile(
                  value: agents.contains(agent['id']),
                  onChanged: busy
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            agents.add('${agent['id']}');
                          } else {
                            agents.remove(agent['id']);
                          }
                        }),
                  title: Text('${agent['displayName'] ?? agent['name']}'),
                  subtitle: Text(raftText(context, 'Agent')),
                ),
              for (final user in widget.users)
                CheckboxListTile(
                  value: users.contains(user['userId'] ?? user['id']),
                  onChanged: busy
                      ? null
                      : (checked) => setState(() {
                          final id = '${user['userId'] ?? user['id']}';
                          if (checked == true) {
                            users.add(id);
                          } else {
                            users.remove(id);
                          }
                        }),
                  title: Text(
                    '${user['displayName'] ?? user['name'] ?? user['userName']}',
                  ),
                ),
              if (error != null)
                Text(
                  error!,
                  key: const ValueKey('joint-create-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(raftText(context, 'Cancel')),
      ),
      FilledButton(
        key: const ValueKey('joint-create-submit'),
        onPressed: busy ? null : submit,
        child: Text(
          raftText(context, busy ? 'Creating…' : 'Create joint channel'),
        ),
      ),
    ],
  );
}
