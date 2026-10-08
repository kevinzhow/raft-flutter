// Create-channel dialog: the Web CreateChannelDialog
// (packages/web/src/components/channel/CreateChannelDialog.tsx) — DialogCard
// with Name, Description (optional), Visibility (Public/Private segmented
// control), Members (optional) search + AGENTS/HUMANS picker, Cancel/Create.
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart'
    show RaftButtonRecipeVariant, RaftButtonRecipeSize;

import '../data/workspace_controller.dart';
import 'channel_form_fields.dart';

/// One selectable member row of the picker (an agent or a human).
@immutable
class ChannelMemberCandidate {
  const ChannelMemberCandidate({
    required this.kind,
    required this.id,
    required this.name,
    this.displayName,
    this.description,
    this.avatarUrl,
  });
  final String kind; // 'agent' | 'human'
  final String id, name;
  final String? displayName, description, avatarUrl;
  String get label =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : name;
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        (displayName ?? '').toLowerCase().contains(q);
  }
}

/// Agents (not deleted) and server members other than the signed-in user,
/// from the same endpoints the Web stores load (`/agents`,
/// `/servers/:id/members`).
Future<List<ChannelMemberCandidate>> loadChannelMemberCandidates(
  WorkspaceController w,
) async {
  final serverId = w.server?.id;
  final values = await Future.wait([
    w.query('/agents'),
    if (serverId != null) w.query('/servers/$serverId/members'),
  ]);
  final me = w.client.user?.id;
  return [
    for (final a in (values[0] as List? ?? const []).whereType<Map>())
      if (a['deletedAt'] == null)
        ChannelMemberCandidate(
          kind: 'agent',
          id: '${a['id']}',
          name: '${a['name'] ?? ''}',
          displayName: a['displayName'] as String?,
          description: a['description'] as String?,
          avatarUrl: a['avatarUrl'] as String?,
        ),
    if (values.length > 1)
      for (final m in (values[1] as List? ?? const []).whereType<Map>())
        if ((m['userId'] ?? m['id']) != me)
          ChannelMemberCandidate(
            kind: 'human',
            id: '${m['userId'] ?? m['id']}',
            name: '${m['name'] ?? ''}',
            displayName: m['displayName'] as String?,
            description: m['description'] as String?,
            avatarUrl: m['avatarUrl'] as String?,
          ),
  ];
}

class CreateChannelDialog extends StatefulWidget {
  const CreateChannelDialog({
    super.key,
    required this.controller,
    this.prefilledName,
    this.prefilledDescription,
    this.prefilledVisibility = 'public',
    this.prefilledAgentIds = const [],
    this.prefilledHumanIds = const [],
    this.onCreated,
  });
  final WorkspaceController controller;
  final String? prefilledName, prefilledDescription;
  final String prefilledVisibility;
  final List<String> prefilledAgentIds, prefilledHumanIds;
  final Future<void> Function(RaftChannel channel)? onCreated;

  static Future<void> show(
    BuildContext context, {
    required WorkspaceController controller,
    Future<void> Function(RaftChannel channel)? onCreated,
  }) => showRaftModal<void>(
    context,
    builder: (_) =>
        CreateChannelDialog(controller: controller, onCreated: onCreated),
  );

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  WorkspaceController get w => widget.controller;
  late final name = TextEditingController(text: widget.prefilledName ?? '');
  late final description = TextEditingController(
    text: widget.prefilledDescription ?? '',
  );
  final search = TextEditingController();
  late String visibility = widget.prefilledVisibility;
  late final Set<String> agentIds = {...widget.prefilledAgentIds};
  late final Set<String> humanIds = {...widget.prefilledHumanIds};
  List<ChannelMemberCandidate> candidates = const [];
  bool submitting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    loadChannelMemberCandidates(w).then((value) {
      if (mounted) setState(() => candidates = value);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    search.dispose();
    super.dispose();
  }

  void close() => Navigator.of(context).maybePop();

  Future<void> submit() async {
    if (submitting) return;
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = raftText(context, 'Channel name is required.'));
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final result = await w.command(
        'POST',
        '/channels',
        data: {
          'name': trimmed,
          if (description.text.trim().isNotEmpty)
            'description': description.text.trim(),
          'visibility': visibility,
          'type': 'channel',
          'agentIds': [...agentIds],
          'userIds': [...humanIds],
        },
      );
      await w.refreshChannels();
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onCreated?.call(
        RaftChannel(Map<String, dynamic>.from(result as Map)),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RaftApiException
              ? e.message
              : raftText(context, 'Failed to create channel'),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final agents = [
      for (final c in candidates)
        if (c.kind == 'agent' && c.matches(search.text)) c,
    ];
    final humans = [
      for (final c in candidates)
        if (c.kind == 'human' && c.matches(search.text)) c,
    ];
    // space-y-4 between the form's direct children.
    const gap = SizedBox(height: 16);
    return RaftModalBackdrop(
      child: RaftDialogCard(
        title: 'Create Channel',
        onClose: close,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[ChannelFormBanner(error!), gap],
            RaftProductFormField(
              label: 'Name',
              required: true,
              child: ChannelTextInput(
                controller: name,
                placeholder: 'e.g. ai-research',
                autofocus: true,
                onSubmitted: (_) => submit(),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Description',
              optional: true,
              child: ChannelTextInput(
                controller: description,
                placeholder: 'What is this channel about?',
                multiline: true,
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Visibility',
              child: Align(
                alignment: Alignment.centerLeft,
                child: RaftRecipeSegmentedControl<String>(
                  label: raftText(context, 'Channel visibility'),
                  value: visibility,
                  items: const [
                    ('public', RaftGlyph.hash, 'Public'),
                    ('private', RaftGlyph.lock, 'Private'),
                  ],
                  onChanged: submitting
                      ? null
                      : (v) => setState(() => visibility = v),
                ),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Members',
              optional: true,
              child: candidates.isEmpty
                  ? Text(
                      raftText(context, 'No members available'),
                      style: raftCssTextStyle(
                        family: t.monoFont,
                        step: RaftTextSteps.sm,
                        color: t.colors['foreground-muted'],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChannelTextInput(
                          controller: search,
                          placeholder: 'Search members by name',
                          leadingGlyph: RaftGlyph.search,
                        ),
                        const SizedBox(height: 8), // space-y-2
                        _MemberPicker(
                          agents: agents,
                          humans: humans,
                          selected: (c) =>
                              (c.kind == 'agent' ? agentIds : humanIds)
                                  .contains(c.id),
                          query: search.text,
                          onToggle: submitting
                              ? null
                              : (c) => setState(() {
                                  final set = c.kind == 'agent'
                                      ? agentIds
                                      : humanIds;
                                  if (!set.remove(c.id)) set.add(c.id);
                                }),
                        ),
                      ],
                    ),
            ),
            gap,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RaftRecipeButton(
                  label: 'Cancel',
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  // px-4 py-2 text-sm
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStep: RaftTextSteps.sm,
                  disabled: submitting,
                  onPressed: close,
                ),
                const SizedBox(width: 12), // gap-3
                RaftRecipeButton(
                  label: submitting ? 'Creating…' : 'Create Channel',
                  variant: RaftButtonRecipeVariant.accent,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStep: RaftTextSteps.sm,
                  disabled: submitting,
                  onPressed: submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `Card max-h-48 overflow-y-auto` with SectionEyebrow headers
/// (`px-3 py-1.5 bg-fill-muted theme-brutal:bg-white/50`) and member rows.
class _MemberPicker extends StatelessWidget {
  const _MemberPicker({
    required this.agents,
    required this.humans,
    required this.selected,
    required this.onToggle,
    required this.query,
  });
  final List<ChannelMemberCandidate> agents, humans;
  final bool Function(ChannelMemberCandidate) selected;
  final ValueChanged<ChannelMemberCandidate>? onToggle;
  final String query;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final eyebrowFill = t.brutal
        ? Colors.white.withValues(alpha: .5)
        : t.colors['fill-muted'];
    Widget eyebrow(String text) => RaftSectionEyebrow(
      text,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      background: eyebrowFill,
    );
    return RaftRecipeCard(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 192 - 4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agents.isNotEmpty) ...[
                eyebrow('Agents'),
                for (final c in agents)
                  _MemberRow(
                    candidate: c,
                    selected: selected(c),
                    onTap: onToggle == null ? null : () => onToggle!(c),
                  ),
              ],
              if (humans.isNotEmpty) ...[
                eyebrow('Humans'),
                for (final c in humans)
                  _MemberRow(
                    candidate: c,
                    selected: selected(c),
                    onTap: onToggle == null ? null : () => onToggle!(c),
                  ),
              ],
              if (agents.isEmpty && humans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    raftText(context, 'No matches for "${query.trim()}"'),
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
}

/// `flex w-full items-center gap-2 px-3 py-1.5 text-sm font-medium`; selected
/// `bg-accent-soft theme-brutal:bg-brutal-pink/20`, hover
/// `hover:bg-primary-soft theme-brutal:hover:bg-soft-signal`.
class _MemberRow extends StatefulWidget {
  const _MemberRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });
  final ChannelMemberCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;
  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final pink = t.colors['color-brutal-pink']!;
    final fill = widget.selected
        ? (t.brutal ? pink.withValues(alpha: .2) : t.colors['accent-soft'])
        : hovered
        ? (t.brutal ? t.colors['color-soft-signal'] : t.colors['primary-soft'])
        : null;
    final c = widget.candidate;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            color: fill,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                ChannelCandidateAvatar(
                  candidate: c,
                  avatarContext: RaftMountedAvatarContext.sidebarList,
                  humanPlaceholder: true,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.sm,
                      weight: FontWeight.w500,
                      color: t.brutal ? Colors.black : t.strong,
                    ),
                  ),
                ),
                if (widget.selected) ...[
                  const SizedBox(width: 8),
                  RaftIcon(RaftGlyph.check, size: 14, color: pink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
