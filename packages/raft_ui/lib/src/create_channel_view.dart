// Presentation of the Web CreateChannelDialog
// (packages/web/src/components/channel/CreateChannelDialog.tsx): DialogCard
// with Name, Description (optional), Visibility segmented control, Members
// (optional) search + AGENTS/HUMANS picker and Cancel/Create Channel. The app
// adapter owns loading, selection state and the create command.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption, RaftSegmentedStyle;
import 'card.dart' show RaftCard;
import 'raft/checkbox.dart' show RaftCheckboxIndicator;
import 'raft/ui_tokens.dart';
import 'space.dart';
import 'control_typography.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'design_primitives.dart' show RaftInteractive;
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/banner.g.dart';
import 'recipes/button_variants.g.dart';
import 'separator.dart';
import 'error_presentation.dart' show RaftErrorBanner;
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
    this.notice,
    this.slackField,
    this.submitting = false,
  });
  final TextEditingController name, description, search;
  final String visibility;

  /// The Slack channel field (Web ChannelSlackBridgeField) under the members;
  /// null while the Slack bridge is not ready.
  final Widget? slackField;
  final ValueChanged<String> onVisibilityChanged;
  final List<RaftPickerItem> agents, humans;
  final bool hasCandidates, submitting;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClose, onSubmit;
  final String? error;

  /// Extra banner under [error] (the archived-name collision).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
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
            if (error != null) ...[RaftErrorBanner(error!), gap],
            if (notice != null) ...[notice!, gap],
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
                child: RaftSegmentedControl<String>(
                  legacyStyle: RaftSegmentedStyle.recipe,
                  label: raftText(context, 'Channel visibility'),
                  value: visibility,
                  items: const [
                    RaftSegmentedOption(
                      value: 'public',
                      glyph: RaftGlyph.hash,
                      label: 'Public',
                    ),
                    RaftSegmentedOption(
                      value: 'private',
                      glyph: RaftGlyph.lock,
                      label: 'Private',
                    ),
                  ],
                  onChanged: submitting ? null : onVisibilityChanged,
                ),
              ),
            ),
            gap,
            RaftProductFormField(
              label: 'Members',
              optional: true,
              child: RaftMemberPickerContent(
                search: search,
                agents: agents,
                humans: humans,
                hasCandidates: hasCandidates,
                isSelected: isSelected,
                onToggle: submitting ? null : onToggle,
              ),
            ),
            if (slackField != null) ...[
              gap,
              RaftSeparator(
                thickness: 1,
                color: RaftTokens.of(context).colors['line-muted'],
              ),
              gap,
              slackField!,
            ],
          ],
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RaftRecipeButton(
              label: 'Cancel',
              variant: RaftButtonRecipeVariant.outline,
              size: RaftButtonRecipeSize.sm,
              // px-4 py-2 text-sm
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStep: RaftTextSteps.sm,
              disabled: submitting,
              onPressed: raftExplicitClose(context, onClose),
            ),
            const SizedBox(width: 12), // gap-3
            RaftRecipeButton(
              label: submitting ? 'Creating…' : 'Create Channel',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStep: RaftTextSteps.sm,
              disabled: submitting,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The member picker body shared by the create dialogs: `No members
/// available`, or the search `Input` (`pl-9` + Search glyph) over the
/// `Card max-h-48` AGENTS / HUMANS list.
class RaftMemberPickerContent extends StatelessWidget {
  const RaftMemberPickerContent({
    super.key,
    required this.search,
    required this.agents,
    required this.humans,
    required this.hasCandidates,
    required this.isSelected,
    required this.onToggle,
  });
  final TextEditingController search;
  final List<RaftPickerItem> agents, humans;
  final bool hasCandidates;
  final bool Function(String key) isSelected;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (!hasCandidates) {
      return Text(
        raftText(context, 'No members available'),
        style: raftCssTextStyle(
          family: t.monoFont,
          step: RaftTextSteps.sm,
          color: t.colors['foreground-muted'],
        ),
      );
    }
    return Column(
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
          onToggle: onToggle,
        ),
      ],
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
    final raft = t.isRaftLook;
    final eyebrowFill = t.colors['fill-muted'];
    // Raft look (`PICKER_GROUP_LABEL_CLASS` px-2.5 pt-2 pb-1): a plain group label; the frozen looks band it.
    Widget eyebrow(String text) => raft
        ? RaftDialogSectionEyebrow(
            text,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          )
        : RaftDialogSectionEyebrow(
            text,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            background: eyebrowFill,
          );
    Widget row(RaftPickerItem c) => raft
        ? _RaftMemberRow(
            candidate: c,
            selected: selected(c.key),
            onTap: onToggle == null ? null : () => onToggle!(c.key),
          )
        : _MemberRow(
            candidate: c,
            selected: selected(c.key),
            onTap: onToggle == null ? null : () => onToggle!(c.key),
          );
    return RaftCard(
      padding: raft ? const EdgeInsets.all(RaftSpace.x1_5) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 192 - 4),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agents.isNotEmpty) ...[
                eyebrow('Agents'),
                for (final c in agents) row(c),
              ],
              if (humans.isNotEmpty) ...[
                eyebrow('Humans'),
                for (final c in humans) row(c),
              ],
              if (agents.isEmpty && humans.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  child: Text(
                    raftFormat(context, 'No matches for "{query}"', {
                      'query': query.trim(),
                    }),
                    textAlign: raft ? TextAlign.start : TextAlign.center,
                    style: raft
                        ? t.scale(
                            RaftTypeScale.callout,
                            color: t.ui.foregroundHint,
                          )
                        : raftCssTextStyle(
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

/// `PICKER_ROW_CLASS`: a multi-select option row (`flex min-h-9 w-full items-center gap-2.5 rounded-control px-2.5
/// text-callout font-medium`, `hover:bg-brand-soft`, a focus-ring inset `2px` ink) that carries its choice in a
/// `CheckboxIndicator` before the avatar and the name.
class _RaftMemberRow extends StatelessWidget {
  const _RaftMemberRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });
  final RaftPickerItem candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final ui = t.ui;
    return RaftInteractive(
      onPressed: onTap,
      selected: selected,
      builder: (context, st) => Container(
        constraints: const BoxConstraints(
          minHeight: RaftSpace.x6 + RaftSpace.x3,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: st.hovered || st.focusVisible ? ui['brand-soft'] : null,
          borderRadius: BorderRadius.circular(
            t.size('radius.control', fallback: 8),
          ),
          border: st.focusVisible
              ? Border.all(
                  color: ui.foreground,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : null,
        ),
        child: Row(
          spacing: 10,
          children: [
            RaftCheckboxIndicator(checked: selected),
            candidate.avatar,
            Expanded(
              child: Text(
                candidate.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RaftControlTypography.of(
                  context,
                  t.scale(
                    RaftTypeScale.callout,
                    weight: FontWeight.w500,
                    color: ui.foreground,
                  ),
                ),
              ),
            ),
          ],
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
        ? t.colors['accent-soft']
        : hovered
        ? t.colors['primary-soft']
        : null;
    final c = widget.candidate;
    return Semantics(
      button: true,
      selected: widget.selected,
      child: RaftHoverRegion(
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
                      color: t.strong,
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

/// CreateChannelDialog `archivedCollision` Banner (warning, `space-y-2`): the
/// name is held by an archived channel; Unarchive it or pick another name.
class RaftArchivedNameBanner extends StatelessWidget {
  const RaftArchivedNameBanner({
    super.key,
    required this.name,
    required this.canUnarchive,
    required this.onChangeName,
    this.onUnarchive,
    this.busy = false,
    this.showHint = true,
  });
  final String name;
  final bool canUnarchive, busy;

  /// CreateChannelDialog's second line; the joint dialog's banner has none.
  final bool showHint;
  final VoidCallback onChangeName;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final bold = raftCssTextStyle(
      family: t.headingFont,
      step: RaftTextSteps.sm,
      weight: FontWeight.w700,
      color: t.strong,
    );
    // The public Banner recipe's root (padding, border, fill), not a
    // hand-measured box.
    final tokens = t.recipeTokens;
    final recipe = RaftBannerRecipe.resolve(
      theme: t.recipeTheme,
      status: RaftBannerRecipeStatus.warning,
      states: t.recipeStates(),
      tokens: tokens,
    );
    return Semantics(
      liveRegion: true,
      child: RaftRecipeBox(
        style: recipe.root,
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                children: raftRichText(
                  context,
                  'The name <mono>#{name}</mono> is held by an archived channel.',
                  {
                    'mono': (text) => TextSpan(
                      text: text,
                      style: TextStyle(fontFamily: t.monoFont),
                    ),
                  },
                  values: {'name': name},
                ),
              ),
              style: bold,
            ),
            // Banner children carry no `space-y-2` gap (the Web wrapper sits
            // between the banner and its `<p>`s).
            if (showHint)
              Text(
                raftText(
                  context,
                  canUnarchive
                      ? 'Unarchive it to keep its history, or choose a different name.'
                      : 'Pick a different name, or ask an admin to unarchive it.',
                ),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  color: t.colors['foreground-muted'],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canUnarchive)
                  RaftRecipeButton(
                    label: raftText(
                      context,
                      busy ? 'Unarchiving…' : 'Unarchive',
                    ),
                    variant: RaftButtonRecipeVariant.success,
                    size: RaftButtonRecipeSize.sm,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    textStep: RaftTextSteps.xs,
                    disabled: busy,
                    onPressed: onUnarchive,
                  ),
                RaftRecipeButton(
                  label: raftText(context, 'Change Name'),
                  variant: RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.sm,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  textStep: RaftTextSteps.xs,
                  onPressed: onChangeName,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
