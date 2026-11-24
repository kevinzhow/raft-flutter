import 'overlays/dialog.dart' show RaftDialog;
// Channel creation form and shared Web MemberChoiceList presentation.
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
import 'form_controls.dart' show RaftInputGroup, RaftInputGroupAddon;
import 'interaction.dart';
import 'recipes/choice_list.g.dart';
import 'raft/button.dart';
import 'raft/checkbox.dart' show RaftCheckboxIndicator;
import 'recipes/web_member_picker.g.dart';
import 'separator.dart';
import 'settings_layout.dart' show RaftSpace;
import 'error_presentation.dart' show RaftErrorBanner;
import 'theme.dart';
import 'tooltip.dart';

/// One selectable picker row: stable [key], [label], optional
/// [description] and the adapter-built `AvatarSlot` [avatar].
@immutable
class RaftPickerItem {
  const RaftPickerItem({
    required this.key,
    required this.label,
    required this.avatar,
    this.description,
    this.badge,
  });
  final String key, label;
  final String? description;
  final Widget avatar;
  final Widget? badge;
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
    this.matchedMemberKeys,
    this.notice,
    this.slackField,
    this.submitting = false,
    this.externalAvailable = false,
    this.externalReady = true,
    this.canContinue = true,
    this.twoStep = false,
    this.people = false,
    this.onBack,
    this.problemKey,
    this.visibilityHint,
    this.visibilityNotice,
  });
  final TextEditingController name, description, search;
  final String visibility;
  final bool externalAvailable, externalReady, canContinue, twoStep, people;
  final VoidCallback? onBack;
  final String? visibilityHint;
  final Widget? visibilityNotice;

  /// The Slack channel field (Web ChannelSlackBridgeField) under the members;
  /// null while the Slack bridge is not ready.
  final Widget? slackField;
  final ValueChanged<String> onVisibilityChanged;
  final List<RaftPickerItem> agents, humans;
  final List<String>? matchedMemberKeys;
  final bool hasCandidates, submitting;
  final bool Function(String key) isSelected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClose, onSubmit;
  final String? error;
  final Key? problemKey;

  /// Extra banner under [error] (the archived-name collision).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final sheet = RaftFormFrame.sheetOf(context);
    final submit = submitting || !canContinue ? null : onSubmit;
    final next = twoStep && !people || visibility == 'external';
    final submitLabel = switch ((next, submitting)) {
      (true, _) => 'Next',
      (_, true) => 'Creating…',
      _ => sheet ? 'Create' : 'Create Channel',
    };
    // space-y-4 between the form's direct children.
    const gap = SizedBox(height: 16);
    return RaftModalBackdrop(
      child: RaftDialog.card(
        title: people
            ? raftFormat(context, 'Add people to #{name}', {
                'name': name.text.trim(),
              })
            : sheet
            ? 'Create channel'
            : 'Create Channel',
        onClose: onClose,
        sheetCommit: RaftButton(
          label: submitLabel,
          uiVariant: RaftButtonVariant.primary,
          uiSize: RaftButtonSize.md,
          onPressed: submit,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              KeyedSubtree(key: problemKey, child: RaftErrorBanner(error!)),
              gap,
            ],
            if (notice != null) ...[
              KeyedSubtree(
                key: error == null ? problemKey : null,
                child: notice!,
              ),
              gap,
            ],
            if (!people) ...[
              RaftProductFormField(
                label: 'Name',
                required: true,
                child: RaftDialogTextInput(
                  fieldKey: const ValueKey('create-channel-name'),
                  controller: name,
                  placeholder: 'e.g. ai-research',
                  autofocus: true,
                  onSubmitted: submit == null ? null : (_) => submit(),
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
                hint: visibilityHint,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RaftSegmentedControl<String>(
                    label: raftText(context, 'Channel visibility'),
                    value: visibility,
                    items: [
                      const RaftSegmentedOption(
                        value: 'public',
                        glyph: RaftGlyph.hash,
                        label: 'Public',
                      ),
                      const RaftSegmentedOption(
                        value: 'private',
                        glyph: RaftGlyph.lock,
                        label: 'Private',
                      ),
                      if (externalAvailable)
                        RaftSegmentedOption(
                          value: 'external',
                          glyph: RaftGlyph.globe,
                          label: 'External',
                          enabled: externalReady,
                        ),
                    ],
                    onChanged: submitting ? null : onVisibilityChanged,
                  ),
                ),
              ),
              if (visibilityNotice != null) visibilityNotice!,
            ],
            if (!twoStep || people) ...[
              if (!people) gap,
              RaftProductFormField(
                label: 'Members',
                optional: true,
                child: RaftMemberPickerContent(
                  search: search,
                  agents: agents,
                  humans: humans,
                  matchedKeys: matchedMemberKeys,
                  hasCandidates: hasCandidates,
                  isSelected: isSelected,
                  onToggle: submitting ? null : onToggle,
                ),
              ),
            ],
            if (!people && slackField != null && visibility != 'external') ...[
              gap,
              RaftSeparator(
                thickness: 1,
                color: RaftTokens.of(context).colors['line-muted'],
              ),
              gap,
              slackField!,
            ],
            if (sheet && people) ...[
              gap,
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: RaftButton(
                  label: 'Back',
                  uiVariant: RaftButtonVariant.ghost,
                  onPressed: submitting ? null : onBack,
                ),
              ),
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
                label: people ? 'Back' : 'Cancel',
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.lg,
                onPressed: submitting
                    ? null
                    : people
                    ? onBack
                    : raftExplicitClose(context, onClose),
              ),
              RaftButton(
                label: submitLabel,
                uiVariant: RaftButtonVariant.accent,
                uiSize: RaftButtonSize.lg,
                onPressed: submit,
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
class RaftMemberPickerContent extends StatefulWidget {
  const RaftMemberPickerContent({
    super.key,
    required this.search,
    required this.agents,
    required this.humans,
    required this.hasCandidates,
    required this.isSelected,
    required this.onToggle,
    this.matchedKeys,
    this.footer,
    this.fill = false,
    this.showDescriptions = false,
    this.rowKeyPrefix = 'member-choice-',
    this.searchPlaceholder = 'Search members by name',
    this.emptyLabel = 'No members to add',
  });
  final TextEditingController search;
  final List<RaftPickerItem> agents, humans;
  final List<String>? matchedKeys;
  final bool hasCandidates, fill, showDescriptions;
  final bool Function(String key) isSelected;
  final ValueChanged<String>? onToggle;
  final Widget? footer;
  final String rowKeyPrefix, searchPlaceholder, emptyLabel;

  @override
  State<RaftMemberPickerContent> createState() => _MemberPickerContentState();
}

class _MemberPickerContentState extends State<RaftMemberPickerContent> {
  final focus = FocusNode();
  String? pinnedFor;
  Set<String> pinned = {};

  @override
  void initState() {
    super.initState();
    widget.search.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RaftMemberPickerContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      oldWidget.search.removeListener(changed);
      widget.search.addListener(changed);
    }
  }

  @override
  void dispose() {
    widget.search.removeListener(changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftChoiceListRecipe.resolve(
      fill: widget.fill,
      scroll: widget.hasCandidates && !widget.fill,
      states: t.recipeStates(
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
      tokens: t.recipeTokens,
    );
    final all = [...widget.agents, ...widget.humans];
    final query = widget.search.text;
    if (pinnedFor != query) {
      pinnedFor = query;
      pinned = {
        for (final item in all)
          if (widget.isSelected(item.key)) item.key,
      };
    }
    final byKey = {for (final item in all) item.key: item};
    final needle = query.trim().toLowerCase();
    final rankedKeys = widget.matchedKeys;
    final matches = needle.isEmpty
        ? all
        : rankedKeys != null
        ? [
            for (final key in rankedKeys)
              if (byKey[key] case final item?) item,
          ]
        : [
            for (final item in all)
              if ('${item.label} ${item.description ?? ''}'
                  .toLowerCase()
                  .contains(needle))
                item,
          ];
    final matched = matches.map((item) => item.key).toSet();
    final top = needle.isEmpty
        ? <RaftPickerItem>[]
        : [
            for (final item in all)
              if (pinned.contains(item.key) ||
                  (widget.isSelected(item.key) && !matched.contains(item.key)))
                item,
          ];
    final topKeys = top.map((item) => item.key).toSet();
    final visible = [
      ...top,
      for (final item in matches)
        if (!topKeys.contains(item.key)) item,
    ];
    final agentKeys = widget.agents.map((item) => item.key).toSet();
    final frame = _RecipeMemberPicker(
      agents: [
        for (final item in visible)
          if (agentKeys.contains(item.key)) item,
      ],
      humans: [
        for (final item in visible)
          if (!agentKeys.contains(item.key)) item,
      ],
      selected: widget.isSelected,
      query: query,
      onToggle: widget.onToggle,
      fill: widget.fill,
      footer: widget.footer,
      showDescriptions: widget.showDescriptions,
      rowKeyPrefix: widget.rowKeyPrefix,
      note: !widget.hasCandidates
          ? raftText(context, widget.emptyLabel)
          : needle.isNotEmpty && matches.isEmpty
          ? raftFormat(context, 'No members match "{query}"', {
              'query': query.trim(),
            })
          : null,
    );
    return Column(
      mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hasCandidates) ...[
          RaftInputGroup(
            controller: widget.search,
            focusNode: focus,
            enabled: widget.onToggle != null,
            semanticLabel: raftText(context, 'Search'),
            hintText: raftText(context, widget.searchPlaceholder),
            leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
            clearLabel: raftText(context, 'Clear search'),
            onClear: () {
              widget.search.clear();
              focus.requestFocus();
            },
          ),
          SizedBox(height: recipe.root.rowGap ?? 0),
        ],
        if (widget.fill) Expanded(child: frame) else frame,
      ],
    );
  }
}

class _RecipeMemberPicker extends StatelessWidget {
  const _RecipeMemberPicker({
    required this.agents,
    required this.humans,
    required this.selected,
    required this.onToggle,
    required this.query,
    required this.fill,
    required this.showDescriptions,
    required this.rowKeyPrefix,
    this.footer,
    this.note,
  });
  final List<RaftPickerItem> agents, humans;
  final bool Function(String key) selected;
  final ValueChanged<String>? onToggle;
  final String query, rowKeyPrefix;
  final bool fill, showDescriptions;
  final Widget? footer;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftWebMemberPickerRecipe.resolve(
      fill: fill,
      states: t.recipeStates(
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
      tokens: tokens,
    );
    final choice = RaftChoiceListRecipe.resolve(
      fill: fill,
      tokens: tokens,
      states: t.recipeStates(
        responsive: true,
        pointerCoarse: RaftInteraction.of(context).touch,
      ),
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
      key: ValueKey('$rowKeyPrefix${candidate.key}'),
      candidate: candidate,
      selected: selected(candidate.key),
      showDescription: showDescriptions,
      onTap: onToggle == null ? null : () => onToggle!(candidate.key),
    );
    final rows = SingleChildScrollView(
      padding: recipe.scroller.padding,
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
          if (note case final message?)
            RaftRecipeBox(
              style: recipe.empty,
              tokens: tokens,
              applyText: false,
              child: Text(
                message,
                style: recipe.empty.text(
                  tokens,
                  base: TextStyle(fontFamily: t.headingFont),
                ),
              ),
            ),
        ],
      ),
    );
    final scroller = fill
        ? rows
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: recipe.scroller.maxHeight ?? double.infinity,
            ),
            child: rows,
          );
    return RaftCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fill) Expanded(child: scroller) else scroller,
          if (footer != null)
            RaftRecipeBox(style: choice.footer, tokens: tokens, child: footer!),
        ],
      ),
    );
  }
}

class _RecipeMemberRow extends StatelessWidget {
  const _RecipeMemberRow({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.showDescription,
  });
  final RaftPickerItem candidate;
  final bool selected, showDescription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    return RaftInteractive(
      onPressed: onTap,
      button: false,
      checked: selected,
      builder: (context, state) {
        final states = t.recipeStates(
          hovered: state.hovered,
          pressed: state.pressed,
          focusVisible: state.focusVisible,
          disabled: onTap == null,
          responsive: true,
          pointerCoarse: RaftInteraction.of(context).touch,
        );
        final recipe = RaftWebMemberPickerRecipe.resolve(
          states: states,
          tokens: tokens,
        );
        final choice = RaftChoiceListRecipe.resolve(
          states: states,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftCheckboxIndicator(checked: selected),
              SizedBox(width: recipe.row.columnGap ?? 0),
              candidate.avatar,
              SizedBox(width: recipe.row.columnGap ?? 0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: choice.body.rowGap ?? 0,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: RaftTooltip(
                            message: candidate.label,
                            onlyWhenTruncated: true,
                            child: Text(
                              candidate.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: recipe.label.text(tokens, base: text),
                            ),
                          ),
                        ),
                        if (candidate.badge case final badge?) ...[
                          SizedBox(width: recipe.badge.columnGap ?? 0),
                          badge,
                        ],
                      ],
                    ),
                    if (showDescription &&
                        (candidate.description?.isNotEmpty ?? false))
                      RaftTooltip(
                        message: candidate.description ?? '',
                        onlyWhenTruncated: true,
                        child: Text(
                          candidate.description ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: choice.description.text(tokens, base: text),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

RaftBanner raftArchivedNameBanner(
  BuildContext context, {
  Key? key,
  required String name,
  required bool canUnarchive,
  VoidCallback? onChangeName,
  VoidCallback? onUnarchive,
  VoidCallback? onOpen,
  bool busy = false,
  bool showHint = true,
}) {
  final t = RaftTokens.of(context);
  return RaftBanner(
    key: key ?? const ValueKey('archived-name-collision'),
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
          label: busy ? 'Unarchiving…' : 'Unarchive',
          uiVariant: RaftButtonVariant.outline,
          uiSize: RaftButtonSize.md,
          disabled: busy,
          onPressed: onUnarchive,
        ),
      if (onOpen != null)
        RaftButton(
          key: const ValueKey('archived-name-collision-open'),
          label: 'Open channel',
          uiVariant: canUnarchive
              ? RaftButtonVariant.ghost
              : RaftButtonVariant.outline,
          uiSize: RaftButtonSize.md,
          disabled: busy,
          onPressed: onOpen,
        ),
      if (onChangeName != null)
        RaftButton(
          label: 'Change name',
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.md,
          onPressed: onChangeName,
        ),
    ],
  );
}
