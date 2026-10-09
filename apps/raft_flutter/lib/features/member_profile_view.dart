import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../data/workspace_entity_directory.dart';
import 'management_support.dart';
import 'agent_detail_view.dart';
import 'public_avatar_url.dart';

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
  });
  final WorkspaceController controller;
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
  @override
  String get authority =>
      '${super.authority}|${identityHashCode(w)}|${w.client.origin}|${widget.userId}|${w.can('viewMembers')}';
  @override
  void initState() {
    super.initState();
    profile = w.entityDirectory.member(widget.userId) ?? {};
    w.entityDirectory.addListener(directoryChanged);
    startManagement();
  }

  @override
  void didUpdateWidget(MemberProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      oldWidget.controller.entityDirectory.removeListener(directoryChanged);
      w.entityDirectory.addListener(directoryChanged);
      rebindManagementController();
      profile = w.entityDirectory.member(widget.userId) ?? {};
    } else if (oldWidget.userId != widget.userId) {
      refreshAuthority();
      profile = w.entityDirectory.member(widget.userId) ?? {};
    }
  }

  void directoryChanged() {
    if (!mounted) return;
    final failure = w.entityDirectory.state(WorkspaceEntityKind.members).error;
    if (failure is RaftApiException && [401, 403].contains(failure.status)) {
      setState(() {
        profile = {};
        error = '$failure';
        loading = false;
      });
      return;
    }
    final live = w.entityDirectory.member(widget.userId);
    if (live != null) setState(() => profile = {...profile, ...live});
  }

  @override
  void dispose() {
    w.entityDirectory.removeListener(directoryChanged);
    super.dispose();
  }

  @override
  void clearData() => profile = {};
  @override
  Future<void> loadData(int request, int generation) async {
    if (w.server == null || !w.can('viewMembers')) {
      clearData();
      return;
    }
    final server = w.server!.id, id = widget.userId;
    final value = await w.query('/servers/$server/members/$id/profile');
    if (value is! Map || value['name'] is! String) {
      throw const FormatException('Invalid member profile response.');
    }
    if (accepts(generation, request)) {
      final failure = w.entityDirectory
          .state(WorkspaceEntityKind.members)
          .error;
      if (failure is RaftApiException && [401, 403].contains(failure.status)) {
        throw failure;
      }
      // resolveHumanProfile.ts:4–17: accepted live membership wins over a
      // fallback detail projection; preserve detail-only fields.
      profile = {
        ...Map<String, dynamic>.from(value),
        ...?w.entityDirectory.member(widget.userId),
      };
    }
  }

  Future<void> roleOrRemove(String action) async {
    final server = w.server!.id, id = widget.userId;
    final name = '${profile['displayName'] ?? profile['name']}';
    await scopedDialog<void>(
      (_) => RaftFormDialog(
        title: action == 'remove'
            ? raftText(context, 'Remove Member')
            : raftText(context, 'Change role?'),
        description: action == 'remove'
            ? raftFormat(
                context,
                'Remove this member from {workspace}. They will lose workspace access.',
                {'workspace': w.server!.name},
              )
            : null,
        fields: [
          if (action != 'remove')
            RaftFormField(
              'role',
              'Role',
              initial: '${profile['role'] ?? 'member'}',
              choices: {
                for (final r
                    in w.server!.string('role') == 'owner'
                        ? ['owner', 'admin', 'member', 'guest']
                        : ['member', 'guest'])
                  r: '${r[0].toUpperCase()}${r.substring(1)}',
              },
            ),
        ],
        submitLabel: action == 'remove' ? 'Remove' : 'Confirm',
        destructive: action == 'remove',
        onSubmit: (v) async {
          await w.command(
            action == 'remove' ? 'DELETE' : 'PATCH',
            '/servers/$server/members/$id',
            data: action == 'remove' ? null : {'role': v['role']},
          );
        },
      ),
    );
    if (action == 'remove' && mounted) {
      widget.onBack != null ? widget.onBack!() : widget.onClose();
    } else {
      await reload();
    }
    if (name.isEmpty) return;
  }

  /// HumanDetailPanel.tsx ROLE_CONFIG brutal backgrounds (`theme-brutal:bg-*`)
  /// and elegant soft tokens.
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

  @override
  Widget build(BuildContext context) {
    final name = '${profile['displayName'] ?? profile['name'] ?? ''}';
    final handle = '${profile['name'] ?? ''}';
    final self =
        profile['userId'] == w.client.user?.id ||
        widget.userId == w.client.user?.id;
    final avatarUrl = raftPublicAvatarUrl(
      w.client.origin,
      profile['avatarUrl'] as String?,
    );
    if (profile.isEmpty) {
      return SourceProfileLoadingPanel(
        onBack: widget.onBack,
        onClose: widget.onClose,
        error: loading ? null : error ?? 'Profile unavailable',
        onRetry: reload,
      );
    }
    return RaftPanelTextScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftPanelHeaderBar(
            title: name,
            subtitle: handle.isEmpty ? null : '@$handle',
            iconSlot: RaftAvatarSlot(
              name: name,
              agent: false,
              avatarUrl: avatarUrl,
              slot: RaftAvatarSlotContext.panelHeader,
            ),
            onBack: widget.onBack,
            backTooltip: raftText(context, 'Back'),
            actions: [
              if (!self && widget.onMessage != null)
                RaftPanelIconButton(
                  glyph: RaftGlyph.messageSquareMore,
                  tooltip: raftText(context, 'Message'),
                  onPressed: busy
                      ? null
                      : () => run(widget.onMessage!, refresh: false),
                ),
              if (widget.onBack == null)
                RaftPanelIconButton(
                  glyph: RaftGlyph.x,
                  tooltip: raftText(context, 'Close profile'),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (error != null)
                  RaftPanelMessage(
                    raftText(context, 'Profile could not be loaded.'),
                    action: RaftButton(label: 'Retry', onPressed: reload),
                  ),
                ..._sections(context, name, handle, self, avatarUrl),
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
    final canRole = !self && w.can('changeMemberRoles');
    final canRemove = !self && w.can('removeMembers');
    return [
      RaftProfileIdentity(
        name: name,
        handle: handle,
        agent: false,
        avatarUrl: avatarUrl,
      ),
      RaftPanelSection(
        children: [
          RaftDescriptionBlock(text: '${profile['description'] ?? ''}'),
        ],
      ),
      RaftPanelSection(
        children: [
          RaftSectionEyebrow(raftText(context, 'Info')),
          if (role.isNotEmpty)
            RaftRoleField(
              label: raftText(context, 'Role'),
              badge: RaftRecipeBadge(
                raftText(
                  context,
                  '${role[0].toUpperCase()}${role.substring(1)}',
                ),
                appearance: RaftBadgeRecipeAppearance.solid,
                background: roleColor(t, role),
              ),
              onEdit: canRole
                  ? () => run(() => roleOrRemove('role'), refresh: false)
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
      RaftPanelSection(
        children: [
          RaftSectionHeader(
            label: raftText(context, 'Created Agents'),
            count: created.length,
          ),
          if (created.isEmpty)
            Text(
              raftText(context, 'No created agents'),
              style: RaftPanelText.placeholder(t),
            )
          else
            RaftGapColumn(
              children: [
                for (final a in created)
                  RaftAvatarListRow(
                    avatar: RaftAvatarSlot(
                      name: '${a['displayName'] ?? a['name']}',
                      avatarUrl: a['avatarUrl'] as String?,
                      slot: RaftAvatarSlotContext.surfaceList,
                    ),
                    name: '${a['displayName'] ?? a['name']}',
                    subtitle: sourceRuntimeDisplayNames['${a['runtime']}'],
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
              label: raftText(context, 'Remove Member'),
              glyph: RaftGlyph.trash2,
              variant: RaftButtonRecipeVariant.danger,
              text: RaftButtonText.sm,
              bold: true,
              expand: true,
              horizontalPadding: 16,
              onPressed: busy
                  ? null
                  : () => run(() => roleOrRemove('remove'), refresh: false),
            ),
          ],
        ),
    ];
  }
}
