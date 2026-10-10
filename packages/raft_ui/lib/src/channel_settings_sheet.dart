// Presentation of the Web channel settings sheet
// (packages/web/src/components/channel/EditChannelDialog.tsx, default
// "sheet" presentation, and ChannelPreferencesSection.tsx). The app adapter
// (apps/raft_flutter ChannelSettings) owns data, permissions and commands and
// passes them in as plain values and callbacks.
import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'localization.dart';
import 'recipes/button_variants.g.dart';
import 'switch.dart';
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
  });
  final String title, description;
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
  const RaftSheetSection(this.title, this.rows);
  final String title;
  final List<RaftSheetSwitchRow> rows;
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

  Widget _switchRow(
    BuildContext context,
    RaftTokens t,
    RaftSheetSwitchRow row,
  ) => Padding(
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
                  family: t.headingFont,
                  step: RaftTextSteps.sm,
                  weight: FontWeight.w500,
                  color: t.strong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                raftText(context, row.description),
                style: raftCssTextStyle(
                  family: t.headingFont,
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

  Widget _section(BuildContext context, RaftTokens t, RaftSheetSection s) {
    final divider = t.brutal
        ? Colors.black.withValues(alpha: .1)
        : t.colors['line-muted']!;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, s.title),
            style: raftCssTextStyle(
              family: t.headingFont,
              step: RaftTextSteps.base,
              weight: FontWeight.w700,
              color: t.strong,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < s.rows.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: divider)),
              ),
              child: _switchRow(context, t, s.rows[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // theme-brutal:bg-brutal-cream / bg-layer-canvas-muted.
    final paper = t.brutal
        ? t.colors['color-brutal-cream']!
        : t.colors['layer-canvas-muted']!;
    final strongEdge = t.brutal ? Colors.black : t.colors['line-muted']!;
    final edgeWidth = t.brutal ? 2.0 : 1.0;
    final muted = t.colors['foreground-muted']!;
    final hairline = t.brutal
        ? Colors.black.withValues(alpha: .1)
        : t.colors['line-muted']!;
    final width = MediaQuery.sizeOf(context).width;
    // px-4 py-2 on the sm action/footer buttons.
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.brutal
            ? t.colors['color-soft-signal']
            : t.colors['primary-soft'],
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
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .55)
                        : muted,
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
                      color: t.brutal ? Colors.black : t.strong,
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
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .6)
                        : muted,
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
            tooltip: raftText(context, 'Close channel settings'),
            onPressed: onClose,
          ),
        ],
      ),
    );

    final body = <Widget>[
      if (error != null) ...[
        RaftWarningBanner(error!),
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
                uppercase: false,
                required: true,
                labelWeight: FontWeight.w500,
                hint: nameHint,
                child: RaftDialogTextInput(
                  controller: nameController!,
                  placeholder: 'e.g. ai-research',
                  autofocus: true,
                  enabled: nameEnabled && !busy,
                  onSubmitted: onSubmitName,
                ),
              ),
              const SizedBox(height: 12),
              if (descriptionController != null)
                RaftProductFormField(
                  label: 'Description',
                  uppercase: false,
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
      for (final s in sections) _section(context, t, s),
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
              border: t.brutal
                  ? Border(
                      left: BorderSide(
                        color: t.colors['line-strong']!,
                        width: 2,
                      ),
                    )
                  : null,
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
