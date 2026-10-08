import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';

class WorkspaceActions {
  static Future<void> create(
    BuildContext context,
    WorkspaceController w,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Create workspace',
        submitLabel: 'Create',
        fields: [
          const RaftFormField('name', 'Workspace name', required: true),
          RaftFormField(
            'slug',
            'Workspace address',
            required: true,
            help: 'Lowercase letters, numbers and hyphens.',
            validator: (v) => RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v)
                ? null
                : 'Use lowercase letters, numbers and hyphens.',
          ),
        ],
        onSubmit: (values) async {
          final created = await w.client.post('/servers', data: values);
          await w.recoverMembership();
          final next = w.servers
              .where((s) => s.id == created['id'])
              .firstOrNull;
          if (next != null) await w.selectServer(next);
        },
      ),
    );
  }

  static Future<void> join(BuildContext context, WorkspaceController w) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => RaftFormDialog(
        title: 'Join workspace',
        submitLabel: 'Review invitation',
        fields: [
          RaftFormField(
            'token',
            'Invitation link or code',
            required: true,
            obscure: true,
          ),
        ],
        onSubmit: (values) async {
          final input = values['token']!, uri = Uri.tryParse(values['token']!);
          final token = uri != null && uri.hasScheme
              ? (uri.queryParameters['invite'] ??
                    uri.queryParameters['token'] ??
                    (uri.pathSegments.length >= 2 &&
                            uri.pathSegments.first == 'join'
                        ? uri.pathSegments.last
                        : ''))
              : input;
          if (token.isEmpty) {
            throw const RaftApiException(
              'Enter a valid invitation link or code.',
            );
          }
          final info = await w.client.get(
            '/auth/invite-info',
            query: {'token': token},
          );
          if (!dialogContext.mounted) return;
          final agreement = info['agreement'];
          String? joinedId;
          final accepted = await showDialog<bool>(
            context: dialogContext,
            builder: (_) => RaftFormDialog(
              title: raftFormat(context, 'Join {workspace}?', {
                'workspace': info['serverName'],
              }),
              description: agreement is Map
                  ? '${agreement['title']} · Version ${agreement['version']}\n\n${agreement['bodyMarkdown']}'
                  : 'You have been invited to this workspace${info['inviterName'] == null ? '' : ' by ${info['inviterName']}'}.',
              fields: [],
              submitLabel: agreement == null
                  ? 'Join workspace'
                  : 'Agree and join',
              onSubmit: (_) async {
                final result = await w.client.post(
                  '/auth/accept-invite',
                  data: {
                    'token': token,
                    if (agreement is Map) 'agreementId': agreement['id'],
                  },
                );
                joinedId = result['serverId'];
              },
            ),
          );
          if (accepted != true) {
            throw const RaftApiException(
              'The invitation has not been accepted.',
            );
          }
          await w.recoverMembership();
          final next = w.servers.where((s) => s.id == joinedId).firstOrNull;
          if (next != null) await w.selectServer(next);
        },
      ),
    );
  }

  static Future<void> leave(
    BuildContext context,
    WorkspaceController w, {
    bool delete = false,
  }) async {
    final server = w.server;
    if (server == null) return;
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: delete ? 'Delete workspace?' : 'Leave workspace?',
        description: delete
            ? raftFormat(
                context,
                'Delete {workspace}, its channels and messages. This cannot be undone.',
                {'workspace': server.name},
              )
            : raftFormat(
                context,
                'Leave {workspace}. A new invitation is required to return.',
                {'workspace': server.name},
              ),
        fields: [
          RaftFormField(
            'confirm',
            'Type workspace name',
            required: true,
            validator: (v) => v == server.name
                ? null
                : raftFormat(context, 'The name must match {name}.', {
                    'name': server.name,
                  }),
          ),
        ],
        submitLabel: delete ? 'Delete' : 'Leave',
        destructive: delete,
        onSubmit: (_) async {
          await w.client.exitServer(server.id, delete: delete);
          w.revokeServer(server.id);
          await w.recoverMembership();
        },
      ),
    );
  }
}

class ServerSettingsView extends StatefulWidget {
  const ServerSettingsView({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<ServerSettingsView> createState() => _ServerSettingsViewState();
}

class _ServerSettingsViewState extends State<ServerSettingsView> {
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> profile = {}, prefs = {};
  List<Map<String, dynamic>> invites = [], links = [];
  bool loading = true, busy = false;
  String? error;
  StreamSubscription<RaftEvent>? events;
  Timer? refresh;
  @override
  void initState() {
    super.initState();
    load();
    events = w.client.events.listen((event) {
      if (event.name == 'notification_prefs:updated' ||
          event.name == 'server:member-added') {
        refresh?.cancel();
        refresh = Timer(const Duration(milliseconds: 150), () {
          if (mounted) load();
        });
      }
    });
  }

  @override
  void dispose() {
    refresh?.cancel();
    events?.cancel();
    super.dispose();
  }

  int request = 0;
  Future<void> load() async {
    final ticket = ++request;
    final id = w.server?.id, generation = w.client.generation;
    if (id == null) return;
    try {
      final values = await Future.wait([
        w.query('/servers/$id'),
        w.query('/servers/$id/notification-settings'),
        if (w.can('inviteMembers')) w.query('/servers/$id/invites'),
        if (w.can('inviteMembers')) w.query('/servers/$id/join-links'),
      ]);
      if (!mounted || ticket != request || generation != w.client.generation) {
        return;
      }
      setState(() {
        profile = Map<String, dynamic>.from(values[0]);
        prefs = Map<String, dynamic>.from(values[1]);
        if (values.length > 2) {
          invites = [
            for (final row in values[2]) Map<String, dynamic>.from(row),
          ];
          links = [for (final row in values[3]) Map<String, dynamic>.from(row)];
        }
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit() async {
    final id = w.server!.id;
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Edit workspace',
        fields: [
          RaftFormField(
            'name',
            'Workspace name',
            initial: '${profile['name'] ?? w.server!.name}',
            required: true,
          ),
        ],
        onSubmit: (values) async {
          await w.command('PATCH', '/servers/$id', data: values);
          await w.recoverMembership();
        },
      ),
    );
    if (mounted) await load();
  }

  Future<void> invite() async {
    final id = w.server!.id;
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Invite member',
        submitLabel: 'Send invitation',
        fields: [
          RaftFormField('email', 'Email', required: true),
          RaftFormField(
            'role',
            'Role',
            initial: 'member',
            choices: {'member': 'Member', 'guest': 'Guest'},
          ),
        ],
        onSubmit: (values) async {
          await w.command('POST', '/servers/$id/invites', data: values);
        },
      ),
    );
    if (mounted) await load();
  }

  Future<void> createLink() async {
    final id = w.server!.id;
    String? token;
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: 'Create invitation link',
        submitLabel: 'Create link',
        fields: [
          RaftFormField(
            'maxUses',
            'Maximum uses',
            help: 'Leave empty for unlimited uses.',
            validator: (v) =>
                v.isEmpty || int.tryParse(v) != null && int.parse(v) > 0
                ? null
                : 'Enter a positive integer.',
          ),
          RaftFormField(
            'expiresAt',
            'Expires at (ISO date)',
            help: 'Leave empty for no expiry.',
            validator: (v) => v.isEmpty || DateTime.tryParse(v) != null
                ? null
                : 'Enter an ISO date.',
          ),
        ],
        onSubmit: (values) async {
          final result = await w.command(
            'POST',
            '/servers/$id/join-links',
            data: {
              if (values['maxUses']!.isNotEmpty)
                'maxUses': int.parse(values['maxUses']!),
              if (values['expiresAt']!.isNotEmpty)
                'expiresAt': DateTime.parse(values['expiresAt']!)
                    .toUtc()
                    .toIso8601String(),
            },
          );
          token = result['token'];
        },
      ),
    );
    if (!mounted) return;
    if (token != null) {
      final link = '${w.client.origin}/join/$token';
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(raftText(context, 'Invitation link')),
          content: SelectableText(link),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
              },
              child: Text(raftText(context, 'Copy link')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(raftText(context, 'Done')),
            ),
          ],
        ),
      );
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => loading
      ? Center(child: CircularProgressIndicator())
      : ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Text(
              '${profile['name'] ?? w.server?.name ?? 'Workspace'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Address: ${profile['slug'] ?? w.server?.string('slug') ?? ''}',
            ),
            if (w.can('editServerSettings'))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: busy ? null : edit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(raftText(context, 'Edit workspace')),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              raftText(context, 'Notifications'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: '${prefs['serverPushMode'] ?? 'all'}',
              decoration: InputDecoration(
                labelText: raftText(context, 'Workspace push notifications'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(raftText(context, 'All activity')),
                ),
                DropdownMenuItem(
                  value: 'mentions',
                  child: Text(raftText(context, 'Mentions only')),
                ),
                DropdownMenuItem(
                  value: 'none',
                  child: Text(raftText(context, 'None')),
                ),
              ],
              onChanged: busy
                  ? null
                  : (mode) => run(() async {
                      await w.command(
                        'PATCH',
                        '/servers/${w.server!.id}/notification-settings',
                        data: {'serverPushMode': mode},
                      );
                    }),
            ),
            if (w.can('inviteMembers')) ...[
              const SizedBox(height: 32),
              Text(
                raftText(context, 'Invitations'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  RaftButton(
                    label: 'Invite member',
                    onPressed: busy ? null : invite,
                  ),
                  RaftButton(
                    label: 'Create invitation link',
                    secondary: true,
                    onPressed: busy ? null : createLink,
                  ),
                ],
              ),
              for (final invite in invites)
                ListTile(
                  title: Text('${invite['email']}'),
                  subtitle: Text(
                    '${invite['role'] ?? 'member'} · Expires ${invite['expiresAt'] ?? '—'}',
                  ),
                  trailing: IconButton(
                    tooltip: raftText(context, 'Revoke invitation'),
                    icon: const Icon(Icons.close),
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await w.command(
                              'DELETE',
                              '/servers/${w.server!.id}/invites/${invite['id']}',
                            );
                          }),
                  ),
                ),
              for (final link in links)
                ListTile(
                  title: Text(
                    raftFormat(
                      context,
                      'Invitation link · {used}/{maximum} uses',
                      {
                        'used': link['useCount'] ?? 0,
                        'maximum':
                            link['maxUses'] ?? raftText(context, 'Unlimited'),
                      },
                    ),
                  ),
                  subtitle: Text(
                    raftFormat(context, 'Expires {date}', {
                      'date': link['expiresAt'] ?? raftText(context, 'Never'),
                    }),
                  ),
                  trailing: IconButton(
                    tooltip: raftText(context, 'Revoke invitation link'),
                    icon: const Icon(Icons.link_off),
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await w.command(
                              'DELETE',
                              '/servers/${w.server!.id}/join-links/${link['id']}',
                            );
                          }),
                  ),
                ),
            ],
            const SizedBox(height: 32),
            Text(
              raftText(context, 'Membership'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => WorkspaceActions.leave(context, w),
                icon: const Icon(Icons.logout),
                label: Text(raftText(context, 'Leave workspace')),
              ),
            ),
            if (w.server?.string('role') == 'owner')
              Align(
                alignment: Alignment.centerLeft,
                child: RaftButton(
                  label: 'Delete workspace',
                  destructive: true,
                  onPressed: () =>
                      WorkspaceActions.leave(context, w, delete: true),
                ),
              ),
          ],
        );
}

class MembersView extends StatefulWidget {
  const MembersView({
    super.key,
    required this.controller,
    this.mobileRoot = false,
  });
  final WorkspaceController controller;
  final bool mobileRoot;
  @override
  State<MembersView> createState() => _MembersViewState();
}

class _MembersViewState extends State<MembersView> {
  WorkspaceController get w => widget.controller;
  List<Map<String, dynamic>> members = [];
  bool loading = true;
  String? error;
  StreamSubscription<RaftEvent>? events;
  @override
  void initState() {
    super.initState();
    load();
    events = w.client.events.listen((event) {
      if (event.name.startsWith('server:member')) load();
    });
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final generation = w.client.generation;
    try {
      final result = await w.query('/servers/${w.server!.id}/members');
      if (mounted && generation == w.client.generation) {
        setState(
          () =>
              members = [for (final p in result) Map<String, dynamic>.from(p)],
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> profile(Map<String, dynamic> member) async {
    try {
      final value = await w.query(
        '/servers/${w.server!.id}/members/${member['userId'] ?? member['id']}/profile',
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${value['displayName'] ?? value['name']}'),
          content: SelectableText(
            '${value['description'] ?? ''}\n\n${value['email'] ?? ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(raftText(context, 'Close')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> change(Map<String, dynamic> member, String role) async {
    final id = member['userId'] ?? member['id'],
        server = w.server!.id,
        name = '${member['displayName'] ?? member['name']}';
    await showDialog(
      context: context,
      builder: (_) => RaftFormDialog(
        title: role == 'remove'
            ? raftFormat(context, 'Remove {name}?', {'name': name})
            : raftText(context, 'Change role?'),
        description: role == 'remove'
            ? raftFormat(
                context,
                'Remove this member from {workspace}. They will lose workspace access.',
                {'workspace': w.server!.name},
              )
            : raftFormat(context, 'Make {name} a {role} in {workspace}.', {
                'name': name,
                'role': raftText(
                  context,
                  '${role[0].toUpperCase()}${role.substring(1)}',
                ),
                'workspace': w.server!.name,
              }),
        fields: [],
        submitLabel: role == 'remove' ? 'Remove' : 'Confirm',
        destructive: role == 'remove',
        onSubmit: (_) async {
          await w.command(
            role == 'remove' ? 'DELETE' : 'PATCH',
            '/servers/$server/members/$id',
            data: role == 'remove' ? null : {'role': role},
          );
        },
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.mobileRoot)
        RaftMobileRootHeader(
          title: 'Members',
          actions: [
            RaftIconButton(
              tooltip: 'Refresh members',
              onPressed: load,
              glyph: RaftGlyph.refreshCw,
            ),
          ],
        ),
      Expanded(
        child: loading
            ? Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (!widget.mobileRoot)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            raftText(context, 'Members'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: raftText(context, 'Refresh members'),
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  if (error != null)
                    Semantics(liveRegion: true, child: Text(error!)),
                  for (final member in members)
                    ListTile(
                      leading: RaftAvatar(
                        name: '${member['displayName'] ?? member['name']}',
                      ),
                      title: Text('${member['displayName'] ?? member['name']}'),
                      subtitle: Text(
                        '${member['role']} · ${member['email'] ?? ''}',
                      ),
                      onTap: () => profile(member),
                      trailing:
                          w.can('changeMemberRoles') || w.can('removeMembers')
                          ? PopupMenuButton<String>(
                              tooltip: raftText(context, 'Member actions'),
                              onSelected: (role) => change(member, role),
                              itemBuilder: (_) => [
                                if (w.can('changeMemberRoles')) ...[
                                  for (final role
                                      in w.server!.string('role') == 'owner'
                                          ? [
                                              'owner',
                                              'admin',
                                              'member',
                                              'guest',
                                            ]
                                          : ['member', 'guest'])
                                    PopupMenuItem(
                                      value: role,
                                      child: Text(
                                        raftFormat(context, 'Make {role}', {
                                          'role': raftText(
                                            context,
                                            '${role[0].toUpperCase()}${role.substring(1)}',
                                          ),
                                        }),
                                      ),
                                    ),
                                ],
                                if (w.can('removeMembers') &&
                                    member['userId'] != w.client.user!.id)
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text(
                                      raftText(context, 'Remove member'),
                                    ),
                                  ),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
      ),
    ],
  );
}
