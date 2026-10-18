// Settings > Feedback ("My Feedback") inbox from the Web client:
// @botiverse/hands-feedback-react 0.4.1 FeedbackInbox (components.tsx
// :986-1360) + styles.css, mounted by settings/AboutFeedbackDialog.tsx with
// `hideHeaderTitle`. The app owns the transport and the copy's data; every
// class list (hands-feedback CSS and the raft-ui Tabs / TaskCard / Badge /
// MessageReferenceChip / EmptyState / Skeleton / Banner recipes it composes)
// is resolved here.
import 'hover_region.dart';

import 'package:flutter/material.dart';

import 'control_typography.dart';
import 'banner.dart';
import 'system_inset.dart';
import 'components.dart' show RaftButton;
import 'design_primitives.dart' show RaftControlVariant;
import 'feedback_workspace.dart'
    show RaftFeedbackCloseReason, RaftFeedbackCloseSplit;
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'panel_layout.dart' show raftCssBaseline;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'recipes/message_reference.g.dart';
import 'recipes/skeleton.g.dart';
import 'recipes/tabs.g.dart';
import 'recipes/task_card.g.dart';
import 'theme.dart';
import 'section_pager.dart';
import 'design_primitives.dart' show RaftLayoutMetrics;

/// `.hands-feedback-root { font-family: ui-sans-serif, system-ui, ... }`:
/// the platform UI face (an unknown family name resolves to the platform
/// default font on every Flutter platform).
const raftSystemUiFont = 'system-ui';

enum RaftFeedbackFilter { all, active, ended }

enum RaftFeedbackStatus { open, inProgress, resolved, closed }

@immutable
class RaftFeedbackTicketRow {
  const RaftFeedbackTicketRow({
    required this.id,
    required this.title,
    required this.date,
    required this.problem,
    required this.status,
    this.unreadLabel,
    this.unreadSemantics,
    this.closeReason,
  });
  final String id, title, date;

  /// The Close ticket split's default reason; null once closed (no split).
  final RaftFeedbackCloseReason? closeReason;

  /// Accessible unread label (`{count} unread`).
  final String? unreadSemantics;

  /// Kind chip: Bug (`bug`/`crash`) vs Idea (`feedback`).
  final bool problem;

  /// Display status (`closed` + `completed` already folded into resolved).
  final RaftFeedbackStatus status;

  /// Unread count badge (`99+` capped), null when read.
  final String? unreadLabel;
}

/// Text in the hands-feedback root face (`system-ui`); [line] defaults to
/// the inherited CSS `line-height: 1.5`.
TextStyle raftFeedbackText(
  RaftTokens t, {
  required double size,
  double? line,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => _system(t, size: size, line: line, weight: weight, color: color);

TextStyle _system(
  RaftTokens t, {
  required double size,
  double? line,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) => raftCssText.copyWith(
  fontFamily: raftSystemUiFont,
  fontFamilyFallback: const ['sans-serif'],
  fontSize: size,
  height: (line ?? size * 1.5) / size,
  fontWeight: weight,
  color: color ?? t.colors['foreground'] ?? t.strong,
  leadingDistribution: TextLeadingDistribution.even,
);

/// `.hands-feedback-middle { scrollbar-gutter: stable }`: Chromium reserves
/// its classic 15px scrollbar track on Linux and Windows (overlay
/// scrollbars elsewhere reserve nothing).
double raftFeedbackScrollGutter(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.linux || TargetPlatform.windows => 15,
      _ => 0,
    };

/// The CSS line box, not Flutter's ceiled paragraph height.
Widget _line(TextStyle style, Widget child) =>
    SizedBox(height: style.fontSize! * style.height!, child: child);

/// FeedbackInbox: the `.hands-feedback-header` band (62px, bottom border)
/// holding the trailing action, then the centred `max-width: 860px` content
/// (`padding: 18px`, `gap: 12px`) with the status Tabs (once any ticket
/// exists) over the list scroll: skeleton rows, the error banner, the empty
/// state, or the ticket cards (`gap: 10px`).
class RaftFeedbackInbox extends StatelessWidget {
  const RaftFeedbackInbox({
    super.key,
    required this.tickets,
    required this.filter,
    required this.onFilter,
    this.anyTickets,
    this.ticketsForFilter,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onOpen,
    this.onLoadMore,
    this.headerAction,
    this.onClose,
    this.closeDisabled = false,
  });

  /// A row's Close ticket split chose a reason (opens the confirmation).
  final void Function(String id, RaftFeedbackCloseReason reason)? onClose;
  final bool closeDisabled;

  /// Tickets visible under [filter].
  final List<RaftFeedbackTicketRow> tickets;

  /// Pure projection of the same accepted inbox for neighboring sections.
  final List<RaftFeedbackTicketRow> Function(RaftFeedbackFilter)?
  ticketsForFilter;

  /// Whether the account has any ticket at all (the Tabs render and the
  /// empty copy is per-filter only then); defaults to `tickets.isNotEmpty`.
  final bool? anyTickets;
  final RaftFeedbackFilter filter;
  final ValueChanged<RaftFeedbackFilter> onFilter;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onLoadMore;

  /// The header's trailing control (Web: `New feedback`).
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final any = anyTickets ?? tickets.isNotEmpty;
    Widget listFor(RaftFeedbackFilter filter) {
      final tickets = ticketsForFilter?.call(filter) ?? this.tickets;
      final emptyKind = any ? filter : RaftFeedbackFilter.all;
      final showEmpty = !loading && error == null && tickets.isEmpty;
      final emptyState = RaftFeedbackEmptyState(kind: emptyKind);
      return showEmpty && onLoadMore == null
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                primary: false,
                child: ConstrainedBox(
                  // Keep the original full-height, centred empty state when
                  // it fits; let larger text extend below the viewport.
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    // `[data-feedback-empty-scroll]`: 6px 2px 0.
                    padding: EdgeInsets.fromLTRB(
                      2,
                      6,
                      2 + raftFeedbackScrollGutter(context),
                      0,
                    ),
                    child: emptyState,
                  ),
                ),
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('feedback-inbox'),
              child: ListView(
                key: PageStorageKey(('feedback-inbox', filter)),
                primary: false,
                padding: raftScrollPadding(
                  context,
                  EdgeInsets.fromLTRB(
                    2,
                    2,
                    2 + raftFeedbackScrollGutter(context),
                    2,
                  ),
                ),
                children: [
                  // The zero-height pull-to-refresh row is a
                  // grid item: its `margin-bottom: -12px`
                  // cannot shrink the track, so the 12px grid
                  // gap after it stays.
                  const SizedBox(height: 12),
                  // No match in the loaded pages does not exhaust the inbox.
                  // Keep pagination reachable, including when the empty copy
                  // needs to scroll at larger text sizes.
                  if (showEmpty) emptyState,
                  if (loading)
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      const RaftUiSkeleton(height: 64),
                    ],
                  if (error != null) ...[
                    if (loading) const SizedBox(height: 12),
                    RaftBanner(
                      status: RaftBannerRecipeStatus.destructive,
                      size: RaftBannerRecipeSize.sm,
                      description: error!,
                      action: onRetry == null
                          ? null
                          : RaftButton(
                              label: 'Try again',
                              variant: RaftControlVariant.outline,
                              size: RaftButtonRecipeSize.sm,
                              onPressed: onRetry,
                            ),
                    ),
                  ],
                  for (final (i, ticket) in tickets.indexed) ...[
                    if (i > 0 || loading || error != null)
                      SizedBox(height: i > 0 ? 10 : 12),
                    RaftFeedbackTicketCard(
                      key: ValueKey('feedback-ticket-${ticket.id}'),
                      ticket: ticket,
                      onOpen: onOpen == null ? null : () => onOpen!(ticket.id),
                      onClose: onClose == null
                          ? null
                          : (reason) => onClose!(ticket.id, reason),
                      closeDisabled: closeDisabled,
                    ),
                  ],
                  if (onLoadMore != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RaftButton(
                        label: 'Load more',
                        variant: RaftControlVariant.outline,
                        onPressed: onLoadMore,
                      ),
                    ),
                  ],
                ],
              ),
            );
    }

    return ColoredBox(
      // `--hf-bg: var(--layer-canvas)`.
      color: t.colors['layer-canvas']!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftFeedbackHeaderBand(trailing: headerAction),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (any) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: RaftFeedbackFilterTabs(
                            value: filter,
                            onChanged: onFilter,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child:
                            any &&
                                ticketsForFilter != null &&
                                MediaQuery.sizeOf(context).width <
                                    RaftLayoutMetrics.desktopBreakpoint
                            ? RaftSectionPager<RaftFeedbackFilter>(
                                sections: RaftFeedbackFilter.values,
                                value: filter,
                                onChanged: onFilter,
                                builder: (context, value) => listFor(value),
                              )
                            : listFor(filter),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.hands-feedback-header`: `min-height: 62px` (58px under 640px),
/// `padding: 0 18px` (14px), `border-bottom: 1px solid var(--line-muted)`,
/// space-between; the title is hidden by the Settings host, so the actions
/// sit at the end.
class RaftFeedbackHeaderBand extends StatelessWidget {
  const RaftFeedbackHeaderBand({super.key, this.leading, this.trailing});
  final Widget? leading, trailing;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final narrow = MediaQuery.sizeOf(context).width <= 640;
    return Container(
      constraints: BoxConstraints(minHeight: narrow ? 58 : 62),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Row(
        children: [
          if (leading != null) Expanded(child: leading!) else const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// raft-ui `Tabs` (default variant, top placement) as FeedbackInbox renders
/// it: All / Active / Ended. Elegant: `p-px gap-1` list, `h-9 px-3.5`
/// tabs and the raised `bg-layer-panel` indicator under the active tab;
/// Brutal: the `border-2` list with `px-4 py-1.5` tabs, 2px dividers and
/// the `bg-primary-400` active tab.
class RaftFeedbackFilterTabs extends StatefulWidget {
  const RaftFeedbackFilterTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final RaftFeedbackFilter value;
  final ValueChanged<RaftFeedbackFilter> onChanged;

  static const labels = {
    RaftFeedbackFilter.all: 'All',
    RaftFeedbackFilter.active: 'Active',
    RaftFeedbackFilter.ended: 'Ended',
  };

  @override
  State<RaftFeedbackFilterTabs> createState() => _RaftFeedbackFilterTabsState();
}

class _RaftFeedbackFilterTabsState extends State<RaftFeedbackFilterTabs> {
  RaftFeedbackFilter? hovered;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    RaftTabsRecipeStyle style({bool active = false, bool hover = false}) =>
        RaftTabsRecipe.resolve(
          theme: t.recipeTheme,
          variant: RaftTabsRecipeVariant.default_,
          states: t.recipeStates(
            hovered: hover,
            extra: [if (active) 'data-active'],
          ),
          tokens: rt,
        );
    final base = style();
    final list = base.list;
    Widget tab(RaftFeedbackFilter value, int index) {
      final active = value == widget.value;
      final s = style(active: active, hover: hovered == value);
      final slot = s.tab;
      final text = _system(
        t,
        size: slot.fontSize ?? 13,
        line: slot.lineHeight == null
            ? null
            : slot.lineHeight! * (slot.fontSize ?? 13),
        weight: slot.fontWeight ?? FontWeight.w500,
        color: slot.color?.resolve(rt),
      ).copyWith(letterSpacing: slot.letterSpacing);
      final indicator = s.indicator;
      Widget body = Container(
        height: slot.height,
        padding: slot.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: slot.backgroundColor?.resolve(rt)),
        foregroundDecoration: t.brutal && index > 0
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: t.colors['line-strong']!, width: 2),
                ),
              )
            : null,
        child: _line(
          text,
          Text(
            // ignore: raft_lints/avoid_render_index_assertion -- `value` iterates the fixed filter tab ids that labels covers.
            raftText(context, RaftFeedbackFilterTabs.labels[value]!),
            maxLines: 1,
            softWrap: false,
            style: text,
          ),
        ),
      );
      if (active && !t.brutal) {
        // The indicator: 1px inset horizontally, ~1.67px vertically.
        body = Stack(
          children: [
            Positioned.fill(
              left: 1,
              right: 1,
              top: 1.671875,
              bottom: 1.671875,
              child: DecoratedBox(decoration: indicator.decoration(rt)),
            ),
            body,
          ],
        );
      }
      return RaftHoverRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovered = value),
        onExit: (_) => setState(() => hovered = null),
        child: Semantics(
          button: true,
          selected: active,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(value),
            child: body,
          ),
        ),
      );
    }

    final values = RaftFeedbackFilter.values;
    return Container(
      padding: list.padding,
      decoration: list.decoration(rt),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: list.columnGap ?? 0,
          children: [for (final (i, v) in values.indexed) tab(v, i)],
        ),
      ),
    );
  }
}

/// One ticket: raft-ui `TaskCard` (`px-3 py-2.5`) + `TaskCardRow`
/// (`items-start gap-2`): the single-line title, the 12px date
/// (`margin-top: 4px`, `line-height: 1.4`), the meta row (`gap: 5px`,
/// `margin-top: 5px`: kind chip + status badge), and the trailing unread
/// count (`Badge solid accent`, `min-width: 20px`, `rounded 6px`).
class RaftFeedbackTicketCard extends StatefulWidget {
  const RaftFeedbackTicketCard({
    super.key,
    required this.ticket,
    this.onOpen,
    this.onClose,
    this.closeDisabled = false,
  });
  final RaftFeedbackTicketRow ticket;
  final VoidCallback? onOpen;
  final ValueChanged<RaftFeedbackCloseReason>? onClose;
  final bool closeDisabled;

  @override
  State<RaftFeedbackTicketCard> createState() => _RaftFeedbackTicketCardState();
}

class _RaftFeedbackTicketCardState extends State<RaftFeedbackTicketCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final r = RaftTaskCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(hovered: hovered),
      tokens: rt,
    );
    final ticket = widget.ticket;
    final titleSlot = r.title;
    final title = _system(
      t,
      size: titleSlot.fontSize ?? 14,
      line: 20,
      weight: titleSlot.fontWeight ?? FontWeight.w500,
      color: titleSlot.color?.resolve(rt),
    );
    final date = _system(
      t,
      size: 12,
      line: 12 * 1.4,
      color: t.colors['foreground-muted'],
    );
    final root = r.root.withCssUsedBorderWidths();
    final card = RaftRecipeBox(
      style: root,
      tokens: rt,
      width: double.infinity,
      padding: root.padding,
      applyText: false,
      applyTransform: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: r.row.columnGap ?? 8,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(
                  title,
                  Text(
                    ticket.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: title,
                  ),
                ),
                const SizedBox(height: 4),
                _line(date, Text(ticket.date, maxLines: 1, style: date)),
                // ds-allow: Web hands-feedback/styles.css .hands-feedback-ticket-meta `margin-top: 5px`
                const SizedBox(height: 5),
                Wrap(
                  // ds-allow: Web hands-feedback/styles.css .hands-feedback-ticket-meta `gap: 5px`
                  spacing: 5,
                  // ds-allow: Web hands-feedback/styles.css .hands-feedback-ticket-meta `gap: 5px`
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RaftFeedbackKindChip(problem: ticket.problem),
                    RaftFeedbackStatusBadge(status: ticket.status),
                    if (ticket.closeReason != null && widget.onClose != null)
                      RaftFeedbackCloseSplit(
                        defaultReason: ticket.closeReason!,
                        disabled: widget.closeDisabled,
                        keySuffix: '-${ticket.id}',
                        onChoose: widget.onClose!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (ticket.unreadLabel != null)
            Semantics(
              container: true,
              label: ticket.unreadSemantics,
              excludeSemantics: ticket.unreadSemantics != null,
              child: RaftFeedbackUnreadCount(label: ticket.unreadLabel!),
            ),
        ],
      ),
    );
    return RaftHoverRegion(
      cursor: widget.onOpen == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      // `.hands-feedback-ticket-open`: a transparent button under the whole
      // card (z-index 0), labelled by the first line only; the card content
      // (z-index 1) opens the ticket too unless a control inside it (the
      // Close ticket split) took the tap.
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              button: widget.onOpen != null,
              label: ticket.title,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpen,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onOpen,
            child: card,
          ),
        ],
      ),
    );
  }
}

/// FeedbackKindChip: `MessageReferenceChip` (`info` Idea / `muted` Bug with
/// `--danger-muted` fill and danger icon), `.hands-feedback-reference-chip`:
/// 20px tall, `padding: 0 6px`, 10.5px bold, a 10px Lightbulb / Bug icon.
class RaftFeedbackKindChip extends StatelessWidget {
  const RaftFeedbackKindChip({super.key, required this.problem});
  final bool problem;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final s = RaftMessageReferenceRecipe.resolve(
      theme: t.recipeTheme,
      variant: problem
          ? RaftMessageReferenceRecipeVariant.muted
          : RaftMessageReferenceRecipeVariant.info,
      states: t.recipeStates(),
      tokens: rt,
    ).root;
    final decoration = s.decoration(rt);
    final fg = s.color?.resolve(rt) ?? t.strong;
    final iconColor = problem
        ? t.colors['danger']!
        : (s.target('& > svg')?.color?.resolve(rt) ?? fg);
    final text = RaftControlTypography.of(
      context,
      TextStyle(
        // The chip inherits the hands-feedback root face.
        fontFamily: raftSystemUiFont,
        fontSize: 10.5,
        height: 1,
        fontWeight: FontWeight.w700,
        color: fg,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: decoration.copyWith(
        color: problem ? t.colors['danger-muted'] : decoration.color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          RaftIcon(
            problem ? RaftGlyph.bug : RaftGlyph.lightbulb,
            size: 10,
            color: iconColor,
          ),
          Text(
            raftText(context, problem ? 'Bug' : 'Idea'),
            maxLines: 1,
            softWrap: false,
            style: text,
          ),
        ],
      ),
    );
  }
}

/// FeedbackStatusChip: `Badge solid` (open warning / in progress
/// information / resolved success / closed muted) with a 10px status icon.
class RaftFeedbackStatusBadge extends StatelessWidget {
  const RaftFeedbackStatusBadge({super.key, required this.status});
  final RaftFeedbackStatus status;

  static const labels = {
    RaftFeedbackStatus.open: 'Open',
    RaftFeedbackStatus.inProgress: 'In progress',
    RaftFeedbackStatus.resolved: 'Resolved',
    RaftFeedbackStatus.closed: 'Closed',
  };

  @override
  Widget build(BuildContext context) {
    final (variant, glyph) = switch (status) {
      RaftFeedbackStatus.open => (
        RaftBadgeRecipeVariant.warning,
        RaftGlyph.circle,
      ),
      RaftFeedbackStatus.inProgress => (
        RaftBadgeRecipeVariant.information,
        RaftGlyph.play,
      ),
      RaftFeedbackStatus.resolved => (
        RaftBadgeRecipeVariant.success,
        RaftGlyph.circleCheck,
      ),
      RaftFeedbackStatus.closed => (
        RaftBadgeRecipeVariant.muted,
        RaftGlyph.ban,
      ),
    };
    return RaftBadge(
      // ignore: raft_lints/avoid_render_index_assertion -- `labels` covers every RaftFeedbackStatus; status is that enum.
      label: raftText(context, labels[status]!),
      variant: variant,
      fontFamily: raftSystemUiFont,
      leading: Builder(
        builder: (context) => RaftIcon(
          glyph,
          size: 10,
          color: DefaultTextStyle.of(context).style.color,
        ),
      ),
    );
  }
}

/// `.hands-feedback-unread-count`: Badge solid accent, 6px radius,
/// `min-width: 20px`, inverse text, centred.
class RaftFeedbackUnreadCount extends StatelessWidget {
  const RaftFeedbackUnreadCount({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 20),
    child: RaftBadge(
      label: label,
      variant: RaftBadgeRecipeVariant.accent,
      fontFamily: raftSystemUiFont,
      foreground: RaftTokens.of(context).colors['foreground-inverse'],
      radius: 6,
      center: true,
    ),
  );
}

/// raft-ui `Skeleton` (block, as opposed to the Web app's own
/// ui/Skeleton [RaftSkeleton]): the recipe's `data-[variant=block]` fill and
/// radius, held at its first `animate-pulse` frame like Playwright's
/// disabled animations (reduced motion).
class RaftUiSkeleton extends StatelessWidget {
  const RaftUiSkeleton({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final s = RaftSkeletonRecipe.resolve(
      theme: t.recipeTheme,
      variant: RaftSkeletonRecipeVariant.block,
      states: t.recipeStates(extra: ['data-variant=block']),
      tokens: t.recipeTokens,
    ).root;
    return ExcludeSemantics(
      child: RaftRecipeBox(
        style: s,
        tokens: t.recipeTokens,
        width: double.infinity,
        height: height,
        applyOpacity: false,
      ),
    );
  }
}

/// The inbox EmptyState with the hands-feedback overrides: a 2px dashed
/// `--color-brutal-stone` box (`padding: 40px 24px 48px`) centring the 44px
/// cream icon tile (2px border, 2px hard shadow, `margin-bottom: 14px`), the
/// 15.5px bold title and the 13px / 1.55 muted body.
class RaftFeedbackEmptyState extends StatelessWidget {
  const RaftFeedbackEmptyState({super.key, required this.kind});
  final RaftFeedbackFilter kind;

  static const copy = {
    RaftFeedbackFilter.all: (
      'No feedback yet',
      'Share an idea or report a bug — team replies will show up here.',
    ),
    RaftFeedbackFilter.active: (
      'Nothing in progress',
      'Resolved or closed feedback lives under “Ended”.',
    ),
    RaftFeedbackFilter.ended: (
      'Nothing ended yet',
      'Feedback appears here once it’s resolved or closed.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // ignore: raft_lints/avoid_render_index_assertion -- `copy` covers every empty-state kind; kind is a fixed enum.
    final (title, body) = copy[kind]!;
    final strong = t.colors['line-strong']!;
    final titleStyle = _system(
      t,
      size: 15.5,
      line: t.brutal ? 28 : 20,
      weight: FontWeight.w700,
    );
    final bodyStyle = _system(
      t,
      size: 13,
      line: 13 * 1.55,
      color: t.colors['foreground-muted'],
    );
    return CustomPaint(
      key: const ValueKey('feedback-empty'),
      foregroundPainter: RaftDashedBorderPainter(t.product.brutalStone, 2),
      child: Padding(
        // `padding: 40px 24px 48px` inside the 2px dashed border.
        padding: const EdgeInsets.fromLTRB(26, 42, 26, 50),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.product.brutalCream,
                  border: Border.all(color: strong, width: 2),
                  boxShadow: [
                    BoxShadow(color: strong, offset: const Offset(2, 2)),
                  ],
                ),
                child: RaftIcon(
                  switch (kind) {
                    RaftFeedbackFilter.all => RaftGlyph.messageSquare,
                    RaftFeedbackFilter.active => RaftGlyph.clock,
                    RaftFeedbackFilter.ended => RaftGlyph.check,
                  },
                  size: 20,
                  color: t.colors['foreground'],
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      raftText(context, title),
                      textAlign: TextAlign.center,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      // `max-w-[32ch]` of the 13px face.
                      constraints: BoxConstraints(
                        maxWidth: 32 * _zeroWidth(bodyStyle),
                      ),
                      child: Text(
                        raftText(context, body),
                        textAlign: TextAlign.center,
                        style: bodyStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _zeroWidth(TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: '0', style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// CSS `border: 2px dashed` (Chromium: dashes of 3x the width, gaps evenly
/// distributed per side).
class RaftDashedBorderPainter extends CustomPainter {
  const RaftDashedBorderPainter(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    void side(Offset start, Offset direction, double length, bool vertical) {
      final dash = width * 3;
      final count = ((length + dash) / (dash * 2)).floor().clamp(1, 10000);
      final gap = count > 1 ? (length - count * dash) / (count - 1) : 0.0;
      for (var i = 0; i < count; i++) {
        final o = start + direction * (i * (dash + gap));
        canvas.drawRect(
          vertical
              ? Rect.fromLTWH(o.dx, o.dy, width, dash)
              : Rect.fromLTWH(o.dx, o.dy, dash, width),
          paint,
        );
      }
    }

    side(Offset.zero, const Offset(1, 0), size.width, false);
    side(Offset(0, size.height - width), const Offset(1, 0), size.width, false);
    side(Offset.zero, const Offset(0, 1), size.height, true);
    side(Offset(size.width - width, 0), const Offset(0, 1), size.height, true);
  }

  @override
  bool shouldRepaint(RaftDashedBorderPainter old) =>
      old.color != color || old.width != width;
}

/// The Settings host's own RaftButton for the header slot (`Button
/// size="xs"`, default variant).
class RaftFeedbackHeaderButton extends StatelessWidget {
  const RaftFeedbackHeaderButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftGlyph? glyph;

  @override
  Widget build(BuildContext context) => RaftButton(
    label: label,
    glyph: glyph,
    tone: RaftButtonRecipeVariant.default_,
    size: RaftButtonRecipeSize.xs,
    onPressed: onPressed,
  );
}

/// Exposed for the CSS baseline of inline text next to the chips.
double raftFeedbackBaseline(TextStyle style) => raftCssBaseline(style);
