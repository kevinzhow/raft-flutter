// Presentation of the Web channel / DM settings drawer, the only surface the
// product shows for them: `ChannelOverflowMenu` -> `OverflowSheet`
// (components/ui/OverflowSheet.tsx) holding the `MembersStrip`,
// `EditChannelDialog presentation="panel"` and `ChannelPreferencesSection`.
// The app adapter (apps/raft_flutter ChannelSettings) owns data, permissions
// and commands and passes plain values and callbacks in.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'channel_header.dart' show raftCollapseWhitespace;
import 'panel_edge.dart';
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'indicators.dart';
import 'localization.dart';
import 'mounted_avatar_recipe.dart';
import 'inline_badge_editor.dart' show RaftTouchTargetExpander;
import 'tooltip.dart';
import 'recipes/button_variants.g.dart';
import 'settings_controls.dart' show RaftSettingsRecipeButton;
import 'status_bar.dart';
import 'text_scaling.dart' show RaftScaled;
import 'page_tokens.dart';
import 'theme.dart';

/// The drawer popup of `OverflowSheet`: `inset-y-0 right-0 h-dvh w-full
/// max-w-[min(100vw,34rem)] flex-col rounded-none border-0
/// theme-brutal:border-l-2 theme-brutal:border-line-strong bg-layer-panel
/// theme-brutal:bg-brutal-cream`, a `h-panel-header` header and a
/// `min-h-0 flex-1 overflow-y-auto py-2` body.
class RaftOverflowSheet extends StatelessWidget {
  const RaftOverflowSheet({
    super.key,
    required this.title,
    required this.onClose,
    required this.children,
    this.badge,
    this.badgeTone = RaftBadgeRecipeVariant.success,
    this.subtitle,
    this.closeLabel = 'Close Channel Details and Settings',
    this.bodyKey,
    this.page = false,
  });

  /// The visible sheet title (`#general`, a DM peer's name).
  final String title;

  /// Visibility pill on the title row.
  final String? badge;
  final RaftBadgeRecipeVariant badgeTone;

  /// Mono description under the title (single truncated line).
  final String? subtitle;
  final String closeLabel;
  final VoidCallback onClose;
  final Key? bodyKey;

  /// Full-width route content with the shared mobile navigation geometry.
  final bool page;
  final List<Widget> children;

  /// Width of the drawer for a viewport: `max-w-[min(100vw,34rem)]`.
  static double widthFor(double viewport, {bool brutal = true}) =>
      math.min(viewport, brutal ? 544 : 448);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < RaftLayoutMetrics.desktopBreakpoint;
    // `h-panel-header` reads `--shell-header-height`, which the AppShell root
    // sets; the drawer portals out of it, so Web paints the 62px fallback.
    const headerHeight = RaftMetrics.brutalPanelHeader;
    final headerColor = t.colors['layer-panel']!;
    final edge = t.colors['line-muted']!;
    final titleStyle = raftCssTextStyle(
      family: t.bodyFont,
      // text-base font-bold leading-tight (16px / 1.25).
      step: (16, 20),
      weight: FontWeight.w700,
      color: t.strong,
    );
    final subtitleColor = t.strong.withValues(alpha: .85);
    // Above the default text size the header grows with its title and
    // description, which wrap instead of truncating.
    final grows = RaftScaled.grows(context);
    final identity = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  key: const ValueKey('channel-overflow-title-text'),
                  maxLines: grows ? null : 1,
                  overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                RaftBadge(
                  key: const ValueKey('channel-overflow-visibility-badge'),
                  label: raftText(context, badge!),
                  appearance: RaftBadgeRecipeAppearance.soft,
                  variant: badgeTone,
                  fontFamily: t.bodyFont,
                ),
              ],
            ],
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            raftCollapseWhitespace(subtitle!),
            key: const ValueKey('channel-overflow-identity-desc'),
            maxLines: grows ? null : 1,
            overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
            style: raftCssTextStyle(
              family: t.monoFont,
              step: RaftTextSteps.xs,
              color: subtitleColor,
            ),
          ),
      ],
    );
    final header = RaftStatusBarSource(
      color: headerColor,
      child: Container(
        height: grows ? null : headerHeight,
        constraints: grows
            ? const BoxConstraints(minHeight: headerHeight)
            : null,
        padding: grows
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: headerColor,
          border: Border(bottom: BorderSide(color: edge, width: 1)),
        ),
        child: Row(
          children: [
            if (mobile) ...[
              // Web's 28px drawer Back; touch area extended around it.
              RaftTouchTargetExpander(
                minSize: const Size.square(RaftMetrics.touchTarget),
                child: RaftSettingsRecipeButton(
                  key: const ValueKey('channel-overflow-back'),
                  label: '',
                  variant: RaftButtonRecipeVariant.default_,
                  glyph: RaftGlyph.arrowLeft,
                  glyphSize: 16,
                  size: RaftButtonRecipeSize.iconSm,
                  semanticLabel: raftText(context, closeLabel),
                  onPressed: onClose,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: identity),
          ],
        ),
      ),
    );

    return _OverflowDrawerFrame(
      page: page,
      child: Column(
        children: [
          header,
          Expanded(
            child: CustomScrollView(
              key: bodyKey,
              slivers: [
                for (final (i, child) in children.indexed)
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: i == 0 ? 8 : 0,
                      bottom: i == children.length - 1 ? 8 : 0,
                    ),
                    sliver: child is RaftOverflowPanelBody
                        ? RaftOverflowPanelBody.sliver(
                            key: child.key,
                            children: child.children,
                          )
                        : SliverToBoxAdapter(child: child),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `OverflowSheet bare`: the same drawer popup without its header, holding a
/// page that brings its own (the members page).
class RaftOverflowBareSheet extends StatelessWidget {
  const RaftOverflowBareSheet({
    super.key,
    required this.child,
    this.page = false,
  });
  final Widget child;
  final bool page;
  @override
  Widget build(BuildContext context) =>
      _OverflowDrawerFrame(page: page, child: child);
}

/// Drawer popup frame shared by [RaftOverflowSheet] and [RaftOverflowBareSheet]:
/// right-aligned `max-w-[min(100vw,34rem)]`, brutal `border-l-2`, paper fill.
class _OverflowDrawerFrame extends StatelessWidget {
  const _OverflowDrawerFrame({required this.page, required this.child});
  final bool page;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    final paper = t.colors['layer-panel']!;
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        key: const ValueKey('channel-overflow-sheet'),
        width: page
            ? size.width
            : RaftOverflowSheet.widthFor(size.width, brutal: false),
        height: double.infinity,
        child: Material(
          color: paper,
          // Elegant: the drawer is a `rounded-xl` card; brutal `rounded-none`.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(page ? 0 : 12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              // The shared rule (RaftPanelEdge): every width but the
              // full-width phone page draws `theme-brutal:border-l-2`.
              border: RaftPanelEdge.left(context, RaftPanelEdgeStyle.drawer),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(fontFamily: t.bodyFont, color: t.strong),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// `<div className="safe-bottom border-t border-line-muted px-4 pt-3
/// theme-brutal:border-black/10">` around the settings panel sections.
class RaftOverflowPanelBody extends StatelessWidget {
  const RaftOverflowPanelBody({super.key, required this.children})
    : _sliver = false;

  /// Same panel border and inset, with individual children laid out on demand.
  const RaftOverflowPanelBody.sliver({super.key, required this.children})
    : _sliver = true;
  final List<Widget> children;
  final bool _sliver;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (_sliver) {
      final decoration = BoxDecoration(
        border: Border(top: BorderSide(color: t.colors['line-muted']!)),
      );
      return DecoratedSliver(
        key: const ValueKey('channel-settings-panel'),
        decoration: decoration,
        sliver: SliverPadding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ).add(decoration.padding),
          sliver: SliverList.list(children: children),
        ),
      );
    }
    return Container(
      key: const ValueKey('channel-settings-panel'),
      // `safe-bottom` = 1rem + the bottom inset.
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.colors['line-muted']!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// `<div className="mt-5 mb-3">` heading + `mt-1 text-xs` description (the
/// one-word Info group above the name/description form).
class RaftOverflowGroupHeading extends StatelessWidget {
  const RaftOverflowGroupHeading({
    super.key,
    required this.title,
    this.description,
    this.bottom = 12,
  });
  final String title;
  final String? description;
  final double bottom;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      // FormSection `py-4` (v1.21.23) / `mt-5`.
      padding: EdgeInsets.only(top: t.formSectionWeb ? 16 : 20, bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, title),
            style: t.formSectionTitle(
              raftCssTextStyle(
                family: t.bodyFont,
                step: RaftTextSteps.base,
                weight: FontWeight.w700,
                color: t.strong,
              ),
            ),
          ),
          if (description != null) ...[
            SizedBox(height: t.formSectionWeb ? 2 : 4),
            Text(
              raftText(context, description!),
              style: t.formSectionDescription(
                raftCssTextStyle(
                  family: t.bodyFont,
                  step: RaftTextSteps.xs,
                  color: t.colors['foreground-muted'],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Name / description form of the panel: `section space-y-3 border-b
/// border-line-muted pb-5` with the in-section Cancel / Save row.
class RaftChannelInfoForm extends StatelessWidget {
  const RaftChannelInfoForm({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.onCancel,
    required this.onSave,
    this.nameEnabled = true,
    this.descriptionEnabled = true,
    this.nameHint,
    this.onSubmitName,
    this.canCancel = false,
    this.canSave = false,
    this.saving = false,
    this.savedLabel,
  });
  final TextEditingController nameController, descriptionController;
  final bool nameEnabled, descriptionEnabled, canCancel, canSave, saving;
  final String? nameHint;
  final ValueChanged<String>? onSubmitName;
  final VoidCallback onCancel, onSave;

  /// "Changes saved": the Save button turns into a success check for 1.5 s.
  final String? savedLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final hairline = t.colors['line-muted']!;
    final cancelButton = RaftSettingsRecipeButton(
      key: const ValueKey('channel-settings-discard-draft'),
      label: 'Cancel',
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      onPressed: !canCancel || saving ? null : onCancel,
    );
    final saveButton = RaftSettingsRecipeButton(
      key: const ValueKey('channel-settings-save-inline'),
      label: saving ? 'Saving…' : (savedLabel ?? 'Save'),
      glyph: savedLabel != null && !saving ? RaftGlyph.check : null,
      glyphSize: 12,
      variant: savedLabel != null
          ? RaftButtonRecipeVariant.success
          : RaftButtonRecipeVariant.accent,
      size: RaftButtonRecipeSize.sm,
      onPressed: !canSave || saving ? null : onSave,
    );
    return Container(
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
            family: t.bodyFont,
            hint: nameHint,
            child: RaftDialogTextInput(
              fieldKey: const ValueKey('channel-settings-name'),
              controller: nameController,
              placeholder: 'e.g. ai-research',
              enabled: nameEnabled,
              onSubmitted: onSubmitName,
            ),
          ),
          const SizedBox(height: 12),
          RaftProductFormField(
            label: 'Description',
            optional: true,
            labelWeight: FontWeight.w500,
            family: t.bodyFont,
            child: RaftDialogTextInput(
              fieldKey: const ValueKey('channel-settings-description'),
              controller: descriptionController,
              placeholder: 'What is this channel about?',
              multiline: true,
              enabled: descriptionEnabled,
            ),
          ),
          const SizedBox(height: 12),
          // Cancel / Save sit on one line; above the default text size they
          // wrap onto a second line when they no longer fit.
          if (RaftScaled.grows(context))
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [cancelButton, saveButton],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [cancelButton, const SizedBox(width: 8), saveButton],
            ),
        ],
      ),
    );
  }
}

/// One `OverflowActionRow` of the actions group: a `Button size="md"
/// variant="outline"` (Delete: `danger`), `w-full`, content centred.
@immutable
class RaftOverflowAction {
  const RaftOverflowAction({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.danger = false,
    this.disabled = false,
    this.id,
    this.semanticLabel,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onPressed;
  final bool danger, disabled;

  /// Web `data-testid` (also the Flutter widget key).
  final String? id;
  final String? semanticLabel;
}

/// `<section className="mt-5">` "Actions": `mt-2 flex flex-col gap-2`.
class RaftOverflowActions extends StatelessWidget {
  const RaftOverflowActions({
    super.key,
    required this.title,
    required this.actions,
  });
  final String title;
  final List<RaftOverflowAction> actions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Padding(
      key: const ValueKey('channel-settings-lifecycle-group'),
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, title),
            style: t.formSectionTitle(
              raftCssTextStyle(
                family: t.bodyFont,
                step: RaftTextSteps.base,
                weight: FontWeight.w700,
                color: t.strong,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            key: const ValueKey('channel-settings-action-zone'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                RaftSettingsRecipeButton(
                  key: actions[i].id == null
                      ? null
                      : ValueKey<String>(actions[i].id!),
                  label: actions[i].label,
                  glyph: actions[i].glyph,
                  glyphSize: 14,
                  variant: actions[i].danger
                      ? RaftButtonRecipeVariant.danger
                      : RaftButtonRecipeVariant.outline,
                  size: RaftButtonRecipeSize.md,
                  expand: true,
                  semanticLabel: actions[i].semanticLabel,
                  onPressed: actions[i].disabled ? null : actions[i].onPressed,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// One avatar tile of the [RaftMembersStrip].
@immutable
class RaftStripMember {
  const RaftStripMember({required this.label, required this.avatar});
  final String label;
  final Widget avatar;
}

/// `MembersStrip` (ChannelOverflowMenu.tsx): `px-4 pb-3 pt-3` with a count row
/// and `mt-2 flex flex-wrap content-start items-center gap-2` 36px tiles,
/// at most three rows; the add tile always keeps its slot and `+N` replaces
/// the tail once members overflow.
class RaftMembersStrip extends StatelessWidget {
  const RaftMembersStrip({
    super.key,
    required this.heading,
    required this.summary,
    required this.members,
    required this.onOpen,
    this.loading = false,
    this.onAdd,
    this.addLabel = 'Add Member',
  });
  static const maxRows = 3;
  static const double tile = 36, gap = 8;
  final String heading, summary, addLabel;
  final List<RaftStripMember> members;
  final bool loading;
  final VoidCallback onOpen;
  final VoidCallback? onAdd;

  /// Columns that fit in [width] (`getStripColumnCount`).
  static int columnsFor(double width) =>
      width <= 0 ? 7 : math.max(1, ((width + gap) / (tile + gap)).floor());

  /// `getVisibleMemberLimit`: add always keeps a slot, overflow reserves one.
  static int visibleLimit(int total, int columns) {
    final capacity = maxRows * columns;
    return total + 1 <= capacity ? total : math.max(0, capacity - 2);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.colors['foreground-muted']!;
    final headingStyle = t.formSectionTitle(
      raftCssTextStyle(
        family: t.bodyFont,
        step: RaftTextSteps.base,
        weight: FontWeight.w700,
        color: t.strong,
      ),
    );
    final summaryStyle = raftCssTextStyle(
      family: t.bodyFont,
      step: RaftTextSteps.xs,
      weight: FontWeight.w700,
      color: muted,
    );
    final headingText = Text(
      raftText(context, heading),
      key: const ValueKey('channel-overflow-members-heading'),
      style: headingStyle,
    );
    final chevron = RaftIcon(
      RaftGlyph.chevronRight,
      size: 14,
      color: summaryStyle.color,
    );
    return Padding(
      key: const ValueKey('channel-overflow-members-strip'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              key: const ValueKey('channel-overflow-members-entry'),
              behavior: HitTestBehavior.opaque,
              onTap: onOpen,
              child: RaftScaled.grows(context)
                  // Heading over summary when they no longer fit one row.
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        headingText,
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(child: Text(summary, style: summaryStyle)),
                            const SizedBox(width: 4),
                            chevron,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        headingText,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: summaryStyle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              chevron,
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = columnsFor(constraints.maxWidth);
              final limit = visibleLimit(members.length, columns);
              final shown = members.take(limit).toList();
              final overflow = members.length - shown.length;
              return Wrap(
                key: const ValueKey('channel-overflow-members-grid'),
                spacing: gap,
                runSpacing: gap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (loading)
                    for (var i = 0; i < 3; i++)
                      SizedBox.square(
                        key: ValueKey('channel-overflow-member-skeleton-$i'),
                        dimension: tile,
                        child: RaftSkeleton(
                          variant: RaftSkeletonVariant.circle,
                          width: tile,
                          height: tile,
                        ),
                      ),
                  if (!loading)
                    for (final member in shown)
                      RaftTooltip(
                        message: member.label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onOpen,
                          child: Semantics(
                            button: true,
                            label: member.label,
                            excludeSemantics: true,
                            child: member.avatar,
                          ),
                        ),
                      ),
                  if (!loading && overflow > 0)
                    GestureDetector(
                      key: const ValueKey('channel-overflow-members-more'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onOpen,
                      child: _TextTile('+$overflow'),
                    ),
                  if (onAdd != null)
                    RaftTooltip(
                      message: raftText(context, addLabel),
                      child: GestureDetector(
                        key: const ValueKey(
                          'channel-overflow-members-add-tile',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: loading ? null : onAdd,
                        child: Semantics(
                          button: true,
                          label: raftText(context, addLabel),
                          excludeSemantics: true,
                          child: Opacity(
                            opacity: loading ? .4 : 1,
                            child: const _TextTile(
                              '+',
                              dashed: true,
                              large: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// `AvatarSlot context="panel-header" type="human"` with a text child (`+N`,
/// or the dashed `+` add tile).
class _TextTile extends StatelessWidget {
  const _TextTile(this.text, {this.dashed = false, this.large = false});
  final String text;
  final bool dashed, large;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final r = RaftMountedAvatarRecipe(
      t,
      RaftMountedAvatarContext.panelHeader,
      RaftMountedAvatarIdentity.human,
    );
    final frame = RaftMountedAvatarFrame(
      name: text,
      avatarContext: RaftMountedAvatarContext.panelHeader,
      child: Center(
        child: Text(
          text,
          // The tile is a fixed-size avatar: its text keeps its size.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: t.bodyFont,
            // AvatarSlot human text: text-sm font-bold; the add tile text-lg.
            fontSize: large ? 18 : 14,
            height: large ? 28 / 18 : 20 / 14,
            fontWeight: FontWeight.w700,
            color: r.placeholderForeground,
          ),
        ),
      ),
    );
    if (!dashed) return frame;
    return Stack(
      children: [
        frame,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DashedEdgePainter(
                color: r.border,
                width: r.borderWidth,
                radius: r.radius,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// CSS `border-dashed` over the avatar's solid border ring.
class _DashedEdgePainter extends CustomPainter {
  const _DashedEdgePainter({
    required this.color,
    required this.width,
    required this.radius,
  });
  final Color color;
  final double width, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - width,
      size.height - width,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.max(0, radius - inset)),
        ),
      );
    // Dash the ring on top of the avatar's solid border.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    final dash = width * 3, space = width * 3;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + space;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedEdgePainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}

/// `channel-overflow-unsaved-prompt`: `Modal layer={1}` holding a
/// `w-full max-w-sm card-brutal p-6` with the title (`mb-4 text-lg
/// font-bold`), the message (`mb-5 text-sm text-black/70`) and three `sm`
/// actions (`flex justify-end gap-3`): Keep editing / Discard changes /
/// Save and close (the last only while the draft can be saved).
class RaftUnsavedChangesPrompt extends StatelessWidget {
  const RaftUnsavedChangesPrompt({
    super.key,
    required this.message,
    required this.onKeepEditing,
    required this.onDiscard,
    this.onSaveAndClose,
    this.busy = false,
  });
  final String message;
  final VoidCallback onKeepEditing, onDiscard;

  /// Null hides Save and close (an unsent invitation cannot be saved here).
  final VoidCallback? onSaveAndClose;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftModalBackdrop(
      child: _PromptCard(
        key: const ValueKey('channel-overflow-unsaved-prompt'),
        maxWidth: 384,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                raftText(context, 'Unsaved changes'),
                style: raftCssTextStyle(
                  family: t.bodyFont,
                  step: RaftTextSteps.lg,
                  weight: FontWeight.w700,
                  color: t.strong,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                raftText(context, message),
                style: raftCssTextStyle(
                  family: t.bodyFont,
                  step: RaftTextSteps.sm,
                  color: Colors.black.withValues(alpha: .7),
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width <
                RaftLayoutMetrics.desktopBreakpoint)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  RaftSettingsRecipeButton(
                    label: 'Keep Editing',
                    variant: RaftButtonRecipeVariant.outline,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: busy ? null : onKeepEditing,
                  ),
                  RaftSettingsRecipeButton(
                    key: const ValueKey('channel-overflow-unsaved-discard'),
                    label: 'Discard Changes',
                    variant: RaftButtonRecipeVariant.warning,
                    size: RaftButtonRecipeSize.sm,
                    onPressed: busy ? null : onDiscard,
                  ),
                  if (onSaveAndClose != null) ...[
                    RaftSettingsRecipeButton(
                      key: const ValueKey('channel-overflow-unsaved-save'),
                      label: busy ? 'Saving…' : 'Save and Close',
                      variant: RaftButtonRecipeVariant.accent,
                      size: RaftButtonRecipeSize.sm,
                      onPressed: busy ? null : onSaveAndClose,
                    ),
                  ],
                ],
              )
            else
              // `flex justify-end gap-3` (no wrap): the row may be a hair wider
              // than the card, like the unwrapped CSS flex.
              SizedBox(
                height: 28,
                child: OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RaftSettingsRecipeButton(
                        label: 'Keep Editing',
                        variant: RaftButtonRecipeVariant.outline,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: busy ? null : onKeepEditing,
                      ),
                      const SizedBox(width: 12),
                      RaftSettingsRecipeButton(
                        key: const ValueKey('channel-overflow-unsaved-discard'),
                        label: 'Discard Changes',
                        variant: RaftButtonRecipeVariant.warning,
                        size: RaftButtonRecipeSize.sm,
                        onPressed: busy ? null : onDiscard,
                      ),
                      if (onSaveAndClose != null) ...[
                        const SizedBox(width: 12),
                        RaftSettingsRecipeButton(
                          key: const ValueKey('channel-overflow-unsaved-save'),
                          label: busy ? 'Saving…' : 'Save and Close',
                          variant: RaftButtonRecipeVariant.accent,
                          size: RaftButtonRecipeSize.sm,
                          onPressed: busy ? null : onSaveAndClose,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The `card-brutal` utility (index.css): Elegant `border border-line-muted
/// bg-layer-panel shadow-raft-md` (square), Brutal `border-2 border-black
/// bg-white shadow-brutal` (the Card recipe paints that one).
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    super.key,
    required this.maxWidth,
    required this.padding,
    required this.child,
  });
  final double maxWidth;
  final EdgeInsets padding;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: t.colors['layer-panel'],
          border: Border.all(color: t.colors['line-muted']!),
          boxShadow: t.themeShadows.md.outer,
        ),
        child: child,
      ),
    );
  }
}

/// Opens the settings drawer the way Web mounts its `Drawer`: a modal route
/// whose scrim is the drawer backdrop. The route never dismisses itself;
/// the drawer's own scrim / Escape handling decides (unsaved-draft guard).
Future<T?> showRaftOverflowSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  barrierColor: RaftTokens.of(context).colors['layer-backdrop'],
  builder: builder,
);

/// A failure notice above the panel when it has no form of its own to host
/// the warning banner (a DM, a channel the viewer left).
class RaftOverflowNotice extends StatelessWidget {
  const RaftOverflowNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: RaftWarningBanner(message),
  );
}

/// The DM drawer's root view: `px-4 pb-2` around the shared preferences.
class RaftOverflowDmBody extends StatelessWidget {
  const RaftOverflowDmBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: child);
}

/// Cold-load placeholder of the panel body (server flags not known yet).
class RaftOverflowLoading extends StatelessWidget {
  const RaftOverflowLoading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 32),
    child: Center(child: RaftSpinner()),
  );
}

/// The form's `Banner intent="warning"` (`space-y-5`: 20px below it).
class RaftOverflowFormError extends StatelessWidget {
  const RaftOverflowFormError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: RaftWarningBanner(message),
  );
}
