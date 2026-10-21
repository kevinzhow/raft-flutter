import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/feature_flag_client_facts.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart';
import 'agent_detail_view.dart';
import 'agent_runtime_labels.dart' show runtimeLabelWithStatus;
import 'channel_member_servers.dart' show withPrimedServers;
import 'member_profile_rules.dart';
import 'sender_avatar_projection.dart';

/// Current-authority HumanRoute/ProfilePanel fallback contract. Entity payloads
/// remain in this loader's memory and are cleared on role/principal/workspace
/// changes; the shell stores only the selected user id.
class MemberProfileView extends StatefulWidget {
  const MemberProfileView({
    super.key,
    required this.controller,
    required this.userId,
    required this.onClose,
    this.onMessage,
    this.onBack,
    this.showClose = true,
  });
  final WorkspaceController controller;

  /// Web HumanRoute renders no close control (only the overlay presentation
  /// passes `onClose`); the desktop detail pane hides it.
  final bool showClose;
  final String userId;
  final VoidCallback onClose;

  /// Mobile route back (PanelHeader `onMobileBack`); without it the desktop
  /// pane shows a close action instead.
  final VoidCallback? onBack;
  final Future<void> Function()? onMessage;
  @override
  State<MemberProfileView> createState() => _MemberProfileViewState();
}

class _MemberProfileViewState extends ManagementState<MemberProfileView> {
  @override
  WorkspaceController get w => widget.controller;
  Map<String, dynamic> profile = {};

  /// The profile read (description, created agents, join date) was accepted
  /// or restored. Until then only the directory's membership row is shown, so
  /// the detail sections do not appear empty and then fill in.
  bool detailLoaded = false;

  /// The detail read settled (accepted, restored, or failed): a failed read
  /// shows the empty sections it always showed rather than a shorter panel.
  bool get detailSettled => detailLoaded || !loading;
  @override
  String get authority =>
      '${super.authority}|${identityHashCode(w)}|${w.client.origin}|${widget.userId}';
  @override
  String get snapshotKey => 'member-profile:${widget.userId}';
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
      oldWidget.controller.services.entityDirectory.removeListener(
        directoryChanged,
      );
      w.services.entityDirectory.addListener(directoryChanged);
      rebindManagementController();
      profile = {
        ...profile,
        ...?w.services.entityDirectory.member(widget.userId),
      };
    } else if (oldWidget.userId != widget.userId) {
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
    w.services.entityDirectory.removeListener(directoryChanged);
    super.dispose();
  }

  @override
  void clearData() {
    profile = {};
    detailLoaded = false;
    guestEnabled = false;
    guestFlagRequested = false;
    // The role editor and its error belong to the member they were opened for.
    roleError = null;
    editingRole = rolePickerOpen = false;
  }

  @override
  Future<void> loadData(int request, int generation) async {
    // ProfilePanel.tsx:151-156 fetches without a capability gate: the server
    // serves a guest a channel-scoped profile (servers.ts:2297-2304).
    if (w.server == null) {
      clearData();
      return;
    }
    final server = w.server!.id, id = widget.userId;
    final value = await w.query('/servers/$server/members/$id/profile');
    if (value is! Map || value['name'] is! String) {
      throw const FormatException('Invalid member profile response.');
    }
    if (accepts(generation, request)) {
      final failure = w.services.entityDirectory
          .state(WorkspaceEntityKind.members)
          .error;
      if (failure is RaftApiException && [401, 403].contains(failure.status)) {
        throw failure;
      }
      // resolveHumanProfile.ts:4–17: accepted live membership wins over a
      // fallback detail projection; preserve detail-only fields.
      profile = withPrimedServers(
        w,
        {
          ...Map<String, dynamic>.from(value),
          ...?w.services.entityDirectory.member(widget.userId),
        },
        w.server?.id,
        widget.userId,
      );
      detailLoaded = true;
      // `useServerFeatureFlag(server_guest_v0)` feeds the role options
      // (humanRoleTransitions.ts:11): a Guest target has no options while the
      // flag is off, so it must be known before the editor can be offered.
      // Other targets read it lazily when the editor opens.
      if (profile['role'] == 'guest' &&
          w.can('changeMemberRoles') &&
          !guestFlagRequested) {
        guestFlagRequested = true;
        unawaited(loadGuestFlag());
      }
    }
  }

  /// HumanDetailPanel `ConfirmDialog` for removing the member.
  Future<void> remove() async {
    final server = w.server!.id, id = widget.userId;
    final name = humanDisplayName(profile);
    final removed = await scopedDialog<bool>(
      (_) => RaftConfirmDialog(
        surfaceKey: const ValueKey('agent-dialog'),
        title: raftText(context, 'Remove Member'),
        message: raftFormat(
          context,
          '{name} will be removed from every channel on this server. Their past messages will remain in history.',
          {'name': name},
        ),
        confirmLabel: raftText(context, 'Remove'),
        loadingLabel: raftText(context, 'Removing…'),
        onConfirm: () async {
          await w.command('DELETE', '/servers/$server/members/$id');
        },
      ),
    );
    if (removed == true && mounted) {
      widget.onBack != null ? widget.onBack!() : widget.onClose();
    }
  }

  /// `getEditableHumanServerRoles`: the roles the viewer may assign
  /// (`canTransitionServerRole`; Guest only while guest invites are on).
  List<String> editableRoles({required bool self}) => editableHumanServerRoles(
    actorRole: w.server?.string('role'),
    targetRole: profile['role'] is String ? profile['role'] as String : null,
    isSelf: self,
    ownerCount: _ownerCount,
    serverGuestEnabled: guestEnabled,
  );

  int get _ownerCount => w.services.entityDirectory
      .rows(WorkspaceEntityKind.members)
      .where((m) => m['role'] == 'owner')
      .length;

  /// `useServerFeatureFlag(server_guest_v0)`: Guest is only assignable while
  /// guest invites are on (`getEditableHumanServerRoles` `serverGuestEnabled`).
  late bool guestEnabled = cachedServerFlag(w, 'server_guest_v0') ?? false;
  bool guestFlagRequested = false;

  Future<void> loadGuestFlag() async {
    final server = w.server?.id;
    if (server == null) return;
    final identity = pageIdentity(w);
    try {
      final result = await w.command(
        'POST',
        '/feature-flags/evaluate',
        data: featureFlagEvaluateBody(
          keys: const ['server_guest_v0'],
          serverId: server,
        ),
      );
      final on =
          result is Map &&
          (result['evaluations'] as List? ?? []).whereType<Map>().any(
            (f) => f['key'] == 'server_guest_v0' && f['enabled'] == true,
          );
      rememberServerFlag(w, 'server_guest_v0', on, identity);
      if (mounted && on != guestEnabled) setState(() => guestEnabled = on);
    } catch (_) {}
  }

  bool editingRole = false, rolePickerOpen = false, roleSaving = false;
  String roleValue = 'member';
  // ignore: raft_lints/avoid_imperative_notice_state -- Clears when the role editor is opened or cancelled, when a save starts, and when the viewed member or server/account changes (clearData); a late failure for another member is ignored.
  String? roleError;

  Future<void> saveRole() async {
    final server = w.server!.id, id = widget.userId, source = authority;
    setState(() {
      roleSaving = true;
      roleError = null;
    });
    try {
      await w.command(
        'PATCH',
        '/servers/$server/members/$id',
        data: {'role': roleValue},
      );
      await reload();
      if (mounted) setState(() => editingRole = false);
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
      if (mounted) setState(() => roleSaving = false);
    }
  }

  /// InlineBadgeEditor + Save / Cancel.
  Widget _roleEditor(BuildContext context, RaftTokens t, List<String> roles) {
    String name(String r) =>
        raftText(context, '${r[0].toUpperCase()}${r.substring(1)}');
    return RaftInlineRoleEditor(
      saveKey: const ValueKey('member-edit-role-save'),
      label: name(roleValue),
      selectedId: roleValue,
      options: [
        for (final r in roles) RaftInlineBadgeOption(id: r, label: name(r)),
      ],
      onSelect: (id) => setState(() {
        roleValue = id;
        rolePickerOpen = false;
      }),
      open: rolePickerOpen,
      onOpenChanged: (open) => setState(() => rolePickerOpen = open),
      background: roleColor(t, roleValue),
      foreground: roleInk(t, roleValue),
      saveLabel: raftText(context, 'Save'),
      cancelLabel: raftText(context, 'Cancel'),
      canSave: !roleSaving && roleValue != profile['role'],
      canCancel: !roleSaving,
      onSave: saveRole,
      onCancel: () => setState(() {
        rolePickerOpen = false;
        roleError = null;
        editingRole = false;
      }),
      error: roleError,
    );
  }

  /// HumanDetailPanel.tsx ROLE_CONFIG brutal backgrounds (`theme-brutal:bg-*`)
  /// and elegant soft tokens.
  Color roleInk(RaftTokens t, String role) => t.brutal
      ? t.product.brutalBlack
      : switch (role) {
          'owner' => t.colors['warning-strong']!,
          'admin' => t.colors['accent-strong']!,
          'guest' => t.colors['info-strong']!,
          _ => t.colors['foreground-strong']!,
        };

  Color roleColor(RaftTokens t, String role) => t.brutal
      ? switch (role) {
          'owner' => t.product.brutalOrange,
          'admin' => t.product.brutalPink,
          'guest' => t.product.brutalCyan,
          _ => t.product.brutalLavender,
        }
      : switch (role) {
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
  /// `/(api/)avatars/users/<hex>.webp` preempts Gravatar; legacy provider URLs
  /// are ignored. Self uses the signed-in user's own record.
  SenderAvatarProjection _avatar() {
    final id = '${profile['userId'] ?? widget.userId}';
    return projectSenderAvatar(
      origin: w.client.origin,
      senderId: id,
      senderType: 'user',
      agents: const [],
      members: [
        {...profile, 'userId': id},
      ],
      currentUser: w.client.user?.json,
      requestSize: 64,
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
          RaftPanelHeaderBar(
            title: name,
            subtitle: handle.isEmpty ? null : '@$handle',
            profileHandle: true,
            iconSlot: RaftAvatarSlot(
              name: name,
              agent: false,
              avatarUrl: avatarUrl,
              slot: RaftAvatarSlotContext.panelHeader,
              content: RaftAvatarContent(
                name: name,
                uploadedUrl: avatar.uploadedUrl,
                gravatarUrl: avatar.gravatarUrl,
                fallback: const Center(
                  child: RaftIcon(RaftGlyph.user, size: 18),
                ),
              ),
            ),
            onBack: widget.onBack,
            iconAlwaysVisible: true,
            profileBody: true,
            backTooltip: raftText(context, 'Back'),
            actions: [
              // canMessageHuman: not for a guest (no existing DM known here).
              if (widget.onMessage != null &&
                  canMessageHuman(
                    membershipStatus: profile['membershipStatus'],
                    remoteJoint: remoteJoint,
                    actorRole: w.server?.string('role'),
                    targetRole: profile['role'] as String?,
                  ))
                RaftPanelIconButton(
                  icon: (size, color) =>
                      RaftDirectMessageIcon(size: size, color: color),
                  tooltip: raftText(context, 'Message'),
                  onPressed: busy
                      ? null
                      : () => run(widget.onMessage!, refresh: false),
                ),
              if (widget.onBack == null && widget.showClose)
                RaftPanelIconButton(
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close profile'),
                  onPressed: widget.onClose,
                ),
            ],
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
                  remoteJoint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    String name,
    String handle,
    bool self,
    String? avatarUrl,
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
    final roles = w.can('changeMemberRoles')
        ? editableRoles(self: self)
        : const <String>[];
    final canRole = canEditHumanRole(
      membershipStatus: status,
      remoteJoint: remoteJoint,
      hasChangeMemberRoles: w.can('changeMemberRoles'),
      editableRoles: roles,
    );
    final canRemove = canRemoveHuman(
      membershipStatus: status,
      remoteJoint: remoteJoint,
      hasRemoveMembers: w.can('removeMembers'),
      isSelf: self,
      targetRole: profile['role'] is String ? profile['role'] as String : null,
      actorRole: w.server?.string('role'),
      ownerCount: _ownerCount,
    );
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
        avatarUrl: avatarUrl,
        youLabel: self ? raftText(context, '(you)') : null,
      ),
      if (detailSettled || profile['description'] is String)
        RaftPanelSection(
          children: [
            RaftDescriptionBlock(text: '${profile['description'] ?? ''}'),
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
                  background: roleColor(t, role),
                  foreground: roleInk(t, role),
                ),
                editKey: const ValueKey('member-edit-role'),
                helpKey: const ValueKey('member-role-help'),
                onHelp: () => showRaftRolePermissionHelp(context, agent: false),
                onEdit: canRole
                    ? () {
                        // `useServerFeatureFlag(server_guest_v0)`: read when the
                        // role editor is first needed.
                        if (!guestFlagRequested) {
                          guestFlagRequested = true;
                          unawaited(loadGuestFlag());
                        }
                        setState(() {
                          roleValue = role;
                          rolePickerOpen = true;
                          roleError = null;
                          editingRole = true;
                        });
                      }
                    : null,
                editor: canRole && editingRole
                    ? _roleEditor(context, t, roles)
                    : null,
              ),
            if (profile['email'] is String)
              RaftKeyValueRow(
                label: raftText(context, 'Email'),
                value: '${profile['email']}',
                mono: true,
                breakAll: true,
              ),
            if (joined != null)
              RaftKeyValueRow(
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
              label: raftText(context, 'Created Agents'),
              count: created.length,
            ),
            if (created.isEmpty)
              RaftSpanPlaceholder(raftText(context, 'No created agents'))
            else
              RaftGapColumn(
                children: [
                  for (final a in created)
                    RaftAvatarListRow(
                      avatar: RaftAvatarSlot(
                        name: humanDisplayName(a),
                        avatarUrl: a['avatarUrl'] as String?,
                        slot: RaftAvatarSlotContext.surfaceList,
                      ),
                      name: humanDisplayName(a),
                      subtitle: runtimeLabelWithStatus(
                        context,
                        '${a['runtime'] ?? ''}',
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
      if (canRemove)
        RaftPanelSection(
          children: [
            RaftSectionEyebrow(raftText(context, 'Actions')),
            // `<Button size="sm" variant="danger" className="flex w-full
            // items-center justify-center gap-2 px-4 py-2 text-sm font-bold">`.
            RaftRecipeTextButton(
              key: const ValueKey('member-remove'),
              label: raftText(context, 'Remove Member'),
              glyph: RaftGlyph.trash2,
              variant: RaftButtonRecipeVariant.danger,
              text: RaftButtonText.sm,
              bold: true,
              expand: true,
              horizontalPadding: 16,
              onPressed: busy ? null : remove,
            ),
          ],
        ),
    ];
  }
}
