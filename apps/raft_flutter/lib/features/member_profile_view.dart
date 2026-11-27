import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart';
import 'agent_detail_view.dart';
import 'agent_runtime_labels.dart'
    show RuntimeDeprecatedHereState, runtimeLabelWithStatus;
import 'channel_member_servers.dart' show withPrimedServers;
import 'member_profile_rules.dart';
import 'member_profile_role_change.dart';
import 'member_removal_impact.dart';
import 'members_page_remove.dart';
import 'human_avatar_edit_menu.dart';
import 'member_profile_self_edit.dart';
import 'feedback_attachment_preview.dart' show showFeedbackImage;
import 'sender_avatar_projection.dart';

/// Current-authority HumanRoute/ProfilePanel fallback contract. Entity payloads
/// remain in this loader's memory and are cleared on role/principal/workspace
/// changes; the shell stores only the selected user id.
class MemberProfileView extends StatefulWidget {
  const MemberProfileView({
    super.key,
    required this.controller,
    required this.userId,
    this.channelId,
    required this.onClose,
    this.onMessage,
    this.onBack,
    this.onOpenAgent,
    this.showClose = true,
  });
  final WorkspaceController controller;

  /// Tapping a created agent opens its profile (Web `CreatedAgentRow`
  /// `nav.toAgent`). Without a host that presents profiles itself it opens in
  /// the workspace's profile pane.
  final void Function(String agentId)? onOpenAgent;

  /// Web HumanRoute renders no close control (only the overlay presentation
  /// passes `onClose`); the desktop detail pane hides it.
  final bool showClose;
  final String userId;

  /// The channel whose authorized joint membership names this person's servers.
  final String? channelId;
  final VoidCallback onClose;

  /// Mobile route back (PanelHeader `onMobileBack`); without it the desktop
  /// pane shows a close action instead.
  final VoidCallback? onBack;
  final Future<void> Function()? onMessage;
  @override
  State<MemberProfileView> createState() => _MemberProfileViewState();
}

class _MemberProfileViewState extends ManagementState<MemberProfileView>
    with RuntimeDeprecatedHereState<MemberProfileView> {
  @override
  WorkspaceController get w => widget.controller;
  @override
  WorkspaceController get runtimeCatalogWorkspace => w;
  Map<String, dynamic> profile = {};

  /// The profile read (description, created agents, join date) was accepted
  /// or restored. Until then only the directory's membership row is shown, so
  /// the detail sections do not appear empty and then fill in.
  bool detailLoaded = false;

  /// The detail read settled (accepted, restored, or failed): a failed read
  /// shows the empty sections it always showed rather than a shorter panel.
  bool get detailSettled => detailLoaded || !loading;
  bool get channelRevoked =>
      w.sessionScope.revokedChannels.contains(widget.channelId);
  @override
  String get authority =>
      '${super.authority}|${identityHashCode(w)}|${w.client.origin}|${widget.userId}|${widget.channelId}|$channelRevoked';
  // A channel-scoped response is authorized anew on every open.
  @override
  String? get snapshotKey =>
      widget.channelId == null ? 'member-profile:${widget.userId}' : null;
  @override
  bool deniesLoad(Object failure) =>
      super.deniesLoad(failure) ||
      (widget.channelId != null &&
          failure is RaftApiException &&
          failure.status == 404);
  @override
  Map<String, Object?> captureSnapshot() => {'profile': profile};
  @override
  bool restoreSnapshot(Map<String, Object?> fields) {
    detailLoaded = true;
    // Accepted live membership still wins over the last detail projection.
    profile = {
      ...fields['profile'] as Map<String, dynamic>,
      ...?w.services.entityDirectory.member(widget.userId),
    };
    return true;
  }

  @override
  void initState() {
    super.initState();
    profile = w.services.entityDirectory.member(widget.userId) ?? {};
    w.services.entityDirectory.addListener(directoryChanged);
    startManagement();
  }

  @override
  void didUpdateWidget(MemberProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      ownRoleImpact.sync(null, null);
      ownRoleImpact = _makeRoleImpactRead();
      oldWidget.controller.services.entityDirectory.removeListener(
        directoryChanged,
      );
      w.services.entityDirectory.addListener(directoryChanged);
      rebindManagementController();
      profile = {
        ...profile,
        ...?w.services.entityDirectory.member(widget.userId),
      };
    } else if (oldWidget.userId != widget.userId ||
        oldWidget.channelId != widget.channelId) {
      refreshAuthority();
      profile = {
        ...profile,
        ...?w.services.entityDirectory.member(widget.userId),
      };
    }
  }

  void directoryChanged() {
    if (!mounted) return;
    final failure = w.services.entityDirectory
        .state(WorkspaceEntityKind.members)
        .error;
    if (failure is RaftApiException && [401, 403].contains(failure.status)) {
      setState(() {
        profile = {};
        error = userErrorText(failure, where: 'member profile');
        loading = false;
      });
      return;
    }
    final live = w.services.entityDirectory.member(widget.userId);
    if (live != null) {
      setState(() => profile = {...profile, ...live});
      saveSnapshot();
    }
  }

  @override
  void dispose() {
    ownRoleImpact.sync(null, null);
    roleImpactChanges.dispose();
    w.services.entityDirectory.removeListener(directoryChanged);
    super.dispose();
  }

  @override
  void clearData() {
    profile = {};
    detailLoaded = false;
    // The role editor and its error belong to the member they were opened for.
    roleError = null;
    editingRole = roleSaving = false;
    ownRoleImpact.sync(null, null);
    avatarSaving = false;
    avatarError = null;
  }

  Future<Map<String, dynamic>> _requestProfile(String server, String id) async {
    final channelId = widget.channelId;
    final value = await w.query(
      '/servers/$server/members/$id/profile',
      query: channelId == null ? null : {'channelId': channelId},
    );
    if (value is! Map || value['name'] is! String) {
      throw const FormatException('Invalid member profile response.');
    }
    return Map<String, dynamic>.from(value);
  }

  @override
  Future<void> loadData(int request, int generation) async {
    // ProfilePanel.tsx:151-156 fetches without a capability gate: the server
    // serves a guest a channel-scoped profile (servers.ts:2297-2304).
    if (w.server == null) {
      clearData();
      return;
    }
    if (channelRevoked) {
      throw const RaftApiException('Channel unavailable.', status: 404);
    }
    final server = w.server!.id, id = widget.userId;
    final channelId = widget.channelId;
    final value = await _requestProfile(server, id);
    if (accepts(generation, request)) {
      final failure = w.services.entityDirectory
          .state(WorkspaceEntityKind.members)
          .error;
      if (failure is RaftApiException && [401, 403].contains(failure.status)) {
        throw failure;
      }
      // resolveHumanProfile.ts:4–17: accepted live membership wins over a
      // fallback detail projection; preserve detail-only fields.
      final merged = {...value, ...?w.services.entityDirectory.member(id)};
      profile = channelId == null
          ? withPrimedServers(w, merged, server, id)
          : {...merged, 'servers': value['servers']};
      detailLoaded = true;
    }
  }

  /// HumanDetailPanel `ConfirmDialog` for removing the member.
  Future<void> remove() async {
    final server = w.server!.id, id = widget.userId;
    final source = authority;
    final name = humanDisplayName(profile);
    final removed = await scopedDialog<bool>(
      (_) => RemoveMemberDialog(
        workspace: w,
        serverId: server,
        memberId: id,
        name: name,
        onConfirm: () async {
          if (!mounted || source != authority) {
            throw const RaftUserError('This action is no longer available.');
          }
          await w.command('DELETE', '/servers/$server/members/$id');
          if (mounted && source == authority) {
            unawaited(
              w.entityDirectory.refresh(
                WorkspaceEntityKind.members,
                force: true,
              ),
            );
          }
        },
      ),
    );
    if (removed == true && mounted && source == authority) {
      widget.onBack != null ? widget.onBack!() : widget.onClose();
    }
  }

  Future<void> promote() async {
    final server = w.server!, id = widget.userId, source = authority;
    final name = humanDisplayName(profile);
    await scopedDialog<bool>(
      (dialogContext) => RaftConfirmDialog(
        surfaceKey: const ValueKey('human-promote-guest-dialog'),
        confirmKey: const ValueKey('human-promote-guest-confirm'),
        title: raftFormat(dialogContext, 'Make {name} a member of {server}?', {
          'name': name,
          'server': server.string('name'),
        }),
        message: raftFormat(
          dialogContext,
          "They'll get access to {server} like other members and take one seat.",
          {'server': server.string('name')},
        ),
        confirmLabel: raftText(dialogContext, 'Make member'),
        loadingLabel: raftText(dialogContext, 'Promoting…'),
        confirmVariant: RaftButtonRecipeVariant.accent,
        onConfirm: () async {
          if (!mounted || source != authority || profile['role'] != 'guest') {
            throw const RaftUserError('This action is no longer available.');
          }
          await w.command(
            'PATCH',
            '/servers/${server.id}/members/$id',
            data: {'role': 'member'},
          );
          if (!mounted || source != authority) return;
          await w.entityDirectory.refresh(
            WorkspaceEntityKind.members,
            force: true,
          );
          if (mounted && source == authority) await reload();
        },
      ),
    );
  }

  bool avatarSaving = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when a new upload starts and when the viewed member or server/account changes (clearData); a late result for another member is ignored.
  String? avatarError;

  /// Your own picture (HumanDetailPanel `handleUploadAvatar`).
  Future<void> uploadAvatar() async {
    if (avatarSaving) return;
    final source = authority;
    setState(() {
      avatarSaving = true;
      avatarError = null;
    });
    final failure = await uploadOwnAvatar(w.client);
    if (!mounted || source != authority) return;
    setState(() {
      avatarSaving = false;
      avatarError = failure;
    });
  }

  bool _readingProfileForEdit = false;

  Future<Map<String, dynamic>?> _readProfileForEdit() async {
    final server = w.server?.id, id = widget.userId, source = authority;
    if (server == null || channelRevoked || _readingProfileForEdit) return null;
    final channelId = widget.channelId;
    bool accepts() =>
        source == authority &&
        id == widget.userId &&
        channelId == widget.channelId &&
        !channelRevoked;
    _readingProfileForEdit = true;
    try {
      final value = await RaftClient.runFresh(
        () => _requestProfile(server, id),
      );
      return mounted && accepts() ? value : null;
    } catch (failure) {
      if (mounted && accepts()) {
        showRaftToast(context, userErrorText(failure, where: 'member profile'));
      }
      return null;
    } finally {
      _readingProfileForEdit = false;
    }
  }

  /// Your own description (HumanDetailPanel inline editor, as a form).
  Future<void> editDescription() async {
    final fresh = await _readProfileForEdit();
    if (!mounted || fresh == null) return;
    if (fresh['membershipStatus'] != 'active') {
      showRaftToast(context, 'This member is no longer available.');
      return;
    }
    await scopedDialog<void>(
      form: true,
      (context) => ownDescriptionDialog(
        context,
        client: w.client,
        initial: '${fresh['description'] ?? ''}',
        onSaved: () async {
          await reload();
          unawaited(
            w.services.entityDirectory.refresh(
              WorkspaceEntityKind.members,
              force: true,
            ),
          );
        },
      ),
    );
  }

  /// `getEditableHumanServerRoles`: the roles the viewer may assign.
  List<String> editableRoles({required bool self, required Object? role}) =>
      editableHumanServerRoles(
        actorRole: w.server?.string('role'),
        targetRole: role is String ? role : null,
        isSelf: self,
        ownerCount: _ownerCount,
      );

  int get _ownerCount => w.services.entityDirectory
      .rows(WorkspaceEntityKind.members)
      .where((m) => m['role'] == 'owner')
      .length;

  bool editingRole = false, roleSaving = false;
  final roleImpactChanges = ValueNotifier(0);
  late MemberRemovalImpactRead ownRoleImpact = _makeRoleImpactRead();

  MemberRemovalImpactRead _makeRoleImpactRead() =>
      MemberRemovalImpactRead(w, () => roleImpactChanges.value++);

  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the role editor is opened or cancelled, when a save starts, and when the viewed member or server/account changes (clearData); a late failure for another member is ignored.
  String? roleError;

  Future<void> editRole() async {
    final fresh = await _readProfileForEdit();
    if (!mounted || fresh == null || fresh['role'] is! String) return;
    final role = fresh['role'] as String;
    final roles = editableRoles(
      self: widget.userId == w.client.user?.id,
      role: role,
    );
    if (!canEditHumanRole(
      membershipStatus: fresh['membershipStatus'],
      remoteJoint:
          isChannelSummaryHuman(fresh) ||
          isRemoteJointHuman(fresh, w.server?.id),
      hasChangeMemberRoles: w.can('changeMemberRoles'),
      editableRoles: roles,
    )) {
      showRaftToast(context, 'This action is no longer available.');
      return;
    }
    if (w.server?.string('role') == 'owner') {
      ownRoleImpact.sync(w.server?.id, w.client.user?.id);
    }
    setState(() {
      profile = {...profile, 'role': role};
      roleError = null;
      editingRole = true;
    });
  }

  Future<void> saveRole(String next) async {
    final server = w.server?.id, previous = profile['role'];
    if (server == null || previous is! String || roleSaving) return;
    final id = widget.userId, source = authority;
    final self = id == w.client.user?.id;
    final selfDemotion =
        self && (humanRoleRanks[next] ?? 0) < (humanRoleRanks[previous] ?? 0);
    final change = MemberProfileRoleChange(
      workspace: w,
      server: server,
      member: id,
      name: humanDisplayName(profile),
      previous: previous,
      next: next,
    );
    final grant =
        !self &&
        next == 'owner' &&
        w.server?.string('role') == 'owner' &&
        (ownRoleImpact.kind == MemberRemovalImpactKind.loading ||
            (ownRoleImpact.impact?.computers ?? 0) > 0);
    setState(() {
      roleSaving = true;
      editingRole = false;
      roleError = null;
    });

    Future<void> apply() async {
      if (!mounted ||
          source != authority ||
          profile['role'] != previous ||
          !editableRoles(self: self, role: previous).contains(next)) {
        throw const RaftUserError('This action is no longer available.');
      }
      await change.apply();
    }

    try {
      if (selfDemotion || grant) {
        final accepted = await scopedDialog<bool>(
          (context) => memberRoleConfirmation(
            context,
            change: change,
            selfDemotion: selfDemotion,
            impact: w.server?.string('role') == 'owner' ? ownRoleImpact : null,
            changes: roleImpactChanges,
            onConfirm: apply,
          ),
        );
        if (accepted != true) return;
      } else {
        await apply();
      }
      if (!mounted || source != authority) return;
      change.showReceipt(
        context,
        allowUndo: !selfDemotion,
        onRestored: () async {
          if (mounted && source == authority) await reload();
        },
      );
      await reload();
    } catch (e) {
      // A failure for a member the page no longer shows is not this page's.
      if (mounted && source == authority) {
        setState(
          () => roleError = raftText(
            context,
            userErrorText(
              e,
              fallback: 'Failed to update role',
              where: 'member role',
            ),
          ),
        );
      }
    } finally {
      if (mounted && source == authority) setState(() => roleSaving = false);
    }
  }

  Widget _roleEditor(BuildContext context, RaftTokens t, List<String> roles) {
    final role = profile['role'] as String;
    return RaftInlineBadgeEditor(
      label: memberRoleLabel(context, role),
      selectedId: role,
      options: [
        for (final r in roles)
          RaftInlineBadgeOption(id: r, label: memberRoleLabel(context, r)),
      ],
      onSelect: (id) => unawaited(saveRole(id)),
      open: true,
      onOpenChanged: (open) {
        if (!open && mounted) setState(() => editingRole = false);
      },
      background: roleColor(t, role),
      foreground: roleInk(t, role),
    );
  }

  /// HumanDetailPanel.tsx ROLE_CONFIG brutal backgrounds (`theme-brutal:bg-*`)
  /// and elegant soft tokens.
  Color roleInk(RaftTokens t, String role) => switch (role) {
    'owner' => t.colors['warning-strong']!,
    'admin' => t.colors['accent-strong']!,
    'guest' => t.colors['info-strong']!,
    _ => t.colors['foreground-strong']!,
  };

  Color roleColor(RaftTokens t, String role) => switch (role) {
    'owner' => t.colors['warning-soft']!,
    'admin' => t.colors['accent-soft']!,
    'guest' => t.colors['info-soft']!,
    _ => t.colors['fill-muted']!,
  };

  /// Live agent activity (`agent:activity`) else the summary's status: the
  /// created-agent row's StatusDot (`computeAgentDisplayState`).
  String? _createdActivity(Map a) {
    final row = w.services.entityDirectory.agent('${a['id']}');
    final activity = row?['activity'];
    if (activity is String) return activity;
    return (row?['status'] ?? a['status']) == 'active' ? 'online' : 'offline';
  }

  /// Departed members: the "Status" label with a Left / Removed badge in place
  /// of the Role field (HumanDetailPanel.tsx:596-598, 634-639).
  Widget _statusField(BuildContext context, RaftTokens t, String departure) {
    final label = departure == 'Left'
        ? raftTextZh(context, 'Left', '已离开')
        : raftTextZh(context, 'Removed', '已移除');
    return RaftGapColumn(
      gap: 4,
      children: [
        RaftCssText(
          raftTextZh(context, 'Status', '状态'),
          style: RaftPanelText.profileLabel(t),
        ),
        RaftInlineBadge(
          key: const ValueKey('member-departure-status'),
          badge: RaftRecipeBadge(
            label,
            background: t.colors['fill-muted'],
            foreground: t.colors['foreground-strong'],
          ),
          bodyLine: true,
        ),
      ],
    );
  }

  /// `humanAvatar.ts` / `projectSenderAvatar`: only an uploaded
  /// `/(api/)avatars/users/<hex>.webp` is drawn, else the placeholder; legacy
  /// provider URLs are ignored. Self uses the signed-in user's own record.
  SenderAvatarProjection _avatar() {
    final id = '${profile['userId'] ?? widget.userId}';
    final own = w.client.user;
    return projectSenderAvatar(
      origin: w.client.origin,
      senderId: id,
      senderType: 'user',
      agents: const [],
      members: [
        {
          ...profile,
          'userId': id,
          // Your own avatar is the signed-in user's: a photo or a built one
          // you just saved shows before the profile is read again.
          if (own != null && own.id == id) 'avatarUrl': own.json['avatarUrl'],
        },
      ],
      currentUser: w.client.user?.json,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = humanDisplayName(profile);
    final handle = '${profile['name'] ?? ''}';
    final self =
        profile['userId'] == w.client.user?.id ||
        widget.userId == w.client.user?.id;
    final avatar = _avatar();
    final avatarUrl = avatar.uploadedUrl;
    // What the avatar draws: the uploaded photo, else the avatar they built.
    final avatarDrawn = avatarUrl ?? avatar.pixelKey;
    final remoteJoint = isRemoteJointHuman(profile, w.server?.id);
    if (profile.isEmpty) {
      return SourceProfileLoadingPanel(
        onBack: widget.onBack,
        onClose: widget.onClose,
        error: loading ? null : error ?? 'Profile unavailable',
        onRetry: reload,
      );
    }
    return RaftPanelTextScope(
      sans: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final chrome = RaftPanelHeaderChrome.maybeOf(context);
              final moves = chrome?.moves ?? const [];
              // Stacked over another pane by its host (the channel side area):
              // Back replaces the close X and reveals the pane underneath.
              final back = widget.onBack ?? chrome?.onBack;
              final hasClose = back == null && widget.showClose;
              final showMessage =
                  widget.onMessage != null &&
                  !isChannelSummaryHuman(profile) &&
                  canMessageHuman(
                    membershipStatus: profile['membershipStatus'],
                    remoteJoint: remoteJoint,
                    actorRole: w.server?.string('role'),
                    targetRole: profile['role'] as String?,
                  );
              final foldMessage =
                  showMessage &&
                  (chrome?.foldsProfileMessage(
                        context,
                        width: box.maxWidth,
                        hasClose: hasClose,
                        hasMenu: moves.isNotEmpty,
                      ) ??
                      false);
              final messageLabel = raftText(context, 'Message');
              final onMessage = busy
                  ? null
                  : () => run(widget.onMessage!, refresh: false);
              return RaftPanelHeaderBar(
                title: name,
                useHostChrome: true,
                handlesHostMoves: true,
                subtitle: handle.isEmpty ? null : '@$handle',
                profileHandle: true,
                iconSlot: (chrome?.showsProfileAvatar(box.maxWidth) ?? true)
                    ? RaftAvatarSlot(
                        name: name,
                        agent: false,
                        avatarUrl: avatarDrawn,
                        slot: RaftAvatarSlotContext.panelHeader,
                        content: RaftAvatarContent(
                          name: name,
                          uploadedUrl: avatar.uploadedUrl,
                          pixelKey: avatar.pixelKey,
                          fallback: Center(
                            child: RaftIcon(
                              RaftGlyph.user,
                              size: 18,
                              color: RaftTokens.of(context).ui.stickerInk,
                            ),
                          ),
                        ),
                      )
                    : null,
                onBack: back,
                iconAlwaysVisible: true,
                profileBody: true,
                backTooltip: raftText(context, 'Back'),
                actions: [
                  if (showMessage && !foldMessage)
                    RaftPanelIconButton(
                      responsiveSize: true,
                      icon: (size, color) =>
                          RaftDirectMessageIcon(size: size, color: color),
                      tooltip: messageLabel,
                      onPressed: onMessage,
                    ),
                  if (foldMessage || moves.isNotEmpty)
                    RaftOverflowMenuButton(
                      key: const Key('channel-profile-move'),
                      tooltip: raftText(context, 'More actions'),
                      entries: [
                        if (foldMessage)
                          RaftMenuEntry(
                            label: messageLabel,
                            leading: const RaftDirectMessageIcon(),
                            onPressed: onMessage,
                          ),
                        ...moves,
                      ],
                    ),
                  if (hasClose)
                    RaftPanelIconButton(
                      responsiveSize: true,
                      glyph: RaftGlyph.x,
                      tooltip: raftText(context, 'Close Profile'),
                      onPressed: widget.onClose,
                    ),
                ],
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: raftScrollPadding(context),
              children: [
                if (error != null)
                  RaftLoadError(
                    'Profile could not be loaded.',
                    onRetry: reload,
                    expand: false,
                  ),
                ..._sections(
                  context,
                  name,
                  handle,
                  self,
                  avatarUrl,
                  avatarDrawn,
                  remoteJoint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void openAgent(String id) {
    final open = widget.onOpenAgent;
    if (open != null) {
      open(id);
    } else {
      w.openProfile(RaftProfileKind.agent, id);
    }
  }

  /// Web `HumanDetailPanel` lightbox: an uploaded avatar opens large, titled
  /// with the person's name.
  Future<void> viewAvatar() async {
    final url = _avatar().uploadedUrl;
    if (url == null) return;
    try {
      final bytes = await RaftImageBytes.instance.load(url);
      if (!mounted) return;
      await showFeedbackImage(
        context,
        filename: humanDisplayName(profile),
        contentType: 'image/png',
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) showRaftToast(context, 'Failed to load file');
    }
  }

  List<Widget> _sections(
    BuildContext context,
    String name,
    String handle,
    bool self,
    String? avatarUrl,
    String? avatarDrawn,
    bool remoteJoint,
  ) {
    final t = RaftTokens.of(context);
    final role = '${profile['role'] ?? ''}';
    final created = (profile['createdAgents'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final joinedRaw = profile['joinedAt'];
    final joined = joinedRaw is String && DateTime.tryParse(joinedRaw) != null
        ? DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
              .format(DateTime.parse(joinedRaw).toLocal())
        : null;
    final status = profile['membershipStatus'];
    final departure = humanDepartureLabel(status);
    final summaryOnly = remoteJoint || isChannelSummaryHuman(profile);
    final source = humanSourceServerLabel(profile, w.server?.id);
    // HumanDetailPanel: your own picture and description, while you are an
    // active member.
    final editOwn = self && status == 'active';
    final roles = w.can('changeMemberRoles')
        ? editableRoles(self: self, role: profile['role'])
        : const <String>[];
    final canRole = canEditHumanRole(
      membershipStatus: status,
      remoteJoint: summaryOnly,
      hasChangeMemberRoles: w.can('changeMemberRoles'),
      editableRoles: roles,
    );
    final canRemove = canRemoveHuman(
      membershipStatus: status,
      remoteJoint: summaryOnly,
      hasRemoveMembers: w.can('removeMembers'),
      isSelf: self,
      targetRole: profile['role'] is String ? profile['role'] as String : null,
      actorRole: w.server?.string('role'),
      ownerCount: _ownerCount,
    );
    final canPromote =
        canRole && !self && role == 'guest' && roles.contains('member');
    return [
      if (source != null)
        RaftPanelSection(
          topBorder: false,
          vertical: 12,
          gap: 4,
          children: [
            RaftSectionEyebrow(raftTextZh(context, 'From', '来自')),
            RaftCssText(
              source,
              style: raftCssText.merge(
                RaftTypography.heading(
                  t,
                  size: 14,
                  line: 20,
                ).copyWith(color: t.colors['foreground-strong']),
              ),
            ),
          ],
        ),
      RaftProfileIdentity(
        name: name,
        handle: handle,
        agent: false,
        avatarUrl: avatarDrawn,
        youLabel: self ? raftText(context, '(you)') : null,
        // Web: your own avatar is the way to change it (HumanAvatarEditMenu:
        // Upload a photo / Build an avatar); anyone else's uploaded picture
        // opens enlarged, a built one is just drawn.
        avatarWrap: editOwn
            ? (slot) => HumanAvatarEditMenu(
                key: const ValueKey('human-detail-avatar-edit'),
                client: w.client,
                workspace: w,
                avatarUrl: w.client.user?.string('avatarUrl'),
                busy: avatarSaving,
                onUpload: uploadAvatar,
                onBuilt: () => setState(() => avatarError = null),
                avatar: slot,
              )
            : null,
        onAvatar: !editOwn && avatarUrl != null ? viewAvatar : null,
        avatarLabel: 'View avatar',
      ),
      if (editOwn && avatarError != null)
        RaftPanelSection(
          topBorder: false,
          vertical: 8,
          children: [
            Semantics(
              liveRegion: true,
              child: RaftCssText(
                raftText(context, avatarError!),
                key: const ValueKey('member-avatar-error'),
                style: RaftTypography.heading(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w600,
                  color: t.colors['danger'],
                ),
              ),
            ),
          ],
        ),
      if (detailSettled || profile['description'] is String)
        RaftPanelSection(
          children: [
            RaftDescriptionBlock(
              text: '${profile['description'] ?? ''}',
              human: true,
              onEdit: editOwn ? editDescription : null,
              editKey: const ValueKey('member-edit-description'),
            ),
          ],
        ),
      if (!summaryOnly)
        RaftPanelSection(
          children: [
            RaftSectionEyebrow(raftText(context, 'Info')),
            if (departure != null)
              _statusField(context, t, departure)
            else if (role.isNotEmpty)
              RaftRoleField(
                label: raftText(context, 'Role'),
                badge: RaftRecipeBadge(
                  raftText(
                    context,
                    '${role[0].toUpperCase()}${role.substring(1)}',
                  ),
                  variant: role == 'guest'
                      ? RaftBadgeRecipeVariant.information
                      : RaftBadgeRecipeVariant.default_,
                ),
                editKey: const ValueKey('member-edit-role'),
                helpKey: const ValueKey('member-role-help'),
                onHelp: () => showRaftRolePermissionHelp(context, agent: false),
                onEdit: canRole && !roleSaving ? editRole : null,
                editor: canRole && editingRole
                    ? _roleEditor(context, t, roles)
                    : null,
              ),
            if (roleError != null)
              RaftCssText(
                roleError,
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.ui['warning-strong'],
                ),
              ),
            if (profile['email'] is String)
              RaftKeyValueRow.humanProfile(
                label: raftText(context, 'Email'),
                value: '${profile['email']}',
                breakAll: true,
              ),
            if (profile['guestChannel'] case {'name': final String channel}
                when role == 'guest')
              RaftKeyValueRow.humanProfile(
                label: raftText(context, 'Channel'),
                value: raftFormat(context, 'Guest in #{channel}', {
                  'channel': channel,
                }),
              ),
            if (joined != null)
              RaftKeyValueRow.humanProfile(
                label: raftText(context, 'Joined'),
                value: joined,
                mono: true,
              ),
          ],
        ),
      if (detailSettled && !summaryOnly)
        RaftPanelSection(
          children: [
            RaftSectionHeader(
              label: raftText(context, 'Created agents'),
              count: created.length,
            ),
            if (created.isEmpty)
              RaftCssText(
                raftText(context, 'No agents created yet'),
                style: RaftInfoRow.hintStyleOf(context),
              )
            else
              RaftGapColumn(
                children: [
                  for (final a in created)
                    RaftAvatarListRow(
                      key: ValueKey('created-agent-${a['id']}'),
                      onTap: a['id'] is String
                          ? () => openAgent(a['id'] as String)
                          : null,
                      avatar: RaftAvatarSlot(
                        name: humanDisplayName(a),
                        avatarUrl: a['avatarUrl'] as String?,
                        slot: RaftAvatarSlotContext.surfaceList,
                      ),
                      name: humanDisplayName(a),
                      // CreatedAgentRow.tsx:47: the server's answer.
                      subtitle: runtimeLabelWithStatus(
                        context,
                        '${a['runtime'] ?? ''}',
                        deprecated: deprecatedHere('${a['runtime'] ?? ''}'),
                      ),
                      rightContent: [
                        RaftActivityDot(
                          color: raftActivityDotColor(t, _createdActivity(a)),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      if (canRemove || canPromote)
        RaftPanelSection(
          children: [
            RaftSectionEyebrow(raftText(context, 'Actions')),
            if (canPromote)
              RaftButton(
                key: const ValueKey('human-promote-guest'),
                label: 'Promote to server member',
                glyph: RaftGlyph.userPlus,
                uiVariant: RaftButtonVariant.standard,
                uiSize: RaftButtonSize.lg,
                iconInlineStart: false,
                expand: true,
                onPressed: promote,
              ),
            if (canRemove)
              RaftButton(
                key: const ValueKey('member-remove'),
                label: raftText(context, 'Remove member'),
                glyph: RaftGlyph.trash2,
                uiVariant: RaftButtonVariant.danger,
                uiSize: RaftButtonSize.lg,
                iconInlineStart: false,
                expand: true,
                onPressed: busy ? null : remove,
              ),
          ],
        ),
    ];
  }
}
