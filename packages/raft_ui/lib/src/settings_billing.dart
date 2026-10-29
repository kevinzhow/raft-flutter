// Settings > Workspace > Plan & Billing from the Web client (raft-source
// 26f77ef, packages/web/src/components/settings/SettingsPanel.tsx):
// PlanSection, PlanBillingLoadingSection, DowngradeWarningCard and the
// BillingTabContent permission card. The app computes every label, value and
// gate (billing projection); this file resolves only the class lists.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption;

import 'package:flutter/material.dart';

import 'flex_shrink_row.dart';
import 'design_primitives.dart' show RaftTypography;
import 'icons.dart';
import 'indicators.dart' show RaftWebPalette;
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'recipes/card.g.dart';
import 'recipes/progress.g.dart';
import 'recipes/recipe_router.dart'
    show resolveRecipeClasses, usesLegacyRecipes;
import 'recipes/skeleton.g.dart';
import 'recipes/status.g.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'raft/ui_tokens.dart' show RaftTokensUi;
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';
import 'viewport_breakpoints.dart';

/// A label / value pair of the plan card usage strip (`text-xs font-bold`
/// label, `text-xs font-mono` value, `justify-between gap-3`).
@immutable
class RaftBillingStat {
  const RaftBillingStat(this.label, this.value);
  final String label, value;
}

/// The Pro universal-seat bar: `{used} / {limit} used`, the human
/// (`bg-primary-strong theme-brutal:bg-soft-signal`) and agent
/// (`bg-accent-strong theme-brutal:bg-brutal-pink`) segments and their
/// tooltips, and the Humans / Agents legend.
@immutable
class RaftBillingSeatUsage {
  const RaftBillingSeatUsage({
    required this.label,
    required this.value,
    required this.humanPercent,
    required this.agentPercent,
    required this.humanTooltip,
    required this.agentTooltip,
    required this.humansLabel,
    required this.agentsLabel,
  });
  final String label, value, humanTooltip, agentTooltip;
  final String humansLabel, agentsLabel;
  final double humanPercent, agentPercent;
}

/// A billing `Button` (`size="sm"`) with its Tooltip copy.
@immutable
class RaftBillingAction {
  const RaftBillingAction({
    required this.label,
    this.onPressed,
    this.tooltip,
    this.actionKey,
    this.variant = RaftButtonRecipeVariant.outline,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Key? actionKey;
  final RaftButtonRecipeVariant variant;
}

/// A billing-summary row: `text-sm font-bold` label and one or more
/// right-aligned `text-sm font-mono leading-5` value lines; [struck] is the
/// `line-through` original price above them.
@immutable
class RaftBillingSummaryRow {
  const RaftBillingSummaryRow(this.label, this.values, {this.struck});
  final String label;
  final List<String> values;
  final String? struck;
}

/// The trial / downgrade notices above the plan card.
enum RaftBillingNoticeTone {
  /// `bg-primary-soft theme-brutal:bg-soft-signal/30` (Final Trial Period).
  trial,

  /// `bg-brutal-orange/20` with the AlertTriangle title (DowngradeWarningCard).
  downgrade,
}

@immutable
class RaftBillingNotice {
  const RaftBillingNotice({
    required this.tone,
    required this.title,
    required this.body,
    this.lines = const [],
    this.bodyMargin = false,
  });
  final RaftBillingNoticeTone tone;
  final String title;

  /// The body paragraph carries `mb-2` even without excess rows (DowngradeWarningCard grace period).
  final bool bodyMargin;

  /// `text-xs font-mono` paragraph; `**bold**` spans render
  /// `font-bold text-foreground-strong` (ICU `<b>` chunks).
  final String body;

  /// Excess rows (`text-xs font-mono`, `**n**` in `text-brutal-orange`).
  final List<String> lines;
}

/// The billing-interval SegmentedControl (BillingIntervalSegmentedControl).
@immutable
class RaftBillingInterval {
  const RaftBillingInterval({
    required this.title,
    required this.annual,
    required this.monthlyLabel,
    required this.yearlyLabel,
    required this.saveLabel,
    required this.label,
    this.onChanged,
  });
  final String title, monthlyLabel, yearlyLabel, saveLabel, label;
  final bool annual;

  /// Null disables the control.
  final ValueChanged<bool>? onChanged;
}

/// The Manage Plan / Upgrade to Pro / Manage Seats card.
@immutable
class RaftBillingManagePlan {
  const RaftBillingManagePlan({
    required this.title,
    required this.checkout,
    required this.prompt,
    required this.seatLabel,
    required this.seatController,
    required this.help,
    required this.summaryTitle,
    required this.summaryRows,
    this.interval,
    this.intervalLine,
    this.seatEnabled = true,
    this.onSeatChanged,
    this.onSeatCommitted,
    this.promotionLabel,
    this.promotionController,
    this.promotionHint,
    this.onPromotionChanged,
    this.draftError,
    this.actions = const [],
    this.disabledReason,
    this.notice,
    this.error,
    this.summaryFootnote,
  });
  final String title;

  /// Checkout mode (CreditCard header icon) vs. seat management (Plus).
  final bool checkout;
  final RaftBillingInterval? interval;

  /// `Billing interval: Yearly` (subscribed servers).
  final String? intervalLine;
  final String prompt, seatLabel, help;
  final TextEditingController seatController;
  final bool seatEnabled;
  final ValueChanged<String>? onSeatChanged;
  final VoidCallback? onSeatCommitted;
  final String? promotionLabel, promotionHint;
  final TextEditingController? promotionController;
  final ValueChanged<String>? onPromotionChanged;
  final String? draftError;
  final List<RaftBillingAction> actions;
  final String? disabledReason, notice, error;
  final String summaryTitle;
  final List<RaftBillingSummaryRow> summaryRows;
  final String? summaryFootnote;
}

/// PlanSection: the Current Plan header, notices, the plan card (header,
/// Included / Not included features, usage strip, portal / compare footer)
/// and the optional manage-plan card.
class RaftPlanBillingSection extends StatelessWidget {
  const RaftPlanBillingSection({
    super.key,
    required this.planName,
    required this.planDescription,
    required this.included,
    required this.compare,
    this.notices = const [],
    this.notIncluded = const [],
    this.seatUsage,
    this.seatStats = const [],
    this.limitStats = const [],
    this.portalActions,
    this.manage,
    this.afterPlan,
  });
  final String planName, planDescription;

  /// Content between the plan card and the manage card (Web: the cloud agent
  /// spend card, for who may read the billing summary).
  final Widget? afterPlan;
  final List<RaftBillingNotice> notices;
  final List<String> included, notIncluded;
  final RaftBillingSeatUsage? seatUsage;

  /// Humans / Agents rows of a Pro plan without universal seats.
  final List<RaftBillingStat> seatStats;

  /// Message History / File uploads (Free).
  final List<RaftBillingStat> limitStats;

  /// Billing portal / Cancel subscription; null renders the empty `<span>`.
  final List<RaftBillingAction>? portalActions;
  final RaftBillingAction compare;
  final RaftBillingManagePlan? manage;

  @override
  Widget build(BuildContext context) {
    return RaftInheritedFont(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RaftSettingsSectionHeader(
              label: 'Current Plan',
              glyph: RaftGlyph.creditCard,
            ),
            for (final notice in notices) _BillingNoticeCard(notice),
            _PlanCard(section: this),
            if (afterPlan != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: afterPlan,
              ),
            if (manage != null) ...[
              RaftSettingsSectionHeader(
                label: manage!.title,
                glyph: manage!.checkout ? RaftGlyph.creditCard : RaftGlyph.plus,
              ),
              _ManagePlanCard(manage!),
            ],
          ],
        ),
      ),
    );
  }
}

/// BillingTabContent without `viewBilling`: the Billing header over a muted
/// settings card.
class RaftBillingRestricted extends StatelessWidget {
  const RaftBillingRestricted({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Billing',
            glyph: RaftGlyph.creditCard,
          ),
          RaftSettingsCard(
            child: Text(
              raftText(context, message),
              style: RaftSettingsText(t).bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// PlanBillingLoadingSection: the plan card and manage card outlines with
/// raft-ui Skeleton lines and blocks (held at the first pulse frame).
class RaftPlanBillingLoading extends StatelessWidget {
  const RaftPlanBillingLoading({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final wide = raftBreakpointWidth(context) >= 1024;
    final sm = raftBreakpointWidth(context) >= 640;
    final divider = _BillingLines(t);
    Widget line({double? width, double height = 16, double? factor}) =>
        _BillingSkeleton(
          variant: RaftSkeletonRecipeVariant.line,
          width: width,
          height: height,
          widthFactor: factor,
        );
    Widget block(double width) => _BillingSkeleton(
      variant: RaftSkeletonRecipeVariant.block,
      width: width,
      height: 32,
      outlined: true,
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        line(width: 96),
        const SizedBox(height: 12),
        for (final (i, factor) in const [1.0, .8, .6].indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: _BillingSkeleton(
                  variant: RaftSkeletonRecipeVariant.block,
                  width: 16,
                  height: 16,
                  outlined: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: line(factor: factor)),
            ],
          ),
        ],
      ],
    );
    final stats = [
      for (final label in const ['Seat', 'Message History', 'File uploads'])
        Row(
          children: [
            Expanded(
              child: Text(
                raftText(context, label),
                style: RaftTypography.inherited(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: t.muted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            line(width: 80),
          ],
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RaftSettingsSectionHeader(
            label: 'Plan & Billing',
            glyph: RaftGlyph.creditCard,
          ),
          Semantics(
            label: raftText(context, 'Loading'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: RaftSettingsCard.decoration(t),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: divider.headerFill,
                      border: Border(
                        bottom: BorderSide(color: divider.header, width: 2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(width: 128, height: 20),
                        const SizedBox(height: 8),
                        line(width: 256, height: 16),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: column),
                              const SizedBox(width: 16),
                              Expanded(child: column),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              column,
                              const SizedBox(height: 16),
                              column,
                            ],
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: divider.top,
                    child: _Grid(columns: sm ? 2 : 1, gap: 12, children: stats),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: divider.top,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 12,
                      children: [block(112), block(176)],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const RaftSettingsSectionHeader(
            label: 'Manage Plan',
            glyph: RaftGlyph.plus,
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: RaftSettingsCard.decoration(t),
            child: _ManageLayout(
              wide: wide,
              left: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(width: 224, height: 16),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [block(96), line(width: 192)],
                  ),
                  const SizedBox(height: 16),
                  block(128),
                ],
              ),
              right: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: divider.headerFill,
                  border: Border.all(color: text.edge, width: 1),
                  boxShadow: _shadowSm(t),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: line(width: 128, height: 12),
                    ),
                    const SizedBox(height: 16),
                    for (final i in const [0, 1, 2]) ...[
                      if (i > 0) const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [line(width: 112), line(width: 64)],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

List<BoxShadow> _shadowSm(RaftTokens t) => t.themeShadows.sm.outer;

/// Card section rules: the header's `border-b-2 border-line-muted
/// theme-brutal:border-black` and the strips' `border-t-2 border-line-muted
/// theme-brutal:border-black/10`.
class _BillingLines {
  _BillingLines(this.t);
  final RaftTokens t;

  /// raft-ui 0.7.0: the plan card's header and sections are separated by 1px
  /// `border-line-hairline` rules on the plain card fill; the frozen looks keep
  /// their 2px `line-muted` rules and the cream header.
  bool get raft => t.isRaftLook;
  Color get header => t.colors[raft ? 'line-hairline' : 'line-muted']!;
  Color get strip => t.colors[raft ? 'line-hairline' : 'line-muted']!;
  double get ruleWidth => raft ? 1 : 2;

  /// `bg-layer-canvas-muted theme-brutal:bg-brutal-cream`.
  Color? get headerFill => raft ? null : t.colors['layer-canvas-muted']!;
  BoxDecoration get top => BoxDecoration(
    border: Border(
      top: BorderSide(color: strip, width: ruleWidth),
    ),
  );
}

/// raft-ui `Skeleton` with the callsite size (`h-* w-*`, `w-3/5`) and the
/// block placeholders' `border border-line-muted theme-brutal:border-2
/// theme-brutal:border-black/20`.
class _BillingSkeleton extends StatelessWidget {
  const _BillingSkeleton({
    required this.variant,
    this.width,
    required this.height,
    this.widthFactor,
    this.outlined = false,
  });
  final RaftSkeletonRecipeVariant variant;
  final double? width, widthFactor;
  final double height;
  final bool outlined;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftSkeletonRecipe.resolve(
      theme: t.recipeTheme,
      variant: variant,
      states: t.recipeStates(extra: ['data-variant=${variant.css}']),
      tokens: t.recipeTokens,
    ).root;
    final box = ExcludeSemantics(
      child: RaftRecipeBox(
        style: s,
        tokens: t.recipeTokens,
        width: widthFactor == null ? width : double.infinity,
        height: height,
        applyOpacity: false,
        decorationOverride: outlined
            ? (base) => base.copyWith(
                border: Border.all(color: t.colors['line-muted']!, width: 1),
              )
            : null,
      ),
    );
    return widthFactor == null
        ? box
        : FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: box,
          );
  }
}

/// CSS grid `grid-cols-N gap-*` with equal columns and auto rows.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.gap,
    required this.children,
  });
  final int columns;
  final double gap;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < children.length
                      ? children[i + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// `grid gap-4 lg:grid-cols-[minmax(0,1fr)_280px]` (items stretch).
class _ManageLayout extends StatelessWidget {
  const _ManageLayout({
    required this.wide,
    required this.left,
    required this.right,
  });
  final bool wide;
  final Widget left, right;
  @override
  Widget build(BuildContext context) => wide
      ? IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              SizedBox(width: 280, child: right),
            ],
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, const SizedBox(height: 16), right],
        );
}

/// `**bold**` → [bold] spans (ICU `<b>` chunks).
List<TextSpan> _rich(String source, TextStyle bold) {
  final parts = source.split('**');
  return [
    for (final (i, part) in parts.indexed)
      if (part.isNotEmpty) TextSpan(text: part, style: i.isOdd ? bold : null),
  ];
}

class _BillingNoticeCard extends StatelessWidget {
  const _BillingNoticeCard(this.notice);
  final RaftBillingNotice notice;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final white = t.panel;
    final fill = switch (notice.tone) {
      RaftBillingNoticeTone.trial => Color.alphaBlend(
        t.colors['primary-soft']!,
        white,
      ),
      RaftBillingNoticeTone.downgrade => Color.alphaBlend(
        t.product.brutalOrange.withValues(alpha: .2),
        white,
      ),
    };
    final mono = RaftTypography.mono(t, size: 12, line: 16, color: text.muted);
    final strong = mono.copyWith(
      fontWeight: FontWeight.w700,
      color: text.strong,
    );
    final orange = mono.copyWith(
      fontWeight: FontWeight.w700,
      color: t.product.brutalOrange,
    );
    final downgrade = notice.tone == RaftBillingNoticeTone.downgrade;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: text.edge, width: 1),
        boxShadow: _shadowSm(t),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (downgrade) ...[
                RaftIcon(RaftGlyph.alertTriangle, size: 16, color: text.strong),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(notice.title, style: text.title)),
            ],
          ),
          SizedBox(height: downgrade ? 8 : 4),
          Text.rich(
            TextSpan(children: _rich(notice.body, strong)),
            style: mono,
          ),
          if (notice.lines.isNotEmpty || notice.bodyMargin)
            const SizedBox(height: 8),
          if (notice.lines.isNotEmpty) ...[
            for (final (i, line) in notice.lines.indexed) ...[
              if (i > 0) const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: _rich(line, orange)),
                style: mono.copyWith(color: text.strong),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.section});
  final RaftPlanBillingSection section;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final lines = _BillingLines(t);
    final band = raftBreakpointWidth(context);
    final s = section;
    Widget features(String title, List<String> items, {required bool yes}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raftText(context, title),
              style: lines.raft
                  // `SectionEyebrow`: `text-footnote font-bold text-foreground-hint`.
                  ? t.scale(
                      RaftTypeScale.footnote,
                      weight: FontWeight.w700,
                      color: t.colors['foreground-hint'],
                    )
                  : text.title.copyWith(color: yes ? null : text.muted),
            ),
            const SizedBox(height: 12),
            for (final (i, item) in items.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RaftIcon(
                      yes ? RaftGlyph.check : RaftGlyph.x,
                      size: 16,
                      color: lines.raft
                          // `text-foreground` / `text-foreground-hint`.
                          ? (yes
                                ? t.colors['foreground']
                                : t.colors['foreground-hint'])
                          : yes
                          ? RaftWebPalette.green700
                          : t.product.brutalRed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: RaftTypography.inherited(
                        t,
                        size: 14,
                        line: 20,
                        color: lines.raft && !yes ? text.muted : text.strong,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
    final included = features('Included', s.included, yes: true);
    final excluded = s.notIncluded.isEmpty
        ? null
        : features('Not included', s.notIncluded, yes: false);
    Widget stat(RaftBillingStat stat) => _StatRow(stat);
    final usage = <Widget>[
      if (s.seatUsage != null) _SeatUsage(s.seatUsage!),
      if (s.seatStats.isNotEmpty)
        _Grid(
          columns: band >= 640 ? 2 : 1,
          gap: 12,
          children: [for (final x in s.seatStats) stat(x)],
        ),
      if (s.limitStats.isNotEmpty)
        _Grid(
          columns: band >= 640 ? 2 : 1,
          gap: 12,
          children: [for (final x in s.limitStats) stat(x)],
        ),
    ];
    final portal = s.portalActions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        key: const ValueKey('billing-current-plan-card'),
        decoration: RaftSettingsCard.decoration(t),
        // `overflow-hidden`: the header fill stops at the rounded padding box.
        clipBehavior: usesLegacyRecipes(t.recipeTokens)
            ? Clip.none
            : Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lines.headerFill,
                border: Border(
                  bottom: BorderSide(
                    color: lines.header,
                    width: lines.ruleWidth,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lines.raft)
                    // `text-headline` plus the 22px sticker check of the current plan.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            s.planName,
                            style: t.scale(
                              RaftTypeScale.headline,
                              color: text.strong,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CurrentPlanCheck(t),
                      ],
                    )
                  else
                    Text(
                      s.planName,
                      style: RaftTypography.inherited(
                        t,
                        size: 18,
                        line: 28,
                        weight: FontWeight.w700,
                        color: text.strong,
                      ),
                    ),
                  if (lines.raft) const SizedBox(height: 2),
                  Text(s.planDescription, style: text.bodyMuted),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: excluded != null && band >= 1024
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: included),
                        const SizedBox(width: 16),
                        Expanded(child: excluded),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        included,
                        if (excluded != null) ...[
                          const SizedBox(height: 16),
                          excluded,
                        ],
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: lines.top,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: usage,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: lines.top,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (portal == null)
                    const SizedBox.shrink()
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final a in portal) _ActionButton(a)],
                    ),
                  _ActionButton(s.compare),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 22px sticker check beside the current plan's name (`rounded-chip
/// border-[1.5px] border-sticker-ink bg-brand`).
class _CurrentPlanCheck extends StatelessWidget {
  const _CurrentPlanCheck(this.t);
  final RaftTokens t;
  double get chipRadius => t.size('radius.chip', fallback: 0);
  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: t.colors['brand-400'] ?? t.colors['brand'],
      borderRadius: BorderRadius.all(Radius.circular(chipRadius)),
      border: Border.all(color: t.colors['sticker-ink'] ?? t.ink, width: 1.5),
    ),
    child: RaftIcon(
      RaftGlyph.check,
      size: 14,
      strokeWidth: 2.5,
      color: t.colors['sticker-ink'] ?? t.ink,
    ),
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.stat);
  final RaftBillingStat stat;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Row(
      children: [
        Expanded(
          child: Text(
            stat.label,
            // Raft: `text-footnote font-semibold`; the frozen looks `text-xs font-bold`.
            style: RaftTypography.inherited(
              t,
              size: t.isRaftLook ? 13 : 12,
              line: t.isRaftLook ? 18 : 16,
              weight: t.isRaftLook ? FontWeight.w600 : FontWeight.w700,
              color: text.strong,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          stat.value,
          style: RaftTypography.mono(t, size: 12, line: 16, color: text.muted),
        ),
      ],
    );
  }
}

class _SeatUsage extends StatelessWidget {
  const _SeatUsage(this.usage);
  final RaftBillingSeatUsage usage;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final total = (usage.humanPercent + usage.agentPercent).clamp(0, 100);
    final states = t.recipeStates(
      extra: [
        'group/progress:data-size=md',
        if (total >= 100) 'group/progress:data-complete',
      ],
    );
    final p = RaftProgressRecipe.resolve(
      theme: t.recipeTheme,
      states: states,
      tokens: rt,
    );
    // The track inherits Progress's local CSS variables (see RaftProgressBar);
    // the callsite adds `flex !overflow-hidden`.
    final track = resolveRecipeClasses(
      {...p.root.classes, ...p.track.classes},
      states,
      rt,
    );
    Widget segment(double percent, Color color, String tooltip) => percent <= 0
        ? const SizedBox.shrink()
        : RaftTooltip(
            message: tooltip,
            child: ColoredBox(color: color),
          );
    Widget legend(String label, RaftStatusRecipeVariant variant) {
      final dot = RaftStatusRecipe.resolve(
        theme: t.recipeTheme,
        size: RaftStatusRecipeSize.sm,
        variant: variant,
        states: t.recipeStates(),
        tokens: rt,
      ).root;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftRecipeBox(style: dot, tokens: rt),
          const SizedBox(width: 8),
          Text(
            label,
            style: RaftTypography.inherited(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w700,
              color: t.strong,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(RaftBillingStat(usage.label, usage.value)),
        const SizedBox(height: 12),
        Semantics(
          label: usage.label,
          value: '${total.round()}%',
          child: RaftRecipeBox(
            style: track,
            tokens: rt,
            width: double.infinity,
            clip: true,
            child: LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: box.maxWidth * usage.humanPercent / 100,
                    child: segment(
                      usage.humanPercent,
                      t.colors['primary-strong']!,
                      usage.humanTooltip,
                    ),
                  ),
                  SizedBox(
                    width: box.maxWidth * usage.agentPercent / 100,
                    child: segment(
                      usage.agentPercent,
                      t.colors['accent-strong']!,
                      usage.agentTooltip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            legend(usage.humansLabel, RaftStatusRecipeVariant.primary),
            legend(usage.agentsLabel, RaftStatusRecipeVariant.accent),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);
  final RaftBillingAction action;
  @override
  Widget build(BuildContext context) {
    final button = RaftSettingsRecipeButton(
      key: action.actionKey,
      label: action.label,
      variant: action.variant,
      size: RaftButtonRecipeSize.sm,
      onPressed: action.onPressed,
    );
    return action.tooltip == null
        ? button
        : RaftTooltip(message: action.tooltip!, child: button);
  }
}

class _ManagePlanCard extends StatelessWidget {
  const _ManagePlanCard(this.manage);
  final RaftBillingManagePlan manage;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final m = manage;
    final mono = RaftTypography.mono(t, size: 12, line: 16, color: text.muted);
    final red = mono.copyWith(color: t.product.brutalRed);
    final fieldLabel = RaftTypography.inherited(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: text.muted,
    );
    final interval = m.interval;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interval != null) ...[
          Text(interval.title, style: text.title),
          const SizedBox(height: 8),
          RaftSegmentedControl<bool>(
            key: const ValueKey('billing-interval'),
            value: interval.annual,
            label: interval.label,
            onChanged: interval.onChanged,
            items: [
              RaftSegmentedOption(
                value: false,
                label: interval.monthlyLabel,
                enabled: interval.onChanged != null,
              ),
              RaftSegmentedOption(
                value: true,
                label: interval.yearlyLabel,
                labelSuffix: interval.saveLabel,
                enabled: interval.onChanged != null,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (m.intervalLine != null) ...[
          Text(m.intervalLine!, style: mono),
          const SizedBox(height: 16),
        ],
        Text(m.prompt, style: text.title),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(m.seatLabel, style: fieldLabel),
                  const SizedBox(height: 4),
                  _BillingInput(
                    fieldKey: const ValueKey('billing-seat-input'),
                    controller: m.seatController,
                    label: m.seatLabel,
                    enabled: m.seatEnabled,
                    numeric: true,
                    onChanged: m.onSeatChanged,
                    onCommitted: m.onSeatCommitted,
                  ),
                ],
              ),
            ),
            if (m.promotionController != null && m.promotionLabel != null)
              SizedBox(
                width: 256,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(m.promotionLabel!, style: fieldLabel),
                    const SizedBox(height: 4),
                    _BillingInput(
                      fieldKey: const ValueKey('billing-promotion-input'),
                      controller: m.promotionController!,
                      label: m.promotionLabel!,
                      enabled: m.seatEnabled,
                      upperCase: true,
                      onChanged: m.onPromotionChanged,
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (m.promotionHint != null) ...[
          const SizedBox(height: 12),
          Text(
            m.promotionHint!,
            style: RaftTypography.mono(
              t,
              size: 11,
              line: 11 * 1.5,
              color: t.muted,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(m.help, style: mono),
        if (m.draftError != null) ...[
          const SizedBox(height: 12),
          Text(raftText(context, m.draftError!), style: red),
        ],
        if (m.actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final a in m.actions) _ActionButton(a)],
          ),
        ],
        for (final (copy, style) in [
          (m.disabledReason, mono),
          (m.notice, mono),
          (m.error, red),
        ])
          if (copy != null && copy.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(raftText(context, copy), style: style),
            ),
          ],
      ],
    );
    final wide = raftBreakpointWidth(context) >= 1024;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: RaftSettingsCard.decoration(t),
      child: _ManageLayout(
        wide: wide,
        left: left,
        right: _SummaryCard(manage: m),
      ),
    );
  }
}

/// `Card variant="option"` + `bg-layer-canvas-muted p-4
/// theme-brutal:border-black theme-brutal:bg-brutal-cream`.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.manage});
  final RaftBillingManagePlan manage;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final text = RaftSettingsText(t);
    final root = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      variant: RaftCardRecipeVariant.option,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    final label = text.title;
    final value = RaftTypography.mono(t, size: 14, line: 20, color: text.muted);
    final m = manage;
    return RaftRecipeBox(
      key: const ValueKey('billing-summary-card'),
      style: root,
      tokens: rt,
      padding: const EdgeInsets.all(16),
      applyText: false,
      decorationOverride: (base) =>
          base.copyWith(color: t.colors['layer-canvas-muted']),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            raftText(context, m.summaryTitle),
            style: RaftTypography.inherited(
              t,
              size: 12,
              line: 16,
              weight: FontWeight.w700,
              color: t.muted,
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, row) in m.summaryRows.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            // `flex items-center justify-between gap-3`: both items shrink
            // (and wrap) in proportion to their content width.
            RaftFlexShrinkRow(
              gap: 12,
              spaceBetween: true,
              children: [
                Text(row.label, style: label),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (row.struck != null)
                      Text(
                        row.struck!,
                        style: value.copyWith(
                          color: t.muted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: t.muted,
                        ),
                      ),
                    for (final v in row.values) Text(v, style: value),
                  ],
                ),
              ],
            ),
          ],
          if (m.summaryFootnote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: text.edge, width: 2)),
              ),
              child: Text(
                m.summaryFootnote!,
                style: RaftTypography.mono(
                  t,
                  size: 12,
                  line: 16,
                  color: text.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// raft-ui `Input` (`text-sm font-mono`), committing on blur like the Web
/// `onBlur={commitSeatInput}`.
class _BillingInput extends StatefulWidget {
  const _BillingInput({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
    this.numeric = false,
    this.upperCase = false,
    this.onChanged,
    this.onCommitted,
  });
  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled, numeric, upperCase;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onCommitted;
  @override
  State<_BillingInput> createState() => _BillingInputState();
}

class _BillingInputState extends State<_BillingInput> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      setState(() {});
      if (!focus.hasFocus) widget.onCommitted?.call();
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    // Keep the field role on this input, including in an IndexedSemantics
    // list child that otherwise merges the whole billing section.
    container: true,
    label: widget.label,
    textField: true,
    child: RaftRecipeInput(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      focusNode: focus,
      enabled: widget.enabled,
      mono: true,
      numeric: widget.numeric,
      upperCase: widget.upperCase,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onCommitted?.call(),
    ),
  );
}

/// The PlanSection ConfirmDialog message: `space-y-2` of the lead paragraph,
/// the `font-mono text-xs` breakdown lines and the closing paragraphs (the
/// dialog body supplies `text-sm leading-relaxed text-foreground-muted`).
class RaftBillingConfirmMessage extends StatelessWidget {
  const RaftBillingConfirmMessage({
    super.key,
    required this.lead,
    required this.lines,
    required this.closing,
    this.note,
  });
  final String lead;
  final List<String> lines, closing;

  /// A muted line right after [lead] (`text-footnote text-foreground-muted`,
  /// breaks anywhere: the checkout's promotion code review).
  final String? note;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final base = DefaultTextStyle.of(context).style;
    final mono = base.copyWith(
      fontFamily: t.monoFont,
      fontSize: 12,
      height: 16 / 12,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lead),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note!,
            style: base.copyWith(
              fontSize: 12,
              height: 16 / 12,
              color: RaftSettingsText(t).muted,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final line in lines) Text(line, style: mono),
        for (final paragraph in closing) ...[
          const SizedBox(height: 8),
          Text(paragraph),
        ],
      ],
    );
  }
}
