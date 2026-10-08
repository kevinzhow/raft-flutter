import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import 'managed_agent_launcher.dart';
import 'private_route_guard.dart';

const _inlineActions = {
  'integration:approve_agent_login',
  'integration:install_marketplace_app',
  'integration:register_app',
  'integration:update_app_registration',
  'integration:recover_app_owner',
};
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};

class MessageActionCard extends StatefulWidget {
  const MessageActionCard({
    super.key,
    required this.controller,
    required this.message,
    this.exportMode = false,
  });
  final WorkspaceController controller;
  final RaftMessage message;
  final bool exportMode;
  @override
  State<MessageActionCard> createState() => _MessageActionCardState();
}

class _MessageActionCardState extends State<MessageActionCard> {
  WorkspaceController get w => widget.controller;
  Map<String, dynamic>? responseMetadata;
  bool busy = false;
  String? error, openingAuthority;
  dynamic openingVersion;
  Route<dynamic>? ownedDialog;
  Map<String, dynamic> get metadata {
    final latest = [
      ...w.messages,
      ...w.replies,
      if (w.threadParent != null) w.threadParent!,
    ].where((m) => m.id == widget.message.id).firstOrNull;
    if (latest != null &&
        jsonEncode(latest.json['actionMetadata']) !=
            jsonEncode(widget.message.json['actionMetadata'])) {
      return _map(latest.json['actionMetadata']);
    }
    return responseMetadata ?? _map(widget.message.json['actionMetadata']);
  }

  Map<String, dynamic> get action => _map(metadata['action']);
  String get type => '${action['type'] ?? ''}';
  RaftChannel? get carrier =>
      [...w.channels, ...w.dms]
          .where(
            (c) =>
                c.id ==
                (widget.message.json['parentChannelId'] ??
                    widget.message.channelId),
          )
          .firstOrNull ??
      w.channel;
  String? get blocked {
    if (metadata['sourceServerId'] != null &&
        metadata['sourceServerId'] != w.server?.id) {
      return 'Switch to the target workspace to use this action.';
    }
    final c = carrier;
    if (c == null ||
        (c.id != widget.message.channelId &&
            w.threadChannelId != widget.message.channelId)) {
      return 'The action channel is unavailable.';
    }
    if (c.archived) return 'This channel is archived.';
    if (w.server?.string('role') == 'guest') {
      return 'Guests cannot confirm actions.';
    }
    if (!c.joined && !['owner', 'admin'].contains(w.server?.string('role'))) {
      return 'Join this channel before confirming an action.';
    }
    if (type == 'agent:create' && !w.can('createAgents')) {
      return 'You do not have permission to create agents.';
    }
    if (type == 'channel:create' && !w.can('createChannels')) {
      return 'You do not have permission to create channels.';
    }
    if (type == 'channel:add_member') {
      final target = w.channels
          .where((c) => c.id == action['channel'])
          .firstOrNull;
      if (target == null ||
          target.archived ||
          !w.can('addChannelMembers', resource: target)) {
        return 'You do not have permission to add members to this channel.';
      }
    }
    if (!_inlineActions.contains(type) &&
        !{
          'agent:create',
          'channel:create',
          'channel:add_member',
        }.contains(type)) {
      return 'This action needs a newer client.';
    }
    if (!{
      'prepared',
      'executed',
      'frozen',
      'reconfirm_required',
    }.contains(metadata['state'])) {
      return 'This action needs a newer client.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    w.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant MessageActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (jsonEncode(oldWidget.message.json['actionMetadata']) !=
        jsonEncode(widget.message.json['actionMetadata'])) {
      responseMetadata = null;
    }
  }

  void changed() {
    if (!mounted) return;
    if (openingAuthority != null &&
        (openingAuthority != workspaceAuthority(w) ||
            blocked != null ||
            metadata['state'] != 'prepared' ||
            metadata['confirmationVersion'] != openingVersion)) {
      final stale = ownedDialog;
      if (stale != null && stale.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (stale.isActive) stale.navigator?.removeRoute(stale);
        });
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    w.removeListener(changed);
    final stale = ownedDialog;
    if (stale != null && stale.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (stale.isActive) stale.navigator?.removeRoute(stale);
      });
    }
    super.dispose();
  }

  bool current(String authority) =>
      mounted && authority == workspaceAuthority(w) && blocked == null;
  void requireCurrent(String authority) {
    if (!current(authority) ||
        metadata['state'] != 'prepared' ||
        metadata['confirmationVersion'] != openingVersion) {
      throw StateError('The active workspace changed. Reopen this form.');
    }
  }

  Future<void> event(String name) async {
    try {
      await w.client.request(
        'POST',
        '/actions/${widget.message.id}/event',
        data: {'eventType': name, 'metadata': {}},
      );
    } catch (_) {
      /* Best-effort product event; never author execute_success. */
    }
  }

  Future<void> apply(
    String path,
    Map<String, dynamic>? data,
    String authority,
  ) async {
    final out = await w.client.request(
      'POST',
      '/actions/${widget.message.id}/$path',
      data: data,
    );
    if (current(authority) &&
        out is Map &&
        out['messageId'] == widget.message.id &&
        out['metadata'] is Map) {
      setState(() => responseMetadata = _map(out['metadata']));
    }
  }

  Future<void> mark(
    Map<String, dynamic> result,
    String authority,
    dynamic version,
  ) async {
    // A created resource is retained even if synchronizing the card fails.
    try {
      await apply('mark-executed', {
        'result': result,
        'expectedConfirmationVersion': version,
      }, authority);
    } catch (_) {
      if (current(authority)) {
        setState(
          () => error = 'The resource was created, but the action card could not be updated.',
        );
      }
      await event('action_card.execute_fail');
    }
  }

  Future<List<Map<String, dynamic>>> people() async {
    final result = await Future.wait([
      w.query('/servers/${w.server!.id}/members'),
      w.query('/agents'),
    ]);
    List<Map<String, dynamic>> rows(dynamic v, String key, String kind) {
      final values = v is List ? v : v[key] ?? [];
      return (values as List)
          .whereType<Map>()
          .map(
            (p) => {
              ...Map<String, dynamic>.from(p),
              'actorType': kind,
              'id': kind == 'user' ? p['userId'] ?? p['id'] : p['id'],
            },
          )
          .toList();
    }

    return [
      ...rows(result[0], 'members', 'user'),
      ...rows(result[1], 'agents', 'agent'),
    ];
  }

  Future<bool?> form(String authority, Widget Function(BuildContext) builder) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) {
          ownedDialog = ModalRoute.of(ctx);
          return builder(ctx);
        },
      );
  Future<void> confirm() async {
    if (busy ||
        blocked != null ||
        !{'prepared', 'reconfirm_required'}.contains(metadata['state'])) {
      return;
    }
    final authority = workspaceAuthority(w),
        snapshot = Map<String, dynamic>.from(action),
        version = metadata['confirmationVersion'];
    openingAuthority = authority;
    openingVersion = version;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (metadata['state'] == 'reconfirm_required') {
        await apply('reconfirm', null, authority);
        return;
      }
      if (_inlineActions.contains(type)) {
        await apply('execute', {
          'expectedState': 'prepared',
          'expectedConfirmationVersion': version,
        }, authority);
        return;
      }
      await event('action_card.open');
      if (!mounted || !current(authority)) return;
      if (type == 'agent:create') {
        final created = await showManagedAgentForm(
          context,
          w,
          initialName: snapshot['name'],
          initialDescription: snapshot['description'],
          suggestedComputer: snapshot['suggestedComputer'],
          requiredComputer: snapshot['requiredComputer'],
          actionCardMessageId: widget.message.id,
          actionCardConfirmationVersion: version,
        );
        if (created != null && current(authority)) {
          await mark(
            {'kind': 'agent', 'id': created['id'], 'name': created['name']},
            authority,
            version,
          );
        } else {
          await event('action_card.dismiss');
        }
        return;
      }
      final candidates = await people();
      if (!mounted || !current(authority)) return;
      final users = <String>{
        ...(snapshot[type == 'channel:create' ? 'initialHumans' : 'humans']
                    as List? ??
                [])
            .whereType<String>(),
      };
      final agents = <String>{
        ...(snapshot[type == 'channel:create' ? 'initialAgents' : 'agents']
                    as List? ??
                [])
            .whereType<String>(),
      };
      // Only current visible directory identities can become submissions.
      users.removeWhere(
        (id) =>
            !candidates.any((p) => p['actorType'] == 'user' && p['id'] == id),
      );
      agents.removeWhere(
        (id) =>
            !candidates.any((p) => p['actorType'] == 'agent' && p['id'] == id),
      );
      var submitted = false;
      final accepted = await form(
        authority,
        (ctx) => RaftFormDialog(
          title: type == 'channel:create' ? 'Create channel' : 'Add members',
          submitLabel: type == 'channel:create' ? 'Create' : 'Add',
          fields: [
            if (type == 'channel:create') ...[
              RaftFormField(
                'name',
                'Channel name',
                initial: snapshot['name'],
                required: true,
              ),
              RaftFormField(
                'description',
                'Description',
                initial: snapshot['description'] ?? '',
                multiline: true,
              ),
              RaftFormField(
                'visibility',
                'Visibility',
                initial: snapshot['visibility'] ?? 'public',
                choices: const {
                  'public': 'Public channel',
                  'private': 'Private channel',
                },
              ),
            ],
          ],
          extra: StatefulBuilder(
            builder: (context, setLocal) => Column(
              children: [
                for (final p in candidates)
                  CheckboxListTile(
                    key: ValueKey('action-member-${p['actorType']}-${p['id']}'),
                    dense: true,
                    title: Text('${p['displayName'] ?? p['name'] ?? p['id']}'),
                    subtitle: Text(
                      raftText(
                        context,
                        p['actorType'] == 'agent' ? 'Agent' : 'Member',
                      ),
                    ),
                    value: (p['actorType'] == 'agent' ? agents : users)
                        .contains(p['id']),
                    onChanged: (v) => setLocal(() {
                      final selected = p['actorType'] == 'agent'
                          ? agents
                          : users;
                      v == true
                          ? selected.add(p['id'])
                          : selected.remove(p['id']);
                    }),
                  ),
              ],
            ),
          ),
          onSubmit: (values) async {
            requireCurrent(authority);
            if (type == 'channel:add_member' &&
                users.isEmpty &&
                agents.isEmpty) {
              throw StateError('Select at least one member.');
            }
            await event('action_card.execute_attempt');
            requireCurrent(authority);
            try {
              final result = await w.client.request(
                'POST',
                type == 'channel:create'
                    ? '/channels'
                    : '/channels/${snapshot['channel']}/members/batch',
                data: {
                  if (type == 'channel:create') ...values,
                  if (type == 'channel:create') 'type': 'channel',
                  'userIds': users.toList(),
                  'agentIds': agents.toList(),
                  'actionCardMessageId': widget.message.id,
                  'actionCardConfirmationVersion': version,
                },
              );
              submitted = true;
              if (current(authority)) {
                await mark(
                  type == 'channel:create'
                      ? {
                          'kind': 'channel',
                          'id': result['id'],
                          'name': result['name'],
                        }
                      : {
                          'kind': 'channel-members',
                          'channelId': snapshot['channel'],
                          'channelName':
                              w.channels
                                  .where((c) => c.id == snapshot['channel'])
                                  .firstOrNull
                                  ?.name ??
                              '',
                          'addedHumanIds': users.toList(),
                          'addedAgentIds': agents.toList(),
                        },
                  authority,
                  version,
                );
                await w.refreshChannels();
              }
            } catch (_) {
              await event('action_card.execute_fail');
              rethrow;
            }
          },
        ),
      );
      if (accepted != true && !submitted) await event('action_card.dismiss');
    } catch (e) {
      if (current(authority)) setState(() => error = '$e');
    } finally {
      ownedDialog = null;
      openingAuthority = null;
      openingVersion = null;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _map(metadata['presentation']);
    final labels = {
      'channel:create': 'Create channel',
      'agent:create': 'Create agent',
      'channel:add_member': 'Add members',
      'integration:approve_agent_login': 'Approve agent login',
      'integration:install_marketplace_app': 'Install app',
      'integration:register_app': 'Register app',
      'integration:update_app_registration': 'Update app',
      'integration:recover_app_owner': 'Recover app owner',
    };
    final details = <({String label, String value})>[];
    // Only server-designated safe fields and known non-secret action summaries.
    if (presentation['displayItems'] is List) {
      for (final item
          in (presentation['displayItems'] as List).whereType<Map>()) {
        details.add((label: '${item['key']}', value: '${item['value']}'));
      }
    } else {
      for (final key in [
        'name',
        'description',
        'clientName',
        'agentName',
        'clientKey',
      ]) {
        if (key == 'name' && {'channel:create', 'agent:create'}.contains(type)) continue;
        if (action[key] is String) {
          details.add((
            label: const {
              'name': 'Name',
              'description': 'Description',
              'clientName': 'App',
              'agentName': 'Agent',
              'clientKey': 'App identifier',
            }[key]!,
            value: action[key],
          ));
        }
      }
    }
    final fallbackTitle = switch (type) {
      'channel:create' => raftFormat(context, action['visibility'] == 'private' ? 'Create private channel #{name}' : 'Create public channel #{name}', {'name': action['name'] ?? ''}),
      'agent:create' => raftFormat(context, 'Create agent {name}', {'name': action['name'] ?? ''}),
      _ => raftText(context, labels[type] ?? 'Action'),
    };
    return RaftActionCard(
      title: presentation['title'] is String
          ? presentation['title']
          : fallbackTitle,
      state: '${metadata['state']}',
      details: details,
      hint: action['draftHint'],
      targetServer: metadata['targetServerName'],
      completedBy: metadata['executedByUserName'],
      confirmLabel: labels[type] ?? 'Confirm',
      blockedReason: blocked,
      error: error,
      busy:
          busy &&
          (_inlineActions.contains(type) ||
              metadata['state'] == 'reconfirm_required'),
      onConfirm: busy
          ? null
          : widget.exportMode
          ? () {}
          : confirm,
    );
  }
}
