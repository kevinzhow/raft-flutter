// Presentation of the Web CreateChannelDialog
// (packages/web/src/components/channel/CreateChannelDialog.tsx): DialogCard
// with Name, Description (optional), Visibility segmented control, Members
// (optional) search + AGENTS/HUMANS picker and Cancel/Create Channel. The app
// adapter owns loading, selection state and the create command.
import 'package:flutter/material.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'theme.dart';

/// One selectable picker row: stable [key], [label], optional
/// [description] and the adapter-built `AvatarSlot` [avatar].
@immutable
class RaftPickerItem {
  const RaftPickerItem({
    required this.key,
    required this.label,
    required this.avatar,
    this.description,
  });
  final String key, label;
  final String? description;
  final Widget avatar;
}

class RaftCreateChannelDialogView extends StatelessWidget {
  const RaftCreateChannelDialogView({
    super.key,
    required this.name,
    required this.description,
    required this.search,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.agents,
    required this.humans,
    required this.hasCandidates,
    required this.isSelected,
    required this.onToggle,
    required this.onClose,
    required this.onSubmit,
    this.error,
    this.submitting = false,
  });
  final TextEditingController name, description, search;
  final String visibility;
  final ValueChanged<String> onVisibilityChanged;
  final List<RaftPickerItem> agents, humans;
  final bool hasCandidates, submitting;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClose, onSubmit;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // space-y-4 between the form's direct children.
    const gap = SizedBox(height: 16);
    return RaftModalBackdrop(
      child: RaftDialogCard(
        title: 'Create Channel',
        onClose: onClose,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[RaftWarningBanner(error!), gap],
            RaftProductFormField(
              label: 'Name',
              required: true,
              child: RaftDialogTextInput(
                controller: name,
                placeholder: 'e.g. ai-research',
                autofocus: true,
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Description',
              optional: true,
              child: RaftDialogTextInput(
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
                  onChanged: submitting ? null : onVisibilityChanged,
                ),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Members',
              optional: true,
              child: !hasCandidates
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
                        RaftDialogTextInput(
                          controller: search,
                          placeholder: 'Search members by name',
                          leadingGlyph: RaftGlyph.search,
                        ),
                        const SizedBox(height: 8), // space-y-2
                        _MemberPicker(
                          agents: agents,
                          humans: humans,
                          selected: isSelected,
                          query: search.text,
                          onToggle: submitting ? null : onToggle,
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
                  onPressed: onClose,
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
                  onPressed: onSubmit,
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
  final List<RaftPickerItem> agents, humans;
  final bool Function(String key) selected;
  final ValueChanged<String>? onToggle;
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
                    selected: selected(c.key),
                    onTap: onToggle == null ? null : () => onToggle!(c.key),
                  ),
              ],
              if (humans.isNotEmpty) ...[
                eyebrow('Humans'),
                for (final c in humans)
                  _MemberRow(
                    candidate: c,
                    selected: selected(c.key),
                    onTap: onToggle == null ? null : () => onToggle!(c.key),
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
  final RaftPickerItem candidate;
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
                c.avatar,
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
