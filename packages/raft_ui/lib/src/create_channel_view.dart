import 'overlays/dialog.dart' show RaftDialog;
// Presentation of the Web CreateChannelDialog
// (packages/web/src/components/channel/CreateChannelDialog.tsx): DialogCard
// with Name, Description (optional), Visibility segmented control, Members
// (optional) search + AGENTS/HUMANS picker and Cancel/Create Channel. The app
// adapter owns loading, selection state and the create command.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption;
import 'card.dart' show RaftCard;
import 'banner.dart' show RaftBanner;
import 'design_primitives.dart' show RaftInteractive;

import 'package:flutter/material.dart';

import 'form_presentation.dart';

import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipe_surface.dart';
import 'raft/button.dart';
import 'raft/checkbox.dart' show RaftCheckboxIndicator;
import 'recipes/web_member_picker.g.dart';
import 'separator.dart';
import 'settings_layout.dart' show RaftSpace;
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
      child: RaftDialog.card(
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
        // Current Web: `flex flex-wrap justify-end gap-2 pt-1`, with two
        // recipe-sized lg buttons.
        footer: Padding(
          padding: const EdgeInsets.only(top: RaftSpace.x1),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: [
              RaftButton(
                label: 'Cancel',
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.lg,
                onPressed: submitting
                    ? null
                    : raftExplicitClose(context, onClose),
              ),
              RaftButton(
                label: submitting ? 'Creating…' : 'Create Channel',
                uiVariant: RaftButtonVariant.accent,
                uiSize: RaftButtonSize.lg,
                onPressed: submitting ? null : onSubmit,
              ),
            ],
          ),
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
        raftText(context, 'No members to add'),
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
        _RecipeMemberPicker(
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

/// Current Web member-picker composition, extracted from its product source:
/// `Card max-h-48 overflow-y-auto` with group headers and member rows.
class _RecipeMemberPicker extends StatelessWidget {
  const _RecipeMemberPicker({
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
    final tokens = t.recipeTokens;
    final recipe = RaftWebMemberPickerRecipe.resolve(
      states: t.recipeStates(),
      tokens: tokens,
    );
    Widget group(String label) => RaftRecipeBox(
      style: recipe.group,
      tokens: tokens,
      applyText: false,
      child: Text(
        raftText(context, label),
        style: recipe.group.text(
          tokens,
          base: TextStyle(fontFamily: t.headingFont),
        ),
      ),
    );
    Widget row(RaftPickerItem candidate) => _RecipeMemberRow(
      candidate: candidate,
      selected: selected(candidate.key),
      onTap: onToggle == null ? null : () => onToggle!(candidate.key),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            (recipe.scroller.maxHeight ?? double.infinity) +
            recipe.root.borderWidth.vertical,
      ),
      child: RaftCard(
        padding: recipe.scroller.padding,
        clip: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: recipe.rows.rowGap ?? 0,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (agents.isNotEmpty) ...[
                group('Agents'),
                for (final candidate in agents) row(candidate),
              ],
              if (humans.isNotEmpty) ...[
                group('Humans'),
                for (final candidate in humans) row(candidate),
              ],
              if (agents.isEmpty && humans.isEmpty)
                RaftRecipeBox(
                  style: recipe.empty,
                  tokens: tokens,
                  applyText: false,
                  child: Text(
                    raftFormat(context, 'No members match "{query}"', {
                      'query': query.trim(),
                    }),
                    style: recipe.empty.text(
                      tokens,
                      base: TextStyle(fontFamily: t.headingFont),
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

class _RecipeMemberRow extends StatelessWidget {
  const _RecipeMemberRow({
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
    final tokens = t.recipeTokens;
    return RaftInteractive(
      onPressed: onTap,
      selected: selected,
      builder: (context, state) {
        final recipe = RaftWebMemberPickerRecipe.resolve(
          states: t.recipeStates(
            hovered: state.hovered,
            focusVisible: state.focusVisible,
          ),
          tokens: tokens,
        );
        final text = recipe.row.text(
          tokens,
          base: TextStyle(fontFamily: t.headingFont),
        );
        return RaftRecipeBox(
          style: recipe.row,
          tokens: tokens,
          applyText: false,
          child: Row(
            children: [
              RaftCheckboxIndicator(checked: selected),
              SizedBox(width: recipe.row.columnGap ?? 0),
              candidate.avatar,
              SizedBox(width: recipe.row.columnGap ?? 0),
              Expanded(
                child: Text(
                  candidate.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.label.text(tokens, base: text),
                ),
              ),
            ],
          ),
        );
      },
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
    return RaftBanner(
      titleBuilder: (style) => Text.rich(
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
        style: style,
      ),
      description: showHint
          ? canUnarchive
                ? 'Unarchive it to keep its history, or choose a different name.'
                : 'Pick a different name, or ask an admin to unarchive it.'
          : '',
      actions: [
        if (canUnarchive)
          RaftButton(
            label: busy && showHint ? 'Unarchiving…' : 'Unarchive',
            uiVariant: RaftButtonVariant.outline,
            uiSize: RaftButtonSize.sm,
            disabled: busy,
            onPressed: onUnarchive,
          ),
        RaftButton(
          label: 'Change name',
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.sm,
          onPressed: onChangeName,
        ),
      ],
    );
  }
}
