import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/agent_migration_status.dart' show agentPlacesWithoutSource;
import '../data/app_install_expectation.dart' show appPromptTextConsent;
import '../data/cause_notice.dart';
import '../data/message_history_events.dart';
import '../data/raft_location.dart';
import '../data/source_time_formatter.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import '../platform/bounded_lru.dart';
import '../platform/content_links.dart';
import '../platform/web_billing.dart' show openInBrowser, WebBillingGate;
import 'action_card_form.dart';
import 'action_card_install.dart';
import 'action_card_mcp.dart';
import 'action_card_spec.dart';
import 'action_card_spec_view.dart';
import 'add_members_dialog.dart';
import 'agent_migration_start_dialog.dart';
import 'agent_profile_rules.dart' show canViewAgentPrivateSurfaces;
import 'app_setup.dart';
import 'integrations_views.dart'
    show integrationScopeCopy, integrationVisibleScopes;
import 'managed_agent_launcher.dart';
import 'management_support.dart' show managementLaunch;
import 'message_card_read.dart' show publicCardUrl;
import 'private_route_guard.dart';
import 'second_factor_step_up.dart';
import 'workspace_web_billing.dart';

const _inlineActions = {
  'integration:approve_agent_login',
  'integration:install_marketplace_app',
  'integration:register_app',
  'integration:update_app_registration',
  'integration:recover_app_owner',
};
final _feedbackTicketId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _formDrafts =
    Expando<
      BoundedLruMap<(String, String, String, Object?), ActionCardFormDraft>
    >();
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
  Object? _lastRawSpec;
  ActionCardSpec? _lastSpec;
  Object? get rawSpec => _map(metadata['presentation'])['card'];
  Map<String, dynamic>? get _migrationAgent {
    final id = cardString(action['agentId']);
    final agent = id == null ? null : w.services.entityDirectory.agent(id);
    return agent?['deletedAt'] == null ? agent : null;
  }

  ActionCardSpec? get spec {
    final raw = rawSpec;
    if (!identical(raw, _lastRawSpec)) {
      _lastRawSpec = raw;
      _lastSpec = ActionCardSpec.read(raw);
    }
    return _lastSpec;
  }

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
          : 'This is a history copy. Only the source server can run this action.';
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
    if (w.server?.string('role') == 'guest' &&
        !(c.joined &&
            const {'question:ask', 'feedback:submit'}.contains(type))) {
      return "Guests can't run channel actions.";
    }
    if (!c.joined &&
        c.type != 'dm' &&
        !['owner', 'admin'].contains(w.server?.string('role'))) {
      return 'Join #${c.name} to run this.';
    }
    if (type == 'agent:create' && !w.can('createAgents')) {
      return 'You need the Create Agents permission — ask a server owner or admin to run this.';
    }
    if (type == 'agent:migrate') {
      final agent = _migrationAgent;
      final assistantOwner = agent?['assistantOwnerUserId'];
      if (agent == null ||
          (assistantOwner != null
              ? assistantOwner != w.client.user?.id
              : !canViewAgentPrivateSurfaces(
                  agent,
                  w.client.user?.id,
                  w.can('migrateAgents'),
                ))) {
        return raftFormat(
          context,
          "Only {agent}'s creator or someone with permission to migrate agents can do this.",
          {
            'agent':
                cardString(agent?['displayName']) ??
                cardString(agent?['name']) ??
                raftText(context, 'Agent'),
          },
        );
      }
    }
    if (type == 'seats:add' &&
        (w.server?.string('role') != 'owner' || !w.can('manageBilling'))) {
      return raftText(context, 'Only an owner can add seats.');
    }
    final viewer = w.client.user?.id;
    final questionAddressee = cardObject(action['addressee']);
    final addressee = questionAddressee['kind'] == 'user'
        ? cardString(questionAddressee['userId'])
        : null;
    if (type == 'question:ask' &&
        addressee != null &&
        addressee.toLowerCase() != viewer?.toLowerCase()) {
      return raftFormat(context, 'Waiting for {person} to answer.', {
        'person': _memberName(addressee),
      });
    }
    if (viewer != null && metadata['requesterUserId'] == viewer) {
      return raftText(
        context,
        "You sent this; it's for the other person to act on.",
      );
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
    if (spec == null &&
        !_inlineActions.contains(type) &&
        !{
          'agent:create',
          'channel:create',
          'channel:add_member',
        }.contains(type)) {
      return 'This action needs a newer client.';
    }
    if (spec == null &&
        !{
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
      throw StateError('The active server changed. Reopen this form.');
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
  ) => _apply(w, widget.message, path, data, authority);

  Future<void> _apply(
    WorkspaceController workspace,
    RaftMessage message,
    String path,
    Map<String, dynamic>? data,
    String authority,
  ) async {
    final out = await workspace.client.request(
      'POST',
      '/actions/${message.id}/$path',
      data: data,
    );
    _acceptActionResponse(workspace, message, authority, out);
  }

  void _acceptActionResponse(
    WorkspaceController workspace,
    RaftMessage message,
    String authority,
    Object? out,
  ) {
    if (authority == workspaceAuthority(workspace) &&
        out is Map &&
        out['messageId'] == message.id &&
        out['metadata'] is Map) {
      final next = _map(out['metadata']);
      if (mounted && widget.message.id == message.id) {
        setState(() => responseMetadata = next);
      }
      final stored = workspace.messageDomain.ledger
          .messages(message.channelId)
          .where((row) => row['id'] == message.id)
          .firstOrNull;
      if (stored != null) {
        MessageHistoryEvents.store(workspace, {
          ...stored,
          'actionMetadata': next,
        }, updateOnly: true);
      }
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
  ) => showRaftDialog<bool>(
    context: context,
    modal: true,
    builder: (ctx) {
      ownedDialog = ModalRoute.of(ctx);
      return builder(ctx);
    },
  );

  Future<bool?> form(
    String authority,
    Widget Function(BuildContext) builder, {
    bool guardUnsaved = true,
    bool dismissible = true,
  }) => showRaftForm<bool>(
    context,
    guardUnsaved: guardUnsaved,
    dismissible: dismissible,
    dragDismissible: dismissible,
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
        await withSecondFactorStepUp(
          context,
          w.client,
          () => apply('execute', {
            'expectedState': 'prepared',
            'expectedConfirmationVersion': version,
          }, authority),
          reason: StepUpReason.actionCard,
        );
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
          initialHosting: snapshot['hosting'],
          initialHostedModel: snapshot['model'],
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
          title: 'Create Channel',
          submitLabel: 'Create Channel',
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
                  RaftCheckboxRow(
                    key: ValueKey('action-member-${p['actorType']}-${p['id']}'),
                    dense: true,
                    title: '${p['displayName'] ?? p['name'] ?? p['id']}',
                    description: raftText(
                      context,
                      p['actorType'] == 'agent' ? 'Agent' : 'Member',
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
      // Closing "Verify it's you" is not a failure (Web
      // isSecondFactorStepUpCancelled): nothing ran.
      if (current(authority) && !isSecondFactorStepUpCancelled(e)) {
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
      'integration:register_app' => f('Create Raft app <n>{name}</n>', {
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
            const RaftActionNote('No description', tone: RaftActionTone.hint),
          if (computer is String)
            field(
              action['requiredComputer'] != null
                  ? 'Required computer:'
                  : 'Suggested computer:',
              '${machine?['name'] ?? _short(computer)}',
            ),
          if (action['hosting'] == 'antiproton')
            field(
              'Runs on:',
              action['model'] is String && '${action['model']}'.isNotEmpty
                  ? raftFormat(context, 'Cloud agent, model {model}', {
                      'model': action['model'],
                    })
                  : raftText(context, 'Cloud agent'),
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
          'Only a server owner or admin can install this marketplace app. The agent cannot install it automatically.',
          tone: RaftActionTone.orange,
        ),
        if (_nonEmpty(action['setupUrl'])) ...[
          const RaftActionNote('Setup required'),
          ?_note(action['setupDescription']),
        ],
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
        ?maybe('Setup page URL:', action['setupUrl']),
        ?maybe('Configuration instructions:', action['setupDescription']),
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
        ?maybe('Setup page URL:', action['setupUrl']),
        ?maybe('Configuration instructions:', action['setupDescription']),
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

  static bool _nonEmpty(Object? value) => value is String && value.isNotEmpty;

  static Widget? _note(Object? value) =>
      _nonEmpty(value) ? RaftActionNote(value as String) : null;

  CardJson? _cardEntity(CardJson ref) {
    final id = cardString(ref['id']);
    final currentServer = w.server?.id;
    if (id == null ||
        actionCardReadOnlyInServer(metadata, currentServer) ||
        ref['serverId'] != null && ref['serverId'] != currentServer) {
      return null;
    }
    final directory = w.services.entityDirectory;
    return switch (ref['kind']) {
      'user' => directory.member(id),
      'agent' => directory.agent(id),
      'computer' => directory.computer(id),
      'channel' => w.channelById(id)?.json,
      _ => null,
    };
  }

  String _entityName(CardJson ref) {
    final entity = _cardEntity(ref);
    return cardString(entity?['displayName']) ??
        cardString(entity?['name']) ??
        cardString(ref['fallback']) ??
        '';
  }

  bool _hasCardEntity(CardJson ref) => _cardEntity(ref) != null;

  ActionCardPress _resolvePress(ActionCardSpec card, ActionCardElement node) {
    final press = node.press;
    final argument = press.argument;
    return switch (press.command) {
      ActionCardCommand.execute
          when argument != null && card.confirmation(argument) == null =>
        actionCardBrowser,
      ActionCardCommand.form
          when argument == null ||
              ActionCardForm.read(argument, card.forms[argument]) == null =>
        actionCardBrowser,
      ActionCardCommand.intent
          when !const {
            'create_channel',
            'add_members',
            'create_agent',
            'add_seats',
            'upgrade_dialog',
            'feedback_form',
            'feedback_ticket',
            'migrate_agent',
            'send_create_agent_card',
          }.contains(argument) =>
        actionCardBrowser,
      ActionCardCommand.url when publicCardUrl(argument ?? '') == null =>
        actionCardBrowser,
      ActionCardCommand.target when !_canNavigate(press.target ?? const {}) =>
        actionCardBrowser,
      _ => press,
    };
  }

  bool _canNavigate(CardJson target) =>
      cardString(target['id']) != null &&
      !actionCardReadOnlyInServer(metadata, w.server?.id) &&
      (target['serverId'] == null || target['serverId'] == w.server?.id) &&
      switch (target['kind']) {
        'agent' || 'user' => true,
        'channel' => w.channelById('${target['id']}') != null,
        'message' => cardString(target['channelId']) != null,
        _ => false,
      };

  Future<void> _openCardInBrowser([Uri? url]) async {
    final slug = w.server?.string('slug');
    if (url == null && slug != null && slug.isNotEmpty) {
      final thread = widget.message.channelId == w.threadChannelId
          ? w.messageDomain.state.threadParent
          : null;
      url = ContentLinks.messageUrl(
        origin: ContentLinks.originFor(w.client.origin),
        slug: slug,
        channelId: thread?.channelId ?? widget.message.channelId,
        messageId: widget.message.id,
        kind: carrier?.type ?? 'channel',
        parentMessageId: thread?.id,
      );
    }
    if ((url == null || !await openInBrowser(url)) && mounted) {
      showRaftToast(context, 'Could not open this address.');
    }
  }

  Future<void> _navigateCard(CardJson target) async {
    final id = cardString(target['id']);
    if (id == null || !_canNavigate(target)) {
      await _openCardInBrowser();
      return;
    }
    switch (target['kind']) {
      case 'agent':
        w.openProfile(RaftProfileKind.agent, id);
      case 'user':
        w.openProfile(RaftProfileKind.human, id);
      case 'channel':
        final channel = w.channelById(id);
        if (channel != null) await w.selectChannel(channel);
      case 'message':
        final channelId = cardString(target['channelId']);
        if (channelId != null) await w.jumpToMessage(channelId, id);
    }
  }

  List<ActionCardCandidate> _candidates(ActionCardField field) {
    if (field.type == ActionCardFieldType.channelPicker) {
      return [
        for (final channel in w.channels)
          if (!channel.archived &&
              (field.spec['scope'] != 'joined' || channel.joined))
            (id: channel.id, label: '#${channel.name}'),
      ];
    }
    final kinds = cardList(field.spec['kinds']);
    final directory = w.services.entityDirectory;
    final rows = [
      if (kinds.contains('human'))
        ...directory.rows(WorkspaceEntityKind.members),
      if (kinds.contains('agent') ||
          field.type == ActionCardFieldType.agentPicker)
        ...directory.rows(WorkspaceEntityKind.agents),
    ];
    return [
      for (final row in rows)
        if (row['deletedAt'] == null)
          if (cardString(row['userId'] ?? row['id']) case final String id)
            (
              id: id,
              label: cardString(row['displayName'] ?? row['name']) ?? id,
            ),
    ];
  }

  Widget _formView(
    ActionCardForm cardForm, {
    bool inline = false,
    Object? buttonLabel,
    Key? key,
  }) {
    final workspace = w;
    final message = widget.message;
    final authority = workspaceAuthority(workspace);
    final before = metadata;
    final version = before['confirmationVersion'];
    final question = type == 'question:ask';
    final enabled =
        !widget.exportMode &&
        blocked == null &&
        before['state'] == 'prepared' &&
        !actionCardExpired(before);
    final draftKey = (authority, message.id, cardForm.id, version);
    final drafts = _formDrafts[workspace] ??= BoundedLruMap(64);
    final keepDraft = question || cardForm.paged;
    return ActionCardFormView(
      key: key,
      form: cardForm,
      entityName: _entityName,
      candidates: _candidates,
      enabled: enabled,
      question: question,
      inline: inline,
      buttonLabel: buttonLabel,
      draft: enabled && keepDraft ? drafts[draftKey] : null,
      onDraft: !keepDraft || !enabled
          ? null
          : (draft) {
              if (draft == null) {
                drafts.remove(draftKey);
              } else {
                drafts[draftKey] = draft;
              }
            },
      onSubmit: (values) async {
        final stored = workspace.messageDomain.ledger
            .messages(message.channelId)
            .where((row) => row['id'] == message.id)
            .firstOrNull;
        final latest = mounted
            ? metadata
            : stored == null
            ? before
            : cardObject(stored['actionMetadata']);
        if (!enabled ||
            workspaceAuthority(workspace) != authority ||
            latest['state'] != 'prepared' ||
            latest['confirmationVersion'] != version ||
            actionCardExpired(latest)) {
          throw const RaftUserError(
            'Not sent: the card changed. Answer again.',
          );
        }
        await _apply(workspace, message, 'execute', {
          'expectedState': 'prepared',
          if (version is int) 'expectedConfirmationVersion': version,
          'form': {'id': cardForm.id, 'values': values},
        }, authority);
        if (keepDraft) drafts.remove(draftKey);
      },
    );
  }

  ({ActionCardElement button, ActionCardForm form})? _inlineQuestion(
    ActionCardSpec card,
  ) {
    if (type != 'question:ask' ||
        metadata['state'] != 'prepared' ||
        actionCardExpired(metadata)) {
      return null;
    }
    for (final node in card.body.nodes.where((node) => node.type == 'Button')) {
      final press = node.press;
      final id = press.argument;
      if (press.command != ActionCardCommand.form || id == null) continue;
      final form = ActionCardForm.read(id, card.forms[id]);
      if (form != null &&
          form.inline &&
          form.fields.isNotEmpty &&
          form.fields.every(
            (field) => field.type == ActionCardFieldType.choice,
          )) {
        return (button: node, form: form);
      }
    }
    return null;
  }

  Future<void> _openSpecForm(ActionCardForm cardForm) async {
    await _openSpecDialog(
      (_) => _formView(cardForm),
      guardUnsaved: !(type == 'question:ask' || cardForm.paged),
    );
  }

  Future<void> _openSpecDialog(
    Widget Function(BuildContext) builder, {
    bool guardUnsaved = true,
    bool dismissible = true,
  }) async {
    if (busy ||
        blocked != null ||
        actionCardExpired(metadata) ||
        metadata['state'] != 'prepared') {
      showRaftToast(context, 'This action is no longer available.');
      return;
    }
    final authority = workspaceAuthority(w);
    openingAuthority = authority;
    openingVersion = metadata['confirmationVersion'];
    setState(() {
      busy = true;
      errorNotice.clear();
    });
    unawaited(event('action_card.open'));
    try {
      final submitted = await form(
        authority,
        builder,
        guardUnsaved: guardUnsaved,
        dismissible: dismissible,
      );
      if (submitted != true && mounted && current(authority)) {
        unawaited(event('action_card.dismiss'));
      }
    } finally {
      ownedDialog = null;
      openingAuthority = null;
      openingVersion = null;
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openFeedback() async {
    final workspace = w;
    final message = widget.message;
    final authority = workspaceAuthority(workspace);
    final version = metadata['confirmationVersion'];
    final submissionId = workspace.client.newRandomId();
    final draft = action;
    await _openSpecDialog(
      (_) => RaftFormDialog(
        title: 'Submit feedback',
        submitLabel: 'Submit',
        fields: [
          RaftFormField(
            'type',
            'Feedback type',
            initial: cardString(draft['feedbackType']) ?? 'idea',
            choices: const {'idea': 'Idea', 'problem': 'Problem'},
          ),
          RaftFormField(
            'message',
            'Feedback',
            initial: cardString(draft['message']) ?? '',
            required: true,
            multiline: true,
            validator: (text) => text.runes.length > 3000 ? 'Too long' : null,
          ),
        ],
        extra: Text(
          raftText(
            context,
            'It will be sent as your feedback to the Raft team. You can follow it in Settings.',
          ),
        ),
        onSubmit: (values) async {
          requireCurrent(authority);
          unawaited(event('action_card.execute_attempt'));
          try {
            final response = cardObject(
              await workspace.client.post(
                '/product-feedback',
                data: FormData.fromMap({
                  'type': values['type'],
                  'message': values['message'],
                  'metadata': jsonEncode({
                    'locale': Localizations.localeOf(context).toLanguageTag(),
                  }),
                  'submission_id': submissionId,
                  'may_contact': 'false',
                  'action_card_message_id': message.id,
                  if (version is int)
                    'expected_confirmation_version': '$version',
                }),
              ),
            );
            final result = cardObject(response['action_card']);
            if (result.isNotEmpty) {
              _acceptActionResponse(workspace, message, authority, {
                'messageId': result['message_id'],
                'metadata': result['metadata'],
              });
            }
          } catch (_) {
            if (mounted && current(authority)) {
              unawaited(event('action_card.execute_fail'));
            }
            rethrow;
          }
        },
      ),
      guardUnsaved: false,
      dismissible: false,
    );
  }

  RaftLocation? get _feedbackTicketLocation {
    final viewer = w.client.user?.id;
    final slug = w.server?.string('slug');
    final result = cardObject(metadata['result']);
    if (type != 'feedback:submit' ||
        metadata['state'] != 'executed' ||
        viewer == null ||
        viewer != metadata['executedByUserId'] ||
        slug == null ||
        slug.isEmpty ||
        slug != w.location.serverSlug ||
        actionCardReadOnlyInServer(metadata, w.server?.id) ||
        result['kind'] != 'product-feedback' ||
        (result['source'] ?? 'web') != 'web') {
      return null;
    }
    final ticket = cardString(result['ticketId']);
    return RaftLocation.at(
      serverSlug: slug,
      route: RaftRoute.settings,
      settingsPath: [
        'feedback',
        if (ticket != null && _feedbackTicketId.hasMatch(ticket)) ...[
          'ticket',
          ticket,
        ],
      ],
    );
  }

  Future<void> _openMigration() async {
    final agent = _migrationAgent;
    final agentId = cardString(agent?['id']);
    if (agent == null || agentId == null || blocked != null) {
      showRaftToast(context, 'This action is no longer available.');
      return;
    }
    final machineId = cardString(agent['machineId']);
    final directory = w.services.entityDirectory;
    final sourceMachine = machineId == null
        ? null
        : directory.computer(machineId);
    final source = sourceMachine?['isComputer'] == false ? null : machineId;
    final suggested = cardString(action['suggestedComputer']);
    final plan = w.server?.string('plan');
    final placesWithoutSource = agentPlacesWithoutSource(agent);
    if (!placesWithoutSource && plan == 'free') {
      return openWebBillingOrToast(
        context,
        w,
        gate: WebBillingGate.agentMigration,
      );
    }
    final authority = workspaceAuthority(w);
    final version = metadata['confirmationVersion'];
    final machines = w.services.entityDirectory.rows(
      WorkspaceEntityKind.computers,
    );
    await _openSpecDialog(
      (_) => AgentMigrationStartDialog(
        targets: [
          for (final machine in machines)
            if (machine['id'] != source && machine['isComputer'] == true)
              machine,
        ],
        controller: w,
        initialTarget: suggested,
        sourceMachineId: source,
        placesWithoutSource: placesWithoutSource,
        sourceName: source == null ? null : cardString(sourceMachine?['name']),
        openComputers: (_) => unawaited(_openCardInBrowser()),
        start: (target) async {
          requireCurrent(authority);
          unawaited(event('action_card.execute_attempt'));
          try {
            await w.command(
              'POST',
              '/agents/$agentId/migrate',
              data: {'targetComputer': target},
            );
            if (current(authority)) {
              await mark(
                {
                  'kind': 'agent-migration',
                  'agentId': agentId,
                  'targetMachineId': target,
                },
                authority,
                version,
              );
            }
          } catch (_) {
            if (current(authority)) {
              unawaited(event('action_card.execute_fail'));
            }
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> _openInstall() async {
    final authority = workspaceAuthority(w);
    final version = metadata['confirmationVersion'];
    final snapshot = action;
    final author =
        cardString(snapshot['agentName']) ?? raftText(context, 'Agent');
    await _openSpecDialog(
      (_) => ActionCardInstallDialog(
        action: snapshot,
        agent: author,
        readMarketplace: (_) async {
          final client = w.client;
          final server = w.server?.id;
          final marketplace = client.get('/integrations/marketplace');
          final consent = server == null
              ? Future.value(false)
              : appPromptTextConsent(client, server);
          final (records, promptConsent) = await (marketplace, consent).wait;
          return (
            apps: cardList(records).map(cardObject).toList(),
            promptConsent: promptConsent,
          );
        },
        execute: (context) {
          requireCurrent(authority);
          return withSecondFactorStepUp(context, w.client, () {
            requireCurrent(authority);
            return apply('execute', {
              'expectedState': 'prepared',
              if (version is int) 'expectedConfirmationVersion': version,
            }, authority);
          }, reason: StepUpReason.actionCard);
        },
      ),
      guardUnsaved: false,
      dismissible: false,
    );
  }

  Widget? _mcpPicker() {
    if (type != 'integration:connect_mcp' ||
        blocked != null ||
        widget.exportMode ||
        actionCardExpired(metadata)) {
      return null;
    }
    final app = cardString(action['mcpServerId']);
    final agent = cardString(action['agentId']);
    if (app == null || agent == null || metadata['state'] != 'prepared') {
      return null;
    }
    final authority = workspaceAuthority(w);
    final version = metadata['confirmationVersion'];
    void verify() {
      if (!current(authority) ||
          actionCardExpired(metadata) ||
          metadata['state'] != 'prepared' ||
          metadata['confirmationVersion'] != version) {
        throw const RaftUserError('This action is no longer available.');
      }
    }

    return ActionCardMcpPicker(
      key: ValueKey((authority, widget.message.id, version, app, agent)),
      api: RaftActionCardMcpApi(w.client, app, agent),
      agent: _entityName({
        'kind': 'agent',
        'id': agent,
        'fallback': raftText(context, 'Agent'),
      }),
      verify: verify,
      onOpenWeb: () => unawaited(_openCardInBrowser()),
      onGranted: () async {
        verify();
        unawaited(event('action_card.execute_attempt'));
        await apply('mark-executed', {
          'result': {
            'kind': 'mcp-connection',
            'mcpServerId': app,
            'agentId': agent,
          },
          if (version is int) 'expectedConfirmationVersion': version,
        }, authority);
      },
    );
  }

  Future<void> _pressSpec(
    ActionCardSpec card,
    ActionCardPress press,
    ActionCardElement element,
  ) async {
    switch (press.command) {
      case ActionCardCommand.browser:
        return _openCardInBrowser();
      case ActionCardCommand.url:
        return _openCardInBrowser(publicCardUrl(press.argument ?? ''));
      case ActionCardCommand.target:
        return _navigateCard(press.target ?? const {});
      case ActionCardCommand.intent:
        if (const {'add_seats', 'upgrade_dialog'}.contains(press.argument)) {
          if (blocked != null) {
            showRaftToast(
              context,
              blocked ?? 'This action is no longer available.',
            );
            return;
          }
          return openWebBillingOrToast(context, w, gate: press.gate);
        }
        if (press.argument == 'feedback_form' && type == 'feedback:submit') {
          return _openFeedback();
        }
        if (press.argument == 'feedback_ticket' && type == 'feedback:submit') {
          final location = _feedbackTicketLocation;
          if (location == null) {
            showRaftToast(context, 'This action is no longer available.');
            return;
          }
          w.navigation.navigate(location);
          w.notifyListeners();
          return;
        }
        if (press.argument == 'migrate_agent' && type == 'agent:migrate') {
          return _openMigration();
        }
        if (press.argument == 'send_create_agent_card' && type == 'seats:add') {
          return _sendCreateAgentCard();
        }
        if (!const {
          ('create_channel', 'channel:create'),
          ('create_agent', 'agent:create'),
          ('add_members', 'channel:add_member'),
        }.contains((press.argument, type))) {
          return _openCardInBrowser();
        }
        return confirm();
      case ActionCardCommand.form:
        if (metadata['state'] == 'reconfirm_required') return confirm();
        final id = press.argument;
        final form = id == null
            ? null
            : ActionCardForm.read(id, card.forms[id]);
        return form == null ? _openCardInBrowser() : _openSpecForm(form);
      case ActionCardCommand.execute:
        if (metadata['state'] == 'reconfirm_required') return confirm();
        if (type == 'integration:install_marketplace_app') {
          return _openInstall();
        }
        if (actionCardExpired(metadata) ||
            blocked != null ||
            busy ||
            metadata['state'] != 'prepared') {
          showRaftToast(context, 'This action is no longer available.');
          return;
        }
        final id = press.argument;
        final confirmation = id == null ? null : card.confirmation(id);
        if (id != null && confirmation == null) return _openCardInBrowser();
        final authority = workspaceAuthority(w);
        final version = metadata['confirmationVersion'];
        openingAuthority = authority;
        openingVersion = version;
        setState(() {
          busy = true;
          errorNotice.clear();
        });
        Future<void> execute() async {
          requireCurrent(authority);
          final data = {
            'expectedState': 'prepared',
            if (version is int) 'expectedConfirmationVersion': version,
          };
          if (_inlineActions.contains(type)) {
            await withSecondFactorStepUp(
              context,
              w.client,
              () => apply('execute', data, authority),
              reason: StepUpReason.actionCard,
            );
          } else {
            await apply('execute', data, authority);
          }
        }

        try {
          if (confirmation == null) {
            await execute();
          } else {
            unawaited(event('action_card.open'));
            await modal(
              authority,
              (context) => RaftConfirmDialog(
                title: actionCardCopy(
                  context,
                  confirmation.data['title'],
                  _entityName,
                ),
                confirmLabel: actionCardCopy(
                  context,
                  confirmation.data['confirmLabel'],
                  _entityName,
                ),
                confirmVariant: element.props['emphasis'] == 'destructive'
                    ? RaftButtonRecipeVariant.danger
                    : RaftButtonRecipeVariant.primary,
                plainMessage: true,
                content: ActionCardSpecTree(
                  root: confirmation.body,
                  entityName: _entityName,
                  hasEntity: _hasCardEntity,
                ),
                onConfirm: execute,
              ),
            );
          }
        } catch (failure) {
          if (current(authority) && !isSecondFactorStepUpCancelled(failure)) {
            setState(
              () => raiseError(
                userErrorText(
                  failure,
                  fallback: 'Failed to execute action',
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
  }

  Future<void> _sendCreateAgentCard() async {
    final person = cardString(metadata['requesterUserId']);
    final outcome = cardObject(metadata['seatOutcome']);
    final name = cardString(outcome['name']);
    if (person == null ||
        name == null ||
        metadata['state'] != 'executed' ||
        actionCardReadOnlyInServer(metadata, w.server?.id) ||
        w.server?.string('role') != 'owner') {
      showRaftToast(context, 'This action is no longer available.');
      return;
    }
    final authority = workspaceAuthority(w);
    final workspace = w;
    final id = widget.message.id;
    final requester = _memberName(person);
    final sent = await RaftConfirmDialog.show(
      context,
      RaftConfirmDialog(
        title: raftFormat(
          context,
          'Send {requester} a card to create {name}?',
          {'requester': requester, 'name': name},
        ),
        message: raftFormat(
          context,
          'It goes to your DM with {requester}. They create {name} from it, as with any agent card.',
          {'requester': requester, 'name': name},
        ),
        confirmLabel: 'Send',
        confirmVariant: RaftButtonRecipeVariant.outline,
        onConfirm: () async {
          if (!mounted || workspaceAuthority(workspace) != authority) {
            throw const RaftUserError('This action is no longer available.');
          }
          await workspace.client.post(
            '/actions/$id/send-create-agent-card',
            data: {},
          );
        },
      ),
    );
    if (sent == true && mounted) {
      setState(() => _sentCreateCard = true);
    }
  }

  bool _sentCreateCard = false;

  Widget? _specTrailing(BuildContext context) {
    if (metadata['state'] != 'executed') return _mcpPicker();
    final outcome = cardObject(metadata['seatOutcome']);
    if (!_sentCreateCard &&
        type == 'seats:add' &&
        blocked == null &&
        outcome['kind'] == 'ready' &&
        outcome['purpose'] == 'agent:create') {
      return Align(
        alignment: Alignment.centerRight,
        child: RaftButton(
          label: 'Send',
          uiVariant: RaftButtonVariant.outline,
          uiSize: RaftButtonSize.md,
          onPressed: widget.exportMode ? null : _sendCreateAgentCard,
        ),
      );
    }
    return _resultAction(context);
  }

  /// ResultLink of an installed Marketplace App that needs setup: the
  /// "Continue setup" button, when the setup page is a safe web URL.
  Widget? _resultAction(BuildContext context) {
    final result = _map(metadata['result']);
    final url = result['setupUrl'];
    if (result['kind'] != 'marketplace-app-installation' ||
        url is! String ||
        !isSafeAppSetupUrl(url)) {
      return null;
    }
    return RaftRecipeButton(
      key: const ValueKey('action-card-continue-setup'),
      label: 'Continue setup',
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      onPressed: () async {
        try {
          await managementLaunch(url);
        } catch (_) {
          if (context.mounted) {
            showRaftToast(context, 'Could not open this address.');
          }
        }
      },
    );
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
      'marketplace-app-installation' => f('{client} installed on this server', {
        'client': result['clientName'],
      }),
      'integration-app-registration' => f(
        result['mode'] == 'register'
            ? '{client} created ({clientKey})'
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
      completedAction: _resultAction(context),
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
    final card = spec;
    if (card != null) {
      final question = _inlineQuestion(card);
      final plan = w.server?.string('plan');
      return ActionCardSpecView(
        key: ValueKey('action-card-spec-${widget.message.id}'),
        spec: card,
        metadata: metadata,
        entityName: _entityName,
        hasEntity: _hasCardEntity,
        formatTimestamp: _timeFormatter(context).messageTime,
        resolvePress: (element) => _resolvePress(card, element),
        onPress: widget.exportMode
            ? null
            : (press, element) => unawaited(_pressSpec(card, press, element)),
        onEntity: widget.exportMode
            ? null
            : (entity) => unawaited(_navigateCard(entity)),
        blocked: blocked,
        hiddenButton: question?.button.id,
        inlineQuestionFields: {
          if (question != null)
            for (final field in question.form.fields) 'q_${field.name}',
        },
        canOpenFeedbackTicket: _feedbackTicketLocation != null,
        inlineForm: question == null
            ? null
            : _formView(
                question.form,
                key: ValueKey((
                  question.form.id,
                  metadata['confirmationVersion'],
                )),
                inline: true,
                buttonLabel: question.button.props['label'],
              ),
        busy: busy,
        error: error,
        trailing: _specTrailing(context),
        completedOnCurrentPlan:
            type == 'plan:upgrade' &&
                plan != null &&
                plan.isNotEmpty &&
                plan != 'free' &&
                !actionCardReadOnlyInServer(metadata, w.server?.id)
            ? raftText(
                context,
                plan == 'pro'
                    ? 'Upgraded to Pro'
                    : 'No longer limited by the Free plan',
              )
            : null,
      );
    }
    if (_known.contains(type) &&
        rawSpec == null &&
        !actionCardExpired(metadata)) {
      return _knownCard(context);
    }
    final presentation = _map(metadata['presentation']);
    final labels = {
      'channel:create': 'Create Channel',
      'agent:create': 'Create Agent',
      'channel:add_member': 'Add Members',
      'integration:approve_agent_login': 'Approve Agent Login',
      'integration:install_marketplace_app': 'Install App',
      'integration:register_app': 'Register App',
      'integration:update_app_registration': 'Update App',
      'integration:recover_app_owner': 'Recover App Owner',
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
      _ => raftText(context, labels[type] ?? 'Action card'),
    };
    final state = '${metadata['state']}';
    final isExecuted = state == 'executed';
    final isExpired = actionCardExpired(metadata);
    final isFrozen = state == 'frozen';
    final isViewOnly = rawSpec != null || isExpired || !_known.contains(type);
    final expiresAt = DateTime.tryParse(
      '${metadata['expiresAt'] ?? action['expiresAt']}',
    );
    final expiredLine = expiresAt == null
        ? null
        : raftFormat(
            context,
            'Expired on {date}. Ask the agent to send a new request.',
            {'date': _timeFormatter(context).messageTime(expiresAt)},
          );
    final unknownDescription = isExecuted
        ? null
        : isExpired
        ? expiredLine
        : isViewOnly
        ? raftText(
            context,
            _known.contains(type)
                ? 'This kind of request is no longer available. Ask the agent to send a new request.'
                : 'Reload the page to see this request.',
          )
        : null;
    final unknownStatus = isExecuted
        ? raftText(context, 'Done')
        : isExpired
        ? raftText(context, 'Expired')
        : isFrozen
        ? raftText(context, 'Frozen')
        : isViewOnly
        ? raftText(context, 'View only')
        : null;
    return RaftActionCard(
      title: presentation['title'] is String
          ? presentation['title']
          : fallbackTitle,
      state: state,
      details: details,
      hint: action['draftHint'],
      targetServer: metadata['targetServerName'],
      completedBy: metadata['executedByUserName'],
      confirmLabel: labels[type] ?? 'Confirm Action',
      blockedReason: rawSpec != null || isExpired
          ? raftText(context, 'View only')
          : blocked,
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
      icon: isViewOnly ? RaftGlyph.circleHelp : null,
      headerDescription: unknownDescription,
      statusLabel: unknownStatus,
      statusVariant: isExecuted
          ? RaftStatusVariant.success
          : RaftStatusVariant.muted,
      warning: cardString(presentation['warning']),
      collapsible: isViewOnly,
      defaultExpanded: !isViewOnly,
      hideConfirmAction: isViewOnly,
    );
  }

  (String, String?, SourceTimeFormat?, SourceTimeFormat?, String)?
  _timeFormatterKey;
  SourceTimeFormatter? _cachedTimeFormatter;

  SourceTimeFormatter _timeFormatter(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final preferredTimezone = w.client.user?.string('preferredTimezone');
    final preferredTimeFormat = sourceTimeFormatPreference(
      w.client.user?.string('preferredTimeFormat'),
    );
    final systemTimeFormat = MediaQuery.alwaysUse24HourFormatOf(context)
        ? SourceTimeFormat.twentyFourHour
        : null;
    final yesterdayLabel = raftText(context, 'Yesterday');
    final key = (
      locale,
      preferredTimezone,
      preferredTimeFormat,
      systemTimeFormat,
      yesterdayLabel,
    );
    if (_cachedTimeFormatter != null && _timeFormatterKey == key) {
      return _cachedTimeFormatter!;
    }
    _timeFormatterKey = key;
    return _cachedTimeFormatter = SourceTimeFormatter(
      locale: locale,
      preferredTimezone: preferredTimezone,
      preferredTimeFormat: preferredTimeFormat,
      systemTimeFormat: systemTimeFormat,
      yesterdayLabel: yesterdayLabel,
    );
  }
}
