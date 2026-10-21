// Create joint (shared) channel dialog: the Web CreateJointChannelDialog
// (packages/web/src/components/channel/CreateJointChannelDialog.tsx) over the
// raft_ui RaftCreateJointChannelDialogView. The host (JointChannelsView) owns
// the guarded mutations; this dialog owns the form state and Web's error
// mapping (archived-name collision, free-server and server limits, billing gate).
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/cause_notice.dart';
import '../data/user_error.dart';

import 'channel_form_fields.dart';
import 'create_channel_dialog.dart'
    show ChannelMemberCandidate, channelNameError;
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart' show WorkspaceEntityKind;
import 'joint_channel_views.dart' show jointPeople;
import 'joint_invite_errors.dart';
import 'management_support.dart';

/// `MAX_JOINT_CHANNEL_SERVERS` of @botiverse/raft-shared.
const maxJointChannelServers = 30;

class CreateJointChannelDialog extends StatefulWidget {
  const CreateJointChannelDialog({
    super.key,
    required this.agents,
    required this.users,
    required this.onCreate,
    required this.onUnarchive,
    this.freePlan = false,
    this.origin,
    this.onViewBilling,
    this.currentServerSlug,
  });
  final List<Map<String, dynamic>> agents, users;

  /// The open server's slug: a joint invite that names it is the server being
  /// invited to its own channel (`joint_target_server_invalid`).
  final String? currentServerSlug;

  /// POST /channels with the Web payload; returns the created channel.
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
  onCreate;

  /// POST /channels/:id/unarchive for the archived-name collision.
  final Future<Map<String, dynamic>> Function(String channelId) onUnarchive;
  final bool freePlan;
  final String? origin;
  final VoidCallback? onViewBilling;

  /// The sidebar's Joint channels "+" and "Create Joint Channel" menu items
  /// (Web Sidebar `openCreateJointChannelDialog`): the dialog opens in place
  /// over the current page, like Create Channel. Mutations stay bound to the
  /// server and the federateChannels capability that opened it.
  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    Future<void> Function(RaftChannel channel)? onCreated,
  }) async {
    final w = controller;
    final serverId = w.server?.id;
    if (serverId == null || !w.can('federateChannels')) return;
    bool current() =>
        context.mounted &&
        w.server?.id == serverId &&
        w.can('federateChannels');
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
            w.client.get('/servers/$serverId/members'),
          ]);
    if (!current()) return;
    final agents = managementRows(values[0])
        .where((a) => a['deletedAt'] == null)
        .toList();
    final users = managementRows(values[1])
        .where((u) => (u['userId'] ?? u['id']) != w.client.user?.id)
        .toList();
    Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic>? data,
    ) async {
      if (!current()) {
        throw StateError('Workspace access changed. Reopen this form.');
      }
      return managementMap(await w.client.post(path, data: data));
    }

    if (!context.mounted) return;
    final created = await showRaftForm<Map<String, dynamic>>(
      context,
      builder: (_) => CreateJointChannelDialog(
        agents: agents,
        users: users,
        freePlan: (w.server?.string('plan') ?? 'free') == 'free',
        origin: w.client.origin,
        currentServerSlug: w.server?.string('slug'),
        onCreate: (payload) => post('/channels', payload),
        onUnarchive: (id) => post('/channels/$id/unarchive', null),
        onViewBilling: () => w.setSection('billing'),
      ),
    );
    if (!current() || created == null || created['id'] == null) return;
    await w.refreshChannels();
    await onCreated?.call(RaftChannel(created));
  }

  @override
  State<CreateJointChannelDialog> createState() =>
      _CreateJointChannelDialogState();
}

class _CreateJointChannelDialogState extends State<CreateJointChannelDialog> {
  final name = TextEditingController(), description = TextEditingController();
  final search = TextEditingController();
  final drafts = [RaftJointInviteDraft('invite-1')];
  int nextInvite = 2;
  final agentIds = <String>{}, humanIds = <String>{};
  // ignore: raft_lints/avoid_imperative_notice_state -- Cleared when the next submit starts or the invite list changes; the dialog state is dropped when it closes.
  String? error;

  /// The name rule that rejected the last submit: it holds only while the
  /// name still breaks it.
  final nameInvalid = CauseNotice();
  // ignore: raft_lints/avoid_imperative_notice_state -- billingError is cleared with the error text it decorates (submit start or an invite change).
  bool billingError = false, submitting = false;
  Map<String, dynamic>? archivedCollision;

  late final List<ChannelMemberCandidate> candidates = [
    for (final a in widget.agents)
      ChannelMemberCandidate(
        kind: 'agent',
        id: '${a['id']}',
        name: '${a['name'] ?? ''}',
        displayName: a['displayName'] as String?,
        description: a['description'] as String?,
        avatarUrl: a['avatarUrl'] as String?,
      ),
    for (final u in widget.users)
      ChannelMemberCandidate(
        kind: 'human',
        id: '${u['userId'] ?? u['id']}',
        name: '${u['name'] ?? u['userName'] ?? ''}',
        displayName: u['displayName'] as String?,
        description: u['description'] as String?,
        avatarUrl: u['avatarUrl'] as String?,
      ),
  ];

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    // The name rule is re-read on every edit, so its message ends with it.
    name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    search.dispose();
    for (final draft in drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  /// A submit error describes the invite list it was submitted with; once the
  /// list changes it is stale.
  void clearSubmitError() {
    if (error != null || billingError) {
      setState(() {
        error = null;
        billingError = false;
      });
    }
  }

  void addServer() {
    if (drafts.length >= maxJointChannelServers - 1) return;
    setState(() {
      error = null;
      billingError = false;
      drafts.add(RaftJointInviteDraft('invite-${nextInvite++}'));
    });
  }

  void removeServer(String id) {
    if (drafts.length <= 1) return;
    setState(() {
      error = null;
      billingError = false;
      drafts.removeWhere((d) {
        final match = d.id == id;
        if (match) d.dispose();
        return match;
      });
    });
  }

  Future<void> submit() async {
    if (submitting) return;
    final trimmed = name.text.trim();
    setState(() {
      error = null;
      nameInvalid.clear();
      billingError = false;
      archivedCollision = null;
    });
    final nameError = channelNameError(context, trimmed);
    if (nameError != null) {
      setState(
        () => nameInvalid.raise(
          nameError,
          whileTrue: () => channelNameError(context, name.text.trim()) != null,
        ),
      );
      return;
    }
    final invites = [
      for (final draft in drafts)
        {
          'targetServerSlug': draft.slug.text.trim(),
          'invitedPeople': jointPeople(draft.people.text),
        },
    ];
    final incomplete = invites.firstWhere(
      (i) =>
          (i['targetServerSlug'] as String).isEmpty ||
          (i['invitedPeople'] as List).isEmpty,
      orElse: () => const {},
    );
    if (incomplete.isNotEmpty) {
      setState(
        () => error = raftText(
          context,
          incomplete['targetServerSlug'] == ''
              ? 'Invite server slug is required'
              : 'At least one invited person is required',
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final channel = await widget.onCreate({
        'name': trimmed,
        if (description.text.trim().isNotEmpty)
          'description': description.text.trim(),
        'visibility': 'joint',
        'agentIds': [...agentIds],
        'userIds': [...humanIds],
        'jointInvites': invites,
      });
      if (mounted) Navigator.of(context).pop(channel);
    } catch (e) {
      if (!mounted) return;
      final Map<String, dynamic> details = e is RaftApiException
          ? e.details
          : const {};
      setState(() {
        submitting = false;
        if (details['code'] == 'archived_name_collision' &&
            details['archivedChannelId'] != null &&
            details['archivedChannelName'] != null &&
            details['archivedChannelType'] == 'joint') {
          archivedCollision = Map<String, dynamic>.from(details);
        } else if (details['code'] == 'joint_free_server_limit') {
          error = raftText(
            context,
            'This Joint Channel already has 2 free servers. Upgrade either side to Pro, or have a free server leave, to continue (30 servers max).',
          );
          billingError = true;
        } else if (details['code'] == 'joint_server_limit') {
          error = raftFormat(
            context,
            'Joint Channels are limited to {max} servers. To request a higher limit, send feedback from Settings.',
            {'max': maxJointChannelServers},
          );
        } else if (describeJointInviteError(
              details,
              widget.currentServerSlug,
              (source, values) => raftFormat(context, source, values),
            )
            case final inviteError?) {
          error = inviteError;
        } else {
          final body = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to create joint channel',
              where: 'create joint channel',
            ),
          );
          error = body;
          billingError = body.contains('requires the Pro plan');
        }
      });
    }
  }

  Future<void> unarchiveCollision() async {
    final held = archivedCollision;
    if (held == null || submitting) return;
    setState(() => submitting = true);
    try {
      final channel = await widget.onUnarchive('${held['archivedChannelId']}');
      if (mounted) Navigator.of(context).pop(channel);
    } catch (e) {
      if (mounted) {
        setState(() {
          submitting = false;
          error = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to unarchive channel',
              where: 'create joint channel unarchive',
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    RaftPickerItem item(ChannelMemberCandidate c) => RaftPickerItem(
      key: '${c.kind}:${c.id}',
      label: c.label,
      description: c.description,
      avatar: ChannelCandidateAvatar(
        candidate: c,
        avatarContext: RaftMountedAvatarContext.sidebarList,
        humanPlaceholder: true,
        origin: widget.origin,
      ),
    );
    return RaftCreateJointChannelDialogView(
      name: name,
      description: description,
      search: search,
      drafts: drafts,
      maxServers: maxJointChannelServers,
      freeAllowance: widget.freePlan,
      onAddServer: addServer,
      onRemoveServer: removeServer,
      onInviteChanged: clearSubmitError,
      agents: [
        for (final c in candidates)
          if (c.kind == 'agent' && c.matches(search.text)) item(c),
      ],
      humans: [
        for (final c in candidates)
          if (c.kind == 'human' && c.matches(search.text)) item(c),
      ],
      hasCandidates: candidates.isNotEmpty,
      isSelected: (key) => key.startsWith('agent:')
          ? agentIds.contains(key.substring(6))
          : humanIds.contains(key.substring(6)),
      onToggle: (key) => setState(() {
        final set = key.startsWith('agent:') ? agentIds : humanIds;
        final id = key.substring(key.indexOf(':') + 1);
        if (!set.remove(id)) set.add(id);
      }),
      onClose: () => Navigator.of(context).maybePop(),
      onSubmit: submit,
      error: error ?? nameInvalid.message,
      onViewBilling: billingError && widget.onViewBilling != null
          ? () {
              Navigator.of(context).pop();
              widget.onViewBilling!();
            }
          : null,
      notice: archivedCollision == null
          ? null
          : RaftArchivedNameBanner(
              name: '${archivedCollision!['archivedChannelName']}',
              canUnarchive:
                  archivedCollision!['canUnarchiveArchivedChannel'] == true,
              busy: submitting,
              showHint: false,
              onUnarchive: unarchiveCollision,
              onChangeName: () => setState(() {
                archivedCollision = null;
                name.clear();
              }),
            ),
      submitting: submitting,
    );
  }
}
