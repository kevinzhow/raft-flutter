import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'add_members_dialog.dart';
import 'integrations_views.dart'
    show integrationScopeCopy, integrationVisibleScopes;
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

/// Source isActionCardReadOnlyInServer (shared/actionCards.ts): an absent
/// `sourceServerId` is an older server (not read-only); an explicit `null` is
/// an unavailable card owner and a foreign id is a history copy.
bool actionCardReadOnlyInServer(
  Map<String, dynamic> metadata,
  String? viewerServerId,
) =>
    metadata.containsKey('sourceServerId') &&
    (metadata['sourceServerId'] == null ||
        metadata['sourceServerId'] != viewerServerId);

/// The thread's parent channel as the wire carries it
/// (`conversationContext.parentChannelId`), null outside a thread.
String? messageParentChannelId(Map<String, dynamic> message) {
  final context = message['conversationContext'];
  final id = context is Map ? context['parentChannelId'] : null;
  return id is String && id.isNotEmpty ? id : null;
}

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
  String? openingAuthority;
  // Why the last confirm failed. Bound to the card state it failed in: once
  // the card moves on (executed elsewhere, a new confirmation version, another
  // workspace) the message no longer describes it. A new confirm clears it.
  final CauseNotice errorNotice = CauseNotice();
  String? get error => errorNotice.message;

  /// Raises [message] for as long as the card is in the state it failed in.
  void raiseError(String message, String authority) {
    final state = metadata['state'], version = metadata['confirmationVersion'];
    errorNotice.raise(
      message,
      whileTrue: () =>
          mounted &&
          authority == workspaceAuthority(w) &&
          metadata['state'] == state &&
          metadata['confirmationVersion'] == version,
    );
  }

  dynamic openingVersion;
  Route<dynamic>? ownedDialog;
  Map<String, dynamic> get metadata {
    final latest = [
      ...w.messageDomain.messages,
      ...w.replies,
      if (w.messageDomain.state.threadParent != null)
        w.messageDomain.state.threadParent!,
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
                (messageParentChannelId(widget.message.json) ??
                    widget.message.channelId),
          )
          .firstOrNull ??
      w.channel;
  String? get blocked {
    if (actionCardReadOnlyInServer(metadata, w.server?.id)) {
      final server = metadata['targetServerName'];
      return server is String
          ? 'This action runs on $server. Switch to $server to run it.'
          : 'This is a history copy. Only the source workspace can run this action.';
    }
    final c = carrier;
    if (c == null ||
        (c.id != widget.message.channelId &&
            w.threadChannelId != widget.message.channelId)) {
      return 'The action channel is unavailable.';
    }
    if (c.archived) {
      return 'This channel is archived, so its actions can no longer be run.';
    }
    if (w.server?.string('role') == 'guest') {
      return "Guests can't run channel actions.";
    }
    if (!c.joined &&
        c.type != 'dm' &&
        !['owner', 'admin'].contains(w.server?.string('role'))) {
      return 'Join #${c.name} to run this.';
    }
    if (type == 'agent:create' && !w.can('createAgents')) {
      return 'You need the Create Agents permission — ask a Server owner or admin to run this.';
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
    // Names in the summary resolve through the server directories.
    w.services.entityDirectory.addListener(changed);
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
    w.services.entityDirectory.removeListener(changed);
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
          () => raiseError(
            'The resource was created, but the action card could not be updated.',
            authority,
          ),
        );
      }
      await event('action_card.execute_fail');
    }
  }

  Future<List<Map<String, dynamic>>> people() async {
    // The workspace directory already holds both lists (same endpoints), so
    // the form opens at once; only a directory that never loaded is fetched.
    final directory = w.services.entityDirectory;
    final loaded =
        directory.state(WorkspaceEntityKind.members).loaded &&
        directory.state(WorkspaceEntityKind.agents).loaded;
    final result = loaded
        ? [
            directory.rows(WorkspaceEntityKind.members),
            directory.rows(WorkspaceEntityKind.agents),
          ]
        : await Future.wait([
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

  /// A product dialog on the Web `Modal` layer (it paints its own backdrop).
  Future<bool?> modal(
    String authority,
    Widget Function(BuildContext) builder,
  ) => showRaftModal<bool>(
    context,
    builder: (ctx) {
      ownedDialog = ModalRoute.of(ctx);
      return builder(ctx);
    },
  );

  Future<bool?> form(String authority, Widget Function(BuildContext) builder) =>
      showRaftForm<bool>(
        context,
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
    final reconfirming = metadata['state'] == 'reconfirm_required';
    openingAuthority = authority;
    openingVersion = version;
    setState(() {
      busy = true;
      errorNotice.clear();
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
      // A best-effort product event never gates the dialog.
      unawaited(event('action_card.open'));
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
      if (type == 'channel:add_member') {
        var submitted = false;
        final accepted = await modal(
          authority,
          (ctx) => AddMembersDialog(
            controller: w,
            channelId: '${snapshot['channel']}',
            prefilledHumanIds: [
              ...(snapshot['humans'] as List? ?? const []).whereType<String>(),
            ],
            prefilledAgentIds: [
              ...(snapshot['agents'] as List? ?? const []).whereType<String>(),
            ],
            actionCardMessageId: widget.message.id,
            actionCardConfirmationVersion: version,
            onSubmitStart: () async {
              requireCurrent(authority);
              await event('action_card.execute_attempt');
              requireCurrent(authority);
            },
            onSubmitError: (_) => unawaited(event('action_card.execute_fail')),
            onSubmitted: (result) async {
              submitted = true;
              if (!current(authority)) return;
              await mark(
                {
                  'kind': 'channel-members',
                  'channelId': result.channelId,
                  'channelName': result.channelName,
                  'addedHumanIds': result.addedHumanIds,
                  'addedAgentIds': result.addedAgentIds,
                },
                authority,
                version,
              );
              await w.refreshChannels();
            },
          ),
        );
        if (accepted != true && !submitted) await event('action_card.dismiss');
        return;
      }
      final candidates = await people();
      if (!mounted || !current(authority)) return;
      final users = <String>{
        ...(snapshot['initialHumans'] as List? ?? []).whereType<String>(),
      };
      final agents = <String>{
        ...(snapshot['initialAgents'] as List? ?? []).whereType<String>(),
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
          title: 'Create channel',
          submitLabel: 'Create',
          fields: [
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
            await event('action_card.execute_attempt');
            requireCurrent(authority);
            try {
              final result = await w.client.request(
                'POST',
                '/channels',
                data: {
                  ...values,
                  'type': 'channel',
                  'userIds': users.toList(),
                  'agentIds': agents.toList(),
                  'actionCardMessageId': widget.message.id,
                  'actionCardConfirmationVersion': version,
                },
              );
              submitted = true;
              if (current(authority)) {
                await mark(
                  {
                    'kind': 'channel',
                    'id': result['id'],
                    'name': result['name'],
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
      if (current(authority)) {
        // Web ActionCard: the server's text, else `actionCard.reconfirmationFailed`
        // / `actionCard.executeFailed`.
        setState(
          () => raiseError(
            userErrorText(
              e,
              fallback: reconfirming
                  ? 'Reconfirmation failed'
                  : 'Failed to execute action',
              where: 'action card',
            ),
            authority,
          ),
        );
      }
    } finally {
      ownedDialog = null;
      openingAuthority = null;
      openingVersion = null;
      if (mounted) setState(() => busy = false);
    }
  }

  static const _known = {
    'channel:create',
    'agent:create',
    'channel:add_member',
    'integration:approve_agent_login',
    'integration:install_marketplace_app',
    'integration:register_app',
    'integration:update_app_registration',
    'integration:recover_app_owner',
  };

  String _short(String id) => id.length > 8 ? id.substring(0, 8) : id;

  String _memberName(String id) {
    final m = w.services.entityDirectory.member(id);
    final name = m?['displayName'] ?? m?['name'];
    return name is String && name.isNotEmpty ? name : _short(id);
  }

  String _agentName(String id) {
    final a = w.services.entityDirectory.agent(id);
    final name = a?['displayName'] ?? a?['name'];
    return name is String && name.isNotEmpty ? name : _short(id);
  }

  List<String> _list(Object? value) =>
      value is List ? value.whereType<String>().toList() : const [];

  /// ActionTitleLine: the localized title split into its flex items (text
  /// pieces and `<n>` chunks), each trimmed like a collapsed anonymous item.
  List<String> _titleParts(BuildContext context) {
    String f(String template, Map<String, Object?> values) =>
        raftFormat(context, template, values);
    final channel = w.channels
        .where((c) => c.id == action['channel'])
        .firstOrNull;
    final raw = switch (type) {
      'channel:create' => f(
        action['visibility'] == 'private'
            ? 'Create private channel <n>#{name}</n>'
            : 'Create public channel <n>#{name}</n>',
        {'name': action['name'] ?? ''},
      ),
      'agent:create' => f('Create Agent <n>@{name}</n>', {
        'name': action['name'] ?? '',
      }),
      'channel:add_member' => () {
        final count =
            _list(action['humans']).length + _list(action['agents']).length;
        return f(
          count == 1
              ? 'Add 1 member to <n>{target}</n>'
              : 'Add {count} members to <n>{target}</n>',
          {
            'count': count,
            'target': channel?.name != null
                ? '#${channel!.name}'
                : raftText(context, 'channel'),
          },
        );
      }(),
      'integration:approve_agent_login' => f(
        'Approve <n>{client}</n> for <n>@{agent}</n>',
        {'client': action['clientName'], 'agent': action['agentName']},
      ),
      'integration:install_marketplace_app' => f(
        'Install <n>{client}</n> for <n>@{agent}</n>',
        {'client': action['clientName'], 'agent': action['agentName']},
      ),
      'integration:register_app' => f('Register app <n>{name}</n>', {
        'name': action['name'],
      }),
      'integration:update_app_registration' => f(
        'Update app <n>{clientKey}</n>',
        {'clientKey': action['clientKey']},
      ),
      _ => f('Recover <n>{clientKey}</n> for <n>@{agent}</n>', {
        'clientKey': action['clientKey'],
        'agent': _agentName('${action['targetAgent']}'),
      }),
    };
    return [
      for (final piece in raw.split(RegExp(r'</?n>')))
        if (piece.trim().isNotEmpty) piece.trim(),
    ];
  }

  Widget _scopes(BuildContext context, {String? agentName}) {
    final scopes = _list(action['scopes']);
    final visible = <String>[];
    for (final scope in scopes) {
      if (integrationVisibleScopes.contains(scope) &&
          !visible.contains(scope)) {
        visible.add(scope);
      }
    }
    if (visible.isEmpty) {
      return RaftActionField(
        label: 'Scopes:',
        value: scopes.isEmpty ? '-' : scopes.join(', '),
      );
    }
    final inbound = visible.any(
      (s) =>
          const {'agent:event:write', 'agent:notification:write'}.contains(s),
    );
    return RaftActionField(
      label: 'Scopes:',
      child: RaftActionScopeList(
        scopes: [
          for (final s in visible)
            (scope: s, copy: integrationScopeCopy[s] ?? ''),
        ],
        footer: [
          if (agentName != null && inbound)
            RaftActionNote(
              raftFormat(context, 'Will send to: @{agent}', {
                'agent': agentName,
              }),
              tone: RaftActionTone.strong,
            ),
          if (inbound)
            const RaftActionWarningBox(
              'Cannot send chat as you, speak as the agent, read messages, or take actions.',
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    Widget field(String label, String? value) =>
        RaftActionField(label: label, value: value);
    Widget? maybe(String label, Object? value) =>
        value is String && value.isNotEmpty ? field(label, value) : null;
    final humans = _list(action['humans'] ?? action['initialHumans']);
    final agents = _list(action['agents'] ?? action['initialAgents']);
    return switch (type) {
      'channel:create' => [
        ?maybe('Description:', action['description']),
        if (humans.isNotEmpty)
          field('Humans:', humans.map(_memberName).join(', ')),
        if (agents.isNotEmpty)
          field('Agents:', agents.map(_agentName).join(', ')),
      ],
      'agent:create' => () {
        final computer =
            action['requiredComputer'] ?? action['suggestedComputer'];
        final machine = computer is String
            ? w.services.entityDirectory.computer(computer)
            : null;
        final description = action['description'];
        return [
          if (description is String && description.isNotEmpty)
            field('Description:', description)
          else
            const RaftActionNote(
              'No description prefilled.',
              tone: RaftActionTone.hint,
            ),
          if (computer is String)
            field(
              action['requiredComputer'] != null
                  ? 'Required computer:'
                  : 'Suggested computer:',
              '${machine?['name'] ?? _short(computer)}',
            ),
        ];
      }(),
      'channel:add_member' => () {
        final channel = w.channels
            .where((c) => c.id == action['channel'])
            .firstOrNull;
        return [
          if (channel != null) field('Channel:', '#${channel.name}'),
          if (humans.isNotEmpty)
            field('Humans:', humans.map(_memberName).join(', ')),
          if (agents.isNotEmpty)
            field('Agents:', agents.map(_agentName).join(', ')),
        ];
      }(),
      'integration:approve_agent_login' => [
        field('Service:', '${action['clientName']}'),
        field('Agent:', '@${action['agentName']}'),
        _scopes(context, agentName: '${action['agentName']}'),
      ],
      'integration:install_marketplace_app' => [
        field('Service:', '${action['clientName']}'),
        field('Agent:', '@${action['agentName']}'),
        _scopes(context, agentName: '${action['agentName']}'),
        const RaftActionNote(
          'Only a Server owner or admin can install this Marketplace app. The Agent cannot install it automatically.',
          tone: RaftActionTone.orange,
        ),
      ],
      'integration:register_app' => [
        field(
          'Client key:',
          action['clientKey'] is String
              ? action['clientKey']
              : raftText(context, 'Auto-generated on commit'),
        ),
        field('Redirect URL:', '${action['returnUrl']}'),
        ?maybe('App URL:', action['homepageUrl']),
        ?maybe('Agent manifest:', action['agentManifestUrl']),
        _scopes(context),
        const RaftActionNote(
          "The requesting agent becomes this app's owner and can rotate, update, or transfer it after commit.",
        ),
        if (action['unsafeDemoUrlOverride'] == true)
          const RaftActionNote(
            'Unsafe demo URL override requested.',
            tone: RaftActionTone.amber,
          ),
      ],
      'integration:update_app_registration' => [
        field('Client key:', '${action['clientKey']}'),
        ?maybe('Name:', action['name']),
        ?maybe('Redirect URL:', action['returnUrl']),
        ?maybe('App URL:', action['homepageUrl']),
        ?maybe('Agent manifest:', action['agentManifestUrl']),
        if (action['scopes'] is List) _scopes(context),
        if (action['unsafeDemoUrlOverride'] == true)
          const RaftActionNote(
            'Unsafe demo URL override requested.',
            tone: RaftActionTone.amber,
          ),
      ],
      _ => [
        field('Client key:', '${action['clientKey']}'),
        field('Recovery owner:', '@${_agentName('${action['targetAgent']}')}'),
        const RaftActionNote(
          'Admin recovery only. Execution is rejected while the app has an active owner.',
          tone: RaftActionTone.amber,
        ),
      ],
    };
  }

  /// ResultLink: `→ ...` for the resource the execute step produced.
  String? _resultText(BuildContext context) {
    final result = _map(metadata['result']);
    if (result.isEmpty) return null;
    String f(String template, Map<String, Object?> values) =>
        raftFormat(context, template, values);
    final body = switch (result['kind']) {
      'channel' => '#${result['name']}',
      'agent' => '@${result['name']}',
      'channel-members' => f('{count} added to #{channel}', {
        'count':
            _list(result['addedHumanIds']).length +
            _list(result['addedAgentIds']).length,
        'channel': result['channelName'],
      }),
      'agent-integration-login' => f('{client} approved for @{agent}', {
        'client': result['clientName'],
        'agent': result['agentName'],
      }),
      'marketplace-app-installation' => f('{client} installed on this Server', {
        'client': result['clientName'],
      }),
      'integration-app-registration' => f(
        result['mode'] == 'register'
            ? '{client} registered ({clientKey})'
            : '{client} updated ({clientKey})',
        {'client': result['clientName'], 'clientKey': result['clientKey']},
      ),
      'integration-app-owner-recovery' => f(
        '{client} ownership recovered to @{owner}',
        {'client': result['clientName'], 'owner': result['ownerAgentName']},
      ),
      _ => null,
    };
    return body == null ? null : '\u2192 $body';
  }

  Widget _knownCard(BuildContext context) {
    const verbs = {
      'channel:create': 'Create Channel',
      'agent:create': 'Create Agent',
      'channel:add_member': 'Add Members',
      'integration:approve_agent_login': 'Approve Login',
      'integration:install_marketplace_app': 'Install App',
      'integration:register_app': 'Register App',
      'integration:update_app_registration': 'Update App',
      'integration:recover_app_owner': 'Recover Owner',
    };
    final server = metadata['targetServerName'];
    return RaftActionCard(
      title: '',
      titleParts: _titleParts(context),
      body: _body(context),
      state: '${metadata['state']}',
      hint: action['draftHint'],
      targetServer: carrier?.type == 'joint' && server is String
          ? server
          : null,
      completedBy: metadata['executedByUserName'],
      completedResult: _resultText(context),
      // ignore: raft_lints/avoid_render_index_assertion -- Only reached for known action types; `verbs` lists every type _knownCard renders.
      confirmLabel: verbs[type]!,
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

  @override
  Widget build(BuildContext context) {
    if (_known.contains(type)) return _knownCard(context);
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
        if (key == 'name' &&
            {'channel:create', 'agent:create'}.contains(type)) {
          continue;
        }
        if (action[key] is String) {
          details.add((
            // ignore: raft_lints/avoid_render_index_assertion -- `key` iterates the same fixed list of five keys the literal map covers.
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
      'channel:create' => raftFormat(
        context,
        action['visibility'] == 'private'
            ? 'Create private channel #{name}'
            : 'Create public channel #{name}',
        {'name': action['name'] ?? ''},
      ),
      'agent:create' => raftFormat(context, 'Create agent {name}', {
        'name': action['name'] ?? '',
      }),
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
