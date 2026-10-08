import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart';

import '../data/workspace_controller.dart';
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
    startManagement();
  }

  @override
  void didUpdateWidget(MemberProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != w) {
      rebindManagementController();
    } else if (oldWidget.userId != widget.userId) {
      refreshAuthority();
    }
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
    if (accepts(generation, request) && value is Map) {
      profile = Map<String, dynamic>.from(value);
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
    final t = RaftTokens.of(context);
    final name = '${profile['displayName'] ?? profile['name'] ?? ''}';
    final handle = '${profile['name'] ?? ''}';
    final self = profile['userId'] == w.client.user?.id ||
        widget.userId == w.client.user?.id;
    final avatarUrl = raftPublicAvatarUrl(
      w.client.origin,
      profile['avatarUrl'] as String?,
    );
    Widget avatar(double size) => AgentAvatarSlot(
      name: name,
      agent: false,
      avatarUrl: avatarUrl,
      size: size,
      border: 2,
    );
    return DefaultTextStyle(
      style: raftCssText(RaftTypography.body(t, color: t.ink)),
      child: ColoredBox(
        color: t.brutal ? Colors.white : t.colors['layer-panel']!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RaftPanelHeaderBar(
              title: name,
              subtitle: handle.isEmpty ? null : '@$handle',
              iconSlot: avatar(36),
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
              child: loading
                  ? Center(
                      child: Text(
                        raftText(context, 'Loading...'),
                        style: RaftTypography.mono(t, size: 14, line: 20),
                      ),
                    )
                  : error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(raftText(context, 'Profile could not be loaded.')),
                          RaftButton(label: 'Retry', onPressed: reload),
                        ],
                      ),
                    )
                  : profile.isEmpty
                  ? RaftEmptyState(
                      title: raftText(context, 'Profile unavailable'),
                      detail: '',
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: _sections(context, t, name, handle, self, avatar),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    RaftTokens t,
    String name,
    String handle,
    bool self,
    Widget Function(double) avatar,
  ) {
    final muted50 = raftPanelInk(t, .5, t.colors['foreground-muted']!);
    final strong = t.brutal ? Colors.black : t.strong;
    final section = BoxDecoration(
      border: Border(
        top: BorderSide(color: raftPanelInk(t, .1, t.colors['line-muted']!)),
      ),
    );
    final value = RaftInfoRow.valueStyle(t);
    final label = raftCssText(
      RaftTypography.body(t, size: 12, line: 16, color: muted50),
    );
    final role = '${profile['role'] ?? ''}';
    final description = '${profile['description'] ?? ''}';
    final created = (profile['createdAgents'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final joinedRaw = profile['joinedAt'];
    final joined = joinedRaw is String && DateTime.tryParse(joinedRaw) != null
        ? DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(DateTime.parse(joinedRaw).toLocal())
        : null;
    final canRole = !self && w.can('changeMemberRoles');
    final canRemove = !self && w.can('removeMembers');
    Widget keyValue(String key, String text, {bool mono = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(key, style: label),
        const SizedBox(height: 4),
        Text(
          mono ? text.characters.join('​') : text,
          style: mono ? value.copyWith(fontFamily: t.monoFont) : value,
        ),
      ],
    );
    Widget block(List<Widget> children) => Container(
      decoration: section,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return [
      // `flex items-start gap-4 px-5 py-5`.
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar(64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
                      RaftTypography.body(
                        t,
                        size: 18,
                        line: 22.5,
                        weight: FontWeight.w700,
                        color: strong,
                      ),
                    ),
                  ),
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssText(
                      RaftTypography.mono(t, size: 14, line: 20, color: muted50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      block([
        RaftSectionEyebrow(raftText(context, 'Description')),
        const SizedBox(height: 4),
        description.isEmpty
            ? Text(
                raftText(context, 'No description'),
                style: value.copyWith(
                  fontStyle: FontStyle.italic,
                  color: raftPanelInk(t, .4, t.colors['foreground-muted']!),
                ),
              )
            : SelectableText(description, style: value),
      ]),
      block([
        RaftSectionEyebrow(raftText(context, 'Info')),
        const SizedBox(height: 12),
        if (role.isNotEmpty) ...[
          Row(
            children: [
              Text(raftText(context, 'Role'), style: label),
              const SizedBox(width: 8),
              RaftInlineIconButton(
                glyph: RaftGlyph.circleHelp,
                tooltip: raftText(context, 'Role permissions'),
              ),
              if (canRole) ...[
                const SizedBox(width: 8),
                RaftInlineIconButton(
                  glyph: RaftGlyph.pencil,
                  tooltip: raftText(context, 'Edit role'),
                  onPressed: () => run(() => roleOrRemove('role'), refresh: false),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // The Badge is inline in a body-text (16/24) line.
          RaftInlineBox(
            lineText: raftCssText(RaftTypography.body(t)),
            childText: RaftTypography.body(
              t,
              size: 10,
              line: 10,
              weight: FontWeight.w700,
            ),
            height: 20,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AgentBadge(
                raftText(context, '${role[0].toUpperCase()}${role.substring(1)}'),
                appearance: RaftBadgeRecipeAppearance.solid,
                background: roleColor(t, role),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (profile['email'] is String) ...[
          keyValue(raftText(context, 'Email'), '${profile['email']}', mono: true),
          const SizedBox(height: 12),
        ],
        if (joined != null) keyValue(raftText(context, 'Joined'), joined, mono: true),
      ]),
      block([
        RaftSectionHeader(
          label: raftText(context, 'Created Agents'),
          count: created.length,
        ),
        const SizedBox(height: 12),
        if (created.isEmpty)
          Text(
            raftText(context, 'No created agents'),
            style: value.copyWith(
              fontStyle: FontStyle.italic,
              color: raftPanelInk(t, .4, t.colors['foreground-muted']!),
            ),
          )
        else
          for (final a in created) ...[
            AgentListRow(
              name: '${a['displayName'] ?? a['name']}',
              avatarUrl: a['avatarUrl'] as String?,
              subtitle: sourceRuntimeDisplayNames['${a['runtime']}'],
            ),
            const SizedBox(height: 8),
          ],
      ]),
      if (canRemove)
        block([
          RaftSectionEyebrow(raftText(context, 'Actions')),
          const SizedBox(height: 12),
          RaftRecipeActionButton(
            label: raftText(context, 'Remove Member'),
            glyph: RaftGlyph.trash2,
            onPressed: busy
                ? null
                : () => run(() => roleOrRemove('remove'), refresh: false),
          ),
        ]),
    ];
  }
}

/// `<Button size="sm" variant="danger" className="flex w-full items-center
/// justify-center gap-2 px-4 py-2 text-sm font-bold">` from the generated
/// buttonVariants recipe.
class RaftRecipeActionButton extends StatefulWidget {
  const RaftRecipeActionButton({
    super.key,
    required this.label,
    this.glyph,
    this.onPressed,
  });
  final String label;
  final RaftGlyph? glyph;
  final VoidCallback? onPressed;
  @override
  State<RaftRecipeActionButton> createState() => _RaftRecipeActionButtonState();
}

class _RaftRecipeActionButtonState extends State<RaftRecipeActionButton> {
  bool hovered = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftButtonRecipe.resolve(
      theme: raftRecipeTheme(t),
      variant: RaftButtonRecipeVariant.danger,
      size: RaftButtonRecipeSize.sm,
      states: RaftRecipeStates({
        if (hovered) RaftRecipeStates.hover,
        if (pressed) RaftRecipeStates.active,
        if (widget.onPressed == null) RaftRecipeStates.disabled,
        if (t.dark) RaftRecipeStates.dark,
      }),
      tokens: rt,
    ).root;
    final text = raftCssText(
      RaftTypography.body(t, size: 14, line: 20, weight: FontWeight.w700)
          .merge(s.textStyle(rt).copyWith(fontSize: 14, height: 20 / 14)),
    );
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          onTap: widget.onPressed,
          child: Opacity(
            opacity: s.opacity ?? 1,
            child: Transform.translate(
              offset: s.translate ?? Offset.zero,
              child: Container(
                height: s.height,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: s.decoration(rt),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.glyph != null) ...[
                      RaftIcon(widget.glyph!, size: 14, color: text.color),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
