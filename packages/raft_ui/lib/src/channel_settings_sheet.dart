// Presentation of the Web channel settings sheet
// (packages/web/src/components/channel/EditChannelDialog.tsx, default
// "sheet" presentation, and ChannelPreferencesSection.tsx). The app adapter
// (apps/raft_flutter ChannelSettings) owns data, permissions and commands and
// passes them in as plain values and callbacks.
import 'package:flutter/material.dart';

import 'interaction.dart';
import 'system_inset.dart';
import 'panel_edge.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftPanelHeaderBar;
import 'recipes/button_variants.g.dart';
import 'raft/switch.dart';
import 'page_tokens.dart';
import 'error_presentation.dart' show RaftErrorBanner;
import 'theme.dart';

/// One `py-3` preference row: title `text-sm font-medium`, description
/// `mt-1 text-xs text-foreground-muted`, trailing `Switch size="md"`.
@immutable
class RaftSheetSwitchRow {
  const RaftSheetSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    this.onChanged,
    this.pending = false,
    this.key,
  });
  final String title, description;
  final Key? key;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// The value is still loading: the row keeps its final geometry and the
  /// switch's space is reserved, but nothing is shown or operable there.
  final bool pending;
}

/// `<section className="mt-5">` with an `h3 text-base font-bold` title and
/// `mt-2 divide-y divide-black/10` rows.
@immutable
class RaftSheetSection {
  const RaftSheetSection(
    this.title,
    this.rows, {
    this.description,
    this.usage,
    this.key,
  });
  final String title;
  final List<RaftSheetSwitchRow> rows;

  /// `mt-1 text-xs font-normal text-foreground-muted` under the heading.
  final String? description;

  /// `mt-2 text-xs font-semibold text-foreground-muted` (already formatted).
  final String? usage;
  final Key? key;
}

/// Sheet action button: `Button size="sm"` with `flex w-full items-center
/// justify-center gap-1.5 px-4 py-2 text-sm`.
@immutable
class RaftSheetAction {
  const RaftSheetAction(this.label, this.glyph, this.variant, this.onPressed);
  final String label;
  final RaftGlyph glyph;
  final RaftButtonRecipeVariant variant;
  final VoidCallback? onPressed;
}

class RaftChannelSettingsSheet extends StatelessWidget {
  const RaftChannelSettingsSheet({
    super.key,
    required this.channelName,
    required this.onClose,
    this.title = 'Settings',
    this.loading = false,
    this.busy = false,
    this.error,
    this.lead,
    this.nameController,
    this.descriptionController,
    this.nameEnabled = true,
    this.descriptionEnabled = true,
    this.nameHint,
    this.onSubmitName,
    this.sections = const [],
    this.showActions = false,
    this.actions = const [],
    this.onSave,
    this.saveDisabled = false,
    this.page = false,
    this.channelDescription = '',
    this.channelLabel,
    this.onEdit,
    this.onMembers,
  });
  final String channelName, title;
  final VoidCallback onClose;
  final bool loading, busy, nameEnabled, descriptionEnabled, showActions;
  final String? error, nameHint;

  /// Optional block above the info form (joint conversion section).
  final Widget? lead;

  /// Name/description form; omitted when [nameController] is null.
  final TextEditingController? nameController, descriptionController;
  final ValueChanged<String>? onSubmitName;
  final List<RaftSheetSection> sections;
  final List<RaftSheetAction> actions;

  /// Footer Save; omitted when null (no edit capability).
  final VoidCallback? onSave;
  final bool saveDisabled;
  final bool page;
  final String channelDescription;
  final String? channelLabel;
  final VoidCallback? onEdit, onMembers;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // theme-brutal:bg-brutal-cream / bg-layer-canvas-muted.
    final paper = t.colors['layer-canvas-muted']!;
    final strongEdge = t.colors['line-muted']!;
    final edgeWidth = 1.0;
    final muted = t.colors['foreground-muted']!;
    final hairline = t.colors['line-muted']!;
    final width = MediaQuery.sizeOf(context).width;
    // px-4 py-2 on the sm action/footer buttons.
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.colors['primary-soft'],
        border: Border(
          bottom: BorderSide(color: strongEdge, width: edgeWidth),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // text-[10px] font-bold tracking-wide (inherited 1.5 leading).
                Text(
                  raftText(context, 'Channel'),
                  style: raftCssTextStyle(
                    family: t.headingFont,
                    step: (10, 15),
                    weight: FontWeight.w700,
                    color: muted,
                    trackingEm: .025,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    raftText(context, title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: raftCssTextStyle(
                      family: t.headingFont,
                      step: RaftTextSteps.xl,
                      weight: FontWeight.w700,
                      color: t.strong,
                    ),
                  ),
                ),
                Text(
                  '#$channelName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: raftCssTextStyle(
                    family: t.monoFont,
                    step: RaftTextSteps.xs,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          RaftRecipeButton(
            glyph: RaftGlyph.x,
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: const EdgeInsets.all(4), // p-1
            tooltip: raftText(context, 'Close Channel Settings'),
            onPressed: onClose,
          ),
        ],
      ),
    );

    final body = <Widget>[
      if (page) ...[
        Semantics(
          header: true,
          child: Text(
            channelLabel ?? '#$channelName',
            style: RaftTypography.heading(t, size: 20, line: 28),
          ),
        ),
        if (channelDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(channelDescription, style: RaftTypography.body(t)),
        ],
        const SizedBox(height: 16),
        if (onEdit != null)
          RaftRecipeButton(
            key: const ValueKey('channel-settings-edit'),
            label: 'Edit',
            variant: RaftButtonRecipeVariant.outline,
            onPressed: busy ? null : onEdit,
          ),
        if (onMembers != null) ...[
          const SizedBox(height: 12),
          RaftRecipeButton(
            key: const ValueKey('channel-settings-members'),
            label: 'Members',
            glyph: RaftGlyph.users,
            variant: RaftButtonRecipeVariant.outline,
            onPressed: onMembers,
          ),
        ],
      ],
      if (error != null) ...[
        RaftErrorBanner(error!),
        const SizedBox(height: 20),
      ],
      ?lead,
      if (nameController != null)
        // section space-y-3 border-b border-line-muted pb-5.
        Container(
          padding: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RaftProductFormField(
                label: 'Name',
                required: true,
                labelWeight: FontWeight.w500,
                hint: nameHint,
                child: RaftDialogTextInput(
                  controller: nameController!,
                  placeholder: 'e.g. ai-research',
                  autofocus: !page && RaftInteraction.of(context).pointer,
                  enabled: nameEnabled && !busy,
                  onSubmitted: onSubmitName,
                ),
              ),
              const SizedBox(height: 12),
              if (descriptionController != null)
                RaftProductFormField(
                  label: 'Description',
                  optional: true,
                  labelWeight: FontWeight.w500,
                  child: RaftDialogTextInput(
                    controller: descriptionController!,
                    placeholder: 'What is this channel about?',
                    multiline: true,
                    enabled: descriptionEnabled && !busy,
                  ),
                ),
            ],
          ),
        ),
      for (final s in sections) raftSheetSection(context, t, s, busy: busy),
      if (showActions)
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                raftText(context, 'Channel actions'),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  weight: FontWeight.w700,
                  color: muted,
                  trackingEm: .025,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                raftText(
                  context,
                  'Membership, visibility, conversion, archive, and destructive controls.',
                ),
                style: raftCssTextStyle(
                  family: t.headingFont,
                  step: RaftTextSteps.xs,
                  color: muted,
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(height: 12),
                RaftRecipeButton(
                  label: action.label,
                  glyph: action.glyph,
                  variant: action.variant,
                  size: RaftButtonRecipeSize.sm,
                  expand: true,
                  gap: 6,
                  padding: buttonPadding,
                  textStep: RaftTextSteps.sm,
                  disabled: busy,
                  onPressed: action.onPressed,
                ),
              ],
            ],
          ),
        ),
    ];

    final footer = Container(
      // `safe-bottom` = 1rem + inset bottom; py-3 elsewhere.
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: paper,
        border: Border(
          top: BorderSide(color: strongEdge, width: edgeWidth),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RaftRecipeButton(
            label: 'Cancel',
            variant: RaftButtonRecipeVariant.outline,
            size: RaftButtonRecipeSize.sm,
            padding: buttonPadding,
            textStep: RaftTextSteps.sm,
            onPressed: onClose,
          ),
          if (onSave != null) ...[
            const SizedBox(width: 12),
            RaftRecipeButton(
              label: busy ? 'Saving…' : 'Save',
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.sm,
              padding: buttonPadding,
              textStep: RaftTextSteps.sm,
              disabled: busy || saveDisabled,
              onPressed: onSave,
            ),
          ],
        ],
      ),
    );

    if (page) {
      return Material(
        color: t.panel,
        child: Column(
          children: [
            // Native page without a Web counterpart (Web opens a drawer): the
            // Web PanelHeader keeps it consistent with every phone page.
            RaftPanelHeaderBar(
              title: raftText(context, title),
              onBack: onClose,
              backTooltip: raftText(context, 'Back'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: raftScrollPadding(context, const EdgeInsets.all(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // DrawerContent: right sheet, `w-full max-w-[min(100vw,34rem)] h-dvh`,
    // `theme-brutal:border-l-2 border-line-strong`.
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width < 544 ? width : 544,
        height: double.infinity,
        child: Material(
          color: paper,
          // Container (not DecoratedBox) so the border-l insets the content
          // like the CSS border box.
          child: Container(
            decoration: BoxDecoration(
              // The shared rule (RaftPanelEdge): only the full-width phone
              // page draws no `theme-brutal:border-l-2`.
              border: RaftPanelEdge.left(context, RaftPanelEdgeStyle.drawer),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontFamily: t.headingFont, color: t.strong),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: loading
                        ? const Center(child: RaftSpinner())
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: body,
                            ),
                          ),
                  ),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One `py-3` preference row (`flex items-center justify-between gap-3`).
Widget raftSheetSwitchRow(
  BuildContext context,
  RaftTokens t,
  RaftSheetSwitchRow row, {
  bool busy = false,
  String? family,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raftText(context, row.title),
              style: raftCssTextStyle(
                family: family ?? t.headingFont,
                step: RaftTextSteps.sm,
                weight: FontWeight.w500,
                color: t.strong,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              raftText(context, row.description),
              style: raftCssTextStyle(
                family: family ?? t.headingFont,
                step: RaftTextSteps.xs,
                color: t.colors['foreground-muted'],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Visibility(
        visible: !row.pending,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: RaftSwitch(
          key: row.key,
          value: row.value,
          size: RaftSwitchSize.md,
          semanticLabel: raftText(context, row.title),
          // The row keeps CSS geometry; the switch is its own tap target.
          minimumTargetSize: 0,
          onChanged: busy || row.pending ? null : row.onChanged,
        ),
      ),
    ],
  ),
);

/// `<section className="mt-5">`: `h3 text-base font-bold`, optional
/// description / usage paragraphs, then `mt-2 divide-y divide-black/10` rows.
Widget raftSheetSection(
  BuildContext context,
  RaftTokens t,
  RaftSheetSection s, {
  bool busy = false,
  String? family,
}) {
  final divider = t.colors['line-muted']!;
  final muted = t.colors['foreground-muted'];
  return Padding(
    key: s.key,
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          raftText(context, s.title),
          style: t.formSectionTitle(
            raftCssTextStyle(
              family: family ?? t.headingFont,
              step: RaftTextSteps.base,
              weight: FontWeight.w700,
              color: t.strong,
            ),
          ),
        ),
        if (s.description != null) ...[
          const SizedBox(height: 4),
          Text(
            raftText(context, s.description!),
            style: t.formSectionDescription(
              raftCssTextStyle(
                family: family ?? t.headingFont,
                step: RaftTextSteps.xs,
                color: muted,
              ),
            ),
          ),
        ],
        if (s.usage != null) ...[
          const SizedBox(height: 8),
          Text(
            s.usage!,
            style: raftCssTextStyle(
              family: family ?? t.headingFont,
              step: RaftTextSteps.xs,
              weight: FontWeight.w600,
              color: muted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < s.rows.length; i++)
          // Container, not DecoratedBox: `divide-y` borders take layout space.
          Container(
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: divider)),
            ),
            child: raftSheetSwitchRow(
              context,
              t,
              s.rows[i],
              busy: busy,
              family: family,
            ),
          ),
      ],
    ),
  );
}
