// Channel members: the Web ChannelMembers "modal" presentation
// (packages/web/src/components/agent/ChannelMembers.tsx) — a header trigger
// (Users + participant count) opening a Modal Card `max-w-sm p-6` with the
// roster and the staged multi-select "Add Member" view (search, AGENTS /
// HUMANS candidates with CheckMarker + AvatarSlot compact-list, pinned
// "Create a New Agent" entry, "Add selected (N)").
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftButtonRecipeVariant, RaftButtonRecipeSize;

import '../data/workspace_controller.dart';
import 'channel_form_fields.dart';
import 'create_channel_dialog.dart';

/// Agent activity for the compact-list badge: the row's `activity` when the
/// payload carries one, else `agentStatusFallbackActivity(status)`.
RaftAvatarPresence? _presence(Map<String, dynamic> json) {
  final activity = json['activity'];
  final value = switch (activity) {
    'online' => RaftAvatarActivity.online,
    'thinking' => RaftAvatarActivity.thinking,
    'working' => RaftAvatarActivity.working,
    'error' => RaftAvatarActivity.error,
    'offline' => RaftAvatarActivity.offline,
    _ =>
      json['status'] == 'active'
          ? RaftAvatarActivity.online
          : RaftAvatarActivity.offline,
  };
  return RaftAvatarPresence(activity: value);
}

/// Header trigger: `Button size="sm" className="min-w-7 gap-1 px-1.5"` with
/// `Users size={14}` and the mono participant count.
class ChannelMembersButton extends StatefulWidget {
  const ChannelMembersButton({
    super.key,
    required this.controller,
    required this.channel,
  });
  final WorkspaceController controller;
  final RaftChannel channel;
  @override
  State<ChannelMembersButton> createState() => _ChannelMembersButtonState();
}

class _ChannelMembersButtonState extends State<ChannelMembersButton> {
  int? count;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final roster = await widget.controller.query(
        '/channels/${widget.channel.id}/members',
      );
      if (!mounted) return;
      setState(
        () => count =
            ((roster['humans'] as List?)?.length ?? 0) +
            ((roster['agents'] as List?)?.length ?? 0),
      );
    } catch (_) {
      if (mounted) setState(() => count = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final n = count;
    return RaftRecipeButton(
      key: const ValueKey('channel-members-open'),
      size: RaftButtonRecipeSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      gap: 4,
      tooltip: raftText(context, 'View participants'),
      onPressed: () async {
        await ChannelMembers.show(
          context,
          controller: widget.controller,
          channel: widget.channel,
        );
        refresh();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RaftIcon(RaftGlyph.users, size: 14),
          const SizedBox(width: 4),
          n == null
              ? const RaftSpinner(size: 12)
              : Text(
                  n > 99 ? '99+' : '$n',
                  style: TextStyle(
                    fontFamily: t.monoFont,
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ],
      ),
    );
  }
}

class ChannelMembers extends StatefulWidget {
  const ChannelMembers({
    super.key,
    required this.controller,
    required this.channel,
  });
  final WorkspaceController controller;
  final RaftChannel channel;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    required RaftChannel channel,
  }) => showRaftModal<void>(
    context,
    builder: (_) => ChannelMembers(controller: controller, channel: channel),
  );

  @override
  State<ChannelMembers> createState() => _ChannelMembersState();
}

class _ChannelMembersState extends State<ChannelMembers> {
  WorkspaceController get w => widget.controller;
  RaftChannel get channel => widget.channel;
  List<Map<String, dynamic>> humans = [], agents = [];
  List<ChannelMemberCandidate> candidates = [];
  final Map<String, Map<String, dynamic>> agentRows = {};
  bool loading = true, adding = false, addView = false;
  String? error;
  final selected = <String>{};
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final roster = await w.query('/channels/${channel.id}/members');
      final pool = await loadChannelMemberCandidates(w);
      final rawAgents = await w.query('/agents');
      if (!mounted) return;
      setState(() {
        humans = [
          for (final h in (roster['humans'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(h),
        ];
        agents = [
          for (final a in (roster['agents'] as List? ?? []).whereType<Map>())
            Map<String, dynamic>.from(a),
        ];
        for (final a in (rawAgents as List? ?? const []).whereType<Map>()) {
          agentRows['${a['id']}'] = Map<String, dynamic>.from(a);
        }
        final inChannel = {
          for (final h in humans) 'human:${h['userId'] ?? h['id']}',
          for (final a in agents) 'agent:${a['id']}',
        };
        // The add view also lists the signed-in user's server peers only.
        candidates = [
          for (final c in pool)
            if (!inChannel.contains('${c.kind}:${c.id}')) c,
        ];
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  bool get canAdd =>
      w.can('addChannelMembers', resource: channel) && !channel.archived;

  Future<void> confirmAdd() async {
    if (adding || selected.isEmpty) return;
    setState(() {
      adding = true;
      error = null;
    });
    try {
      await w.command(
        'POST',
        '/channels/${channel.id}/members/batch',
        data: {
          'userIds': [
            for (final k in selected)
              if (k.startsWith('human:')) k.substring(6),
          ],
          'agentIds': [
            for (final k in selected)
              if (k.startsWith('agent:')) k.substring(6),
          ],
        },
      );
      selected.clear();
      addView = false;
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = raftText(
            context,
            'Some selected members could not be added. They remain selected — press Add again to retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> remove(String kind, String id) async {
    try {
      await w.command(
        'DELETE',
        '/channels/${channel.id}/members/${kind == 'agent' ? 'agent' : 'user'}/$id',
      );
      await load();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final total = humans.length + agents.length;
    final header = Padding(
      padding: const EdgeInsets.only(bottom: 16), // mb-4
      child: Row(
        children: [
          if (addView) ...[
            RaftRecipeButton(
              key: const ValueKey('add-member-back'),
              glyph: RaftGlyph.arrowLeft,
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.all(4),
              tooltip: raftText(context, 'Back to members'),
              onPressed: () => setState(() {
                addView = false;
                selected.clear();
                search.clear();
              }),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              addView
                  ? raftText(context, 'Add Member')
                  : loading
                  ? raftText(context, 'Members')
                  : '${raftText(context, 'Members')} ($total)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: raftCssTextStyle(
                family: t.headingFont,
                step: RaftTextSteps.lg,
                weight: FontWeight.w700,
                color: t.strong,
              ),
            ),
          ),
          if (!addView && !loading && canAdd) ...[
            RaftRecipeButton(
              key: const ValueKey('add-member-open'),
              glyph: RaftGlyph.plus,
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.all(4),
              tooltip: raftText(context, 'Add Member'),
              disabled: candidates.isEmpty,
              onPressed: () => setState(() => addView = true),
            ),
            const SizedBox(width: 6),
          ],
          RaftCloseButton(onPressed: close, tooltip: 'Close channel settings'),
        ],
      ),
    );
    return RaftModalBackdrop(
      child: RaftRecipeCard(
        maxWidth: 384, // max-w-sm
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (error != null) ...[
              ChannelFormBanner(error!),
              const SizedBox(height: 12),
            ],
            if (addView) ..._addView(t) else _roster(t),
          ],
        ),
      ),
    );
  }

  Widget _roster(RaftTokens t) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: RaftSpinner()),
      );
    }
    final canRemove =
        w.can('removeChannelMembers', resource: channel) && !channel.archived;
    Widget row(String kind, Map<String, dynamic> m) {
      final id = '${kind == 'agent' ? m['id'] : (m['userId'] ?? m['id'])}';
      final candidate = ChannelMemberCandidate(
        kind: kind,
        id: id,
        name: '${m['name'] ?? ''}',
        displayName: m['displayName'] as String?,
        avatarUrl: m['avatarUrl'] as String?,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ChannelCandidateAvatar(
              candidate: candidate,
              avatarContext: RaftMountedAvatarContext.compactList,
              origin: w.client.origin,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                candidate.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.sm,
                  weight: FontWeight.w500,
                  color: t.strong,
                ),
              ),
            ),
            if (canRemove)
              RaftIconButton(
                glyph: RaftGlyph.x,
                tooltip: 'Remove ${candidate.label}',
                visualSize: 24,
                onPressed: () => remove(kind, id),
              ),
          ],
        ),
      );
    }

    final eyebrowFill = t.brutal
        ? Colors.white.withValues(alpha: .5)
        : t.colors['fill-muted'];
    return RaftRecipeCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 288),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (humans.isNotEmpty) ...[
                RaftSectionEyebrow(
                  'Humans',
                  uppercase: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (final h in humans) row('human', h),
              ],
              if (agents.isNotEmpty) ...[
                RaftSectionEyebrow(
                  'Agents',
                  uppercase: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  background: eyebrowFill,
                ),
                for (final a in agents) row('agent', a),
              ],
              if (humans.isEmpty && agents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    raftText(context, 'No members'),
                    textAlign: TextAlign.center,
                    style: raftCssTextStyle(
                      family: t.monoFont,
                      step: RaftTextSteps.sm,
                      color: t.colors['foreground-muted'],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _addView(RaftTokens t) {
    final query = search.text;
    final agentRowsShown = [
      for (final c in candidates)
        if (c.kind == 'agent' && c.matches(query)) c,
    ];
    final humanRowsShown = [
      for (final c in candidates)
        if (c.kind == 'human' && c.matches(query)) c,
    ];
    Widget eyebrow(String text) => RaftSectionEyebrow(
      text,
      uppercase: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      background: t.brutal
          ? Colors.white.withValues(alpha: .5)
          : t.colors['fill-muted'],
      color: t.brutal ? Colors.black : null,
    );
    Widget candidateRow(ChannelMemberCandidate c) {
      final key = '${c.kind}:${c.id}';
      return _CandidateRow(
        key: ValueKey('add-candidate-$key'),
        candidate: c,
        checked: selected.contains(key),
        disabled: adding,
        origin: w.client.origin,
        presence: c.kind == 'agent' && agentRows[c.id] != null
            ? _presence(agentRows[c.id]!)
            : null,
        onTap: () => setState(() {
          if (!selected.remove(key)) selected.add(key);
        }),
      );
    }

    final mutedText = raftCssTextStyle(
      family: t.monoFont,
      step: RaftTextSteps.sm,
      color: t.colors['foreground-muted'],
    );
    final canCreate = w.can('createAgents');
    final list = Container(
      // flex flex-col border bg-layer-panel shadow-raft-sm, brutal border-2
      // border-black bg-white shadow-brutal-sm, max-h-72.
      constraints: const BoxConstraints(maxHeight: 288),
      decoration: BoxDecoration(
        color: t.brutal ? Colors.white : t.panel,
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-muted']!,
          width: t.brutal ? 2 : 1,
        ),
        boxShadow: t.brutal ? RaftShadowSet.brutalSm : t.themeShadows.sm.outer,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (agentRowsShown.isNotEmpty) ...[
                    eyebrow('Agents'),
                    for (final c in agentRowsShown) candidateRow(c),
                  ],
                  if (humanRowsShown.isNotEmpty) ...[
                    eyebrow('Humans'),
                    for (final c in humanRowsShown) candidateRow(c),
                  ],
                  if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Text(
                        raftText(context, 'All members added'),
                        textAlign: TextAlign.center,
                        style: mutedText,
                      ),
                    )
                  else if (agentRowsShown.isEmpty && humanRowsShown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: Text(
                        raftText(context, 'No matches for "${query.trim()}"'),
                        textAlign: TextAlign.center,
                        style: mutedText,
                      ),
                    ),
                ],
              ),
            ),
          ),
          _CreateAgentEntry(
            channelName: channel.name,
            enabled: canCreate && !adding,
          ),
        ],
      ),
    );
    return [
      if (selected.isNotEmpty) ...[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final key in selected)
              _SelectedChip(
                label:
                    candidates
                        .where((c) => '${c.kind}:${c.id}' == key)
                        .firstOrNull
                        ?.label ??
                    key,
                agent: key.startsWith('agent:'),
                onRemove: adding
                    ? null
                    : () => setState(() => selected.remove(key)),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
      if (candidates.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12), // mb-3
          child: RaftProductFormField(
            label: 'Search',
            uppercase: false,
            child: ChannelTextInput(
              controller: search,
              placeholder: 'Name',
              leadingGlyph: RaftGlyph.search,
              autofocus: true,
            ),
          ),
        ),
      list,
      const SizedBox(height: 16), // mt-4
      RaftRecipeButton(
        key: const ValueKey('add-member-confirm'),
        label: adding
            ? 'Adding…'
            : '${raftText(context, 'Add selected')} (${selected.length})',
        glyph: RaftGlyph.plus,
        glyphSize: 14,
        variant: RaftButtonRecipeVariant.primary,
        expand: true,
        gap: 6,
        // px-3 py-1.5 text-sm font-bold; theme-brutal:bg-brutal-pink.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStep: RaftTextSteps.sm,
        disabled: adding || selected.isEmpty,
        foreground: t.brutal ? Colors.black : null,
        brutalSurface: (t, hovered) => BoxDecoration(
          color: t.colors['color-brutal-pink'],
          border: Border.all(color: t.colors['line-strong']!, width: 2),
          boxShadow: hovered
              ? t.themeShadows.md.outer
              : t.themeShadows.sm.outer,
        ),
        onPressed: confirmAdd,
      ),
    ];
  }
}

/// Multi-select candidate: `flex w-full items-center gap-2 px-3 py-2`,
/// CheckMarker sm, AvatarSlot compact-list (+ activity badge) and the
/// name / truncated description (description carries a Tooltip).
class _CandidateRow extends StatefulWidget {
  const _CandidateRow({
    super.key,
    required this.candidate,
    required this.checked,
    required this.disabled,
    required this.onTap,
    required this.origin,
    this.presence,
  });
  final ChannelMemberCandidate candidate;
  final bool checked, disabled;
  final VoidCallback onTap;
  final String origin;
  final RaftAvatarPresence? presence;
  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final c = widget.candidate;
    final description = c.description?.trim();
    final fill = hovered && !widget.disabled
        ? (t.brutal ? t.colors['color-soft-signal'] : t.colors['fill-muted'])
        : null;
    final ink = t.brutal ? Colors.black : t.strong;
    return Semantics(
      button: true,
      toggled: widget.checked,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.disabled ? null : widget.onTap,
          child: Opacity(
            opacity: widget.disabled ? .6 : 1,
            child: Container(
              color: fill,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _CheckMarker(checked: widget.checked),
                  const SizedBox(width: 8),
                  ChannelCandidateAvatar(
                    candidate: c,
                    avatarContext: RaftMountedAvatarContext.compactList,
                    origin: widget.origin,
                    presence: widget.presence,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: raftCssTextStyle(
                            family: t.headingFont,
                            step: RaftTextSteps.sm,
                            weight: FontWeight.w500,
                            color: ink,
                          ),
                        ),
                        if (description != null && description.isNotEmpty)
                          RaftTooltip(
                            message: description,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: raftCssTextStyle(
                                  family: t.headingFont,
                                  step: RaftTextSteps.xs,
                                  color: t.colors['foreground-muted'],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web CheckMarker sm: `size-3.5 border border-line-strong
/// theme-brutal:border-2 theme-brutal:border-black`, checked black fill with
/// a white `Check size={10} strokeWidth={4}`.
class _CheckMarker extends StatelessWidget {
  const _CheckMarker({required this.checked});
  final bool checked;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked
            ? (t.brutal ? Colors.black : t.strong)
            : (t.brutal ? Colors.white : t.panel),
        border: Border.all(
          color: t.brutal ? Colors.black : t.colors['line-strong']!,
          width: t.brutal ? 2 : 1,
        ),
      ),
      child: checked
          ? RaftIcon(
              RaftGlyph.check,
              size: 10,
              strokeWidth: 4,
              color: t.brutal ? Colors.white : t.colors['foreground-inverse'],
            )
          : null,
    );
  }
}

/// Pinned "Create a New Agent" footer: `border-t-2 border-black px-3
/// py-2.5 gap-2.5`, dashed `size-6` plus tile, bold title + auto-join line.
class _CreateAgentEntry extends StatelessWidget {
  const _CreateAgentEntry({required this.channelName, required this.enabled});
  final String channelName;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ink = t.brutal ? Colors.black : t.strong;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.brutal ? Colors.white : t.panel,
          border: Border(
            top: BorderSide(
              color: t.brutal ? Colors.black : t.colors['line-strong']!,
              width: t.brutal ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: CustomPaint(
                painter: _DashedBoxPainter(
                  color: t.brutal ? Colors.black : t.colors['line-strong']!,
                  width: t.brutal ? 2 : 1,
                ),
                child: Center(
                  child: RaftIcon(RaftGlyph.plus, size: 14, color: ink),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raftText(context, 'Create a New Agent'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.sm,
                      weight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  Text(
                    raftText(
                      context,
                      'Joins #$channelName automatically after creation',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.xs,
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .5)
                          : t.colors['foreground-muted'],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    // CSS dashed: dash length = 2 * border width, centred on each edge.
    final dash = width * 2;
    final inset = width / 2;
    void edge(Offset a, Offset b) {
      final length = (b - a).distance;
      final dir = (b - a) / length;
      for (double d = 0; d < length; d += dash * 2) {
        canvas.drawLine(
          a + dir * d,
          a + dir * (d + dash).clamp(0, length),
          paint,
        );
      }
    }

    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - width,
      size.height - width,
    );
    edge(r.topLeft, r.topRight);
    edge(r.topRight, r.bottomRight);
    edge(r.bottomRight, r.bottomLeft);
    edge(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBoxPainter old) =>
      old.color != color || old.width != width;
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({
    required this.label,
    required this.agent,
    required this.onRemove,
  });
  final String label;
  final bool agent;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final fill = t.brutal
        ? t.colors[agent ? 'color-brutal-cyan' : 'color-brutal-lavender']
        : t.colors[agent ? 'info-soft' : 'accent-soft'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        border: t.brutal ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: raftCssTextStyle(
                family: t.headingFont,
                step: RaftTextSteps.xs,
                weight: FontWeight.w700,
                color: t.brutal ? Colors.black : t.strong,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const RaftIcon(RaftGlyph.x, size: 12),
          ),
        ],
      ),
    );
  }
}
