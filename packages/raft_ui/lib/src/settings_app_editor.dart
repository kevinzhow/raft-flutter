// Settings > Workspace > Applications: the app editor modal of the Web client
// (raft-source 26f77ef, packages/web/src/components/settings/SettingsPanel.tsx
// IntegrationsSection `showRegisterDrawer` + ConnectedAppEditorSection +
// DeclaredScopesPicker, AppNotificationsControls.tsx DeveloperAppPermissions /
// DeveloperAppNotifications). A `max-w-5xl` Card in the Web `Modal`: header
// (logo, title, close + save), optional error / one-time secret strip, then a
// section rail (220px column on md and up, a horizontal strip on phones) next
// to the scrolling sections (Profile, Login with Raft, App permissions,
// Webhook, Distribution, Danger zone). The app owns the state and the API; the
// geometry, colours and copy live here.
import 'raft/checkbox.dart' show RaftCheckbox;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftInteractive, RaftTypography;
import 'dialog_card.dart' show RaftCloseButton;
import 'form_controls.dart' show RaftField;
import 'icons.dart';

import 'list_items.dart' show RaftSectionEyebrow;
import 'localization.dart';
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipe, RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'recipes/card.g.dart';
import 'recipes/table.g.dart';
import 'select_field.dart';
import 'settings_applications.dart' show RaftAppLogo, RaftAppLogoSize;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'raft/switch.dart';
import 'tooltip.dart';
import 'viewport_breakpoints.dart';

/// `appEditorSections` entry: the rail button and the section card it scrolls to.
@immutable
class RaftAppEditorSection {
  const RaftAppEditorSection({
    required this.id,
    required this.glyph,
    required this.railLabel,
    required this.title,
    required this.description,
    required this.status,
    required this.child,
    this.experimentalBadge = false,
    this.warning = false,
  });

  /// `profile`, `login`, `permissions`, `notifications`, `distribution`, `danger`.
  final String id;
  final RaftGlyph glyph;
  final String railLabel, title, description, status;

  /// `AppNotificationsLabel`: the title carries the Experimental badge.
  final bool experimentalBadge;

  /// `tone="warning"` (the Danger zone card).
  final bool warning;
  final Widget child;
}

/// Tailwind `space-y-*` for a [Column]: [gap] between non-null children.
class RaftAppEditorStack extends StatelessWidget {
  const RaftAppEditorStack({
    super.key,
    required this.children,
    this.gap = RaftSpace.x4,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: crossAxisAlignment,
    spacing: gap,
    children: children,
  );
}

/// raft-ui `Card` root with a callsite fill and optional clip / size.
class _EditorCard extends StatelessWidget {
  const _EditorCard({
    super.key,
    required this.child,
    this.fill,
    this.maxWidth,
    this.height,
    this.clip = false,
  });
  final Widget child;
  final Color? fill;
  final double? maxWidth, height;
  final bool clip;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final root = RaftCardRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: tokens,
    ).root;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: RaftRecipeBox(
        style: root.withCssUsedBorderWidths(),
        tokens: tokens,
        width: double.infinity,
        height: height,
        clip: clip,
        applyText: false,
        decorationOverride: fill == null
            ? null
            : (d) => d.copyWith(color: fill),
        child: DefaultTextStyle.merge(
          style: root.textStyle(tokens),
          child: child,
        ),
      ),
    );
  }
}

/// The editor modal body. Wrap it in [RaftModalBackdrop] (`Modal`).
class RaftConnectedAppEditorCard extends StatefulWidget {
  const RaftConnectedAppEditorCard({
    super.key,
    required this.eyebrow,
    required this.name,
    required this.description,
    required this.initials,
    required this.closeLabel,
    required this.onClose,
    required this.submitLabel,
    required this.sections,
    this.logoUrl,
    this.onSubmit,
    this.banner,
    this.railLabel = 'App editor sections',
  });
  final String eyebrow, name, description, initials, closeLabel, submitLabel;
  final String? logoUrl;
  final String railLabel;
  final VoidCallback onClose;

  /// null disables the save button (`submitting || appNotificationLoading`).
  final VoidCallback? onSubmit;

  /// Error and one-time secret rows under the header.
  final Widget? banner;
  final List<RaftAppEditorSection> sections;
  @override
  State<RaftConnectedAppEditorCard> createState() =>
      _RaftConnectedAppEditorCardState();
}

class _RaftConnectedAppEditorCardState
    extends State<RaftConnectedAppEditorCard> {
  final scroll = ScrollController();
  final rail = ScrollController();
  late final Map<String, GlobalKey> sectionKeys = {
    for (final s in widget.sections) s.id: GlobalKey(),
  };
  final Map<String, GlobalKey> railKeys = {};
  late String active = widget.sections.first.id;

  @override
  void initState() {
    super.initState();
    scroll.addListener(syncFromScroll);
  }

  @override
  void dispose() {
    scroll.dispose();
    rail.dispose();
    super.dispose();
  }

  /// `syncAppEditorSectionFromScroll`: the last section whose top passed the
  /// activation line (16px under the content top); the last one at the bottom.
  void syncFromScroll() {
    if (!scroll.hasClients) return;
    final position = scroll.position;
    final ids = [for (final s in widget.sections) s.id];
    var next = ids.first;
    if (position.maxScrollExtent - position.pixels <= 2) {
      next = ids.last;
    } else {
      final viewport =
          (position.context.storageContext.findRenderObject() as RenderBox?);
      if (viewport == null || !viewport.attached) return;
      final top = viewport.localToGlobal(Offset.zero).dy + 16;
      for (final id in ids) {
        final box =
            sectionKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) break;
        if (box.localToGlobal(Offset.zero).dy > top) break;
        next = id;
      }
    }
    if (next != active) {
      setState(() => active = next);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = railKeys[next]?.currentContext;
        if (context != null && context.mounted && rail.hasClients) {
          Scrollable.ensureVisible(
            context,
            alignment: .5,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  void jumpTo(String id) {
    setState(() => active = id);
    final context = sectionKeys[id]?.currentContext;
    if (context == null || !scroll.hasClients) return;
    final box = context.findRenderObject() as RenderBox;
    final viewport =
        scroll.position.context.storageContext.findRenderObject() as RenderBox;
    final delta =
        box.localToGlobal(Offset.zero).dy -
        viewport.localToGlobal(Offset.zero).dy -
        16;
    scroll.animateTo(
      (scroll.offset + delta).clamp(0, scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final widget = this.widget;
    final band = raftBreakpointWidth(context);
    final wide = band >= 768;
    final inline = band >= 640;
    final maxHeight = math.min(832.0, MediaQuery.sizeOf(context).height - 32);
    final headerFill = t.colors['layer-canvas-muted']!;
    final edge = BorderSide(color: text.edge, width: 2);
    String tr(String s) => raftText(context, s);

    final identity = Row(
      children: [
        RaftAppLogo(
          initials: widget.initials,
          logoUrl: widget.logoUrl,
          size: RaftAppLogoSize.md,
        ),
        const SizedBox(width: RaftSpace.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RaftSectionEyebrow(tr(widget.eyebrow)),
              const SizedBox(height: RaftSpace.half),
              Semantics(
                header: true,
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.body(
                    t,
                    size: 20,
                    line: 28,
                    weight: RaftTypography.black(t),
                    color: text.strong,
                  ),
                ),
              ),
              const SizedBox(height: RaftSpace.half),
              Text(
                tr(widget.description),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  color: t.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      spacing: RaftSpace.x2,
      children: [
        RaftCloseButton(onPressed: widget.onClose, tooltip: widget.closeLabel),
        RaftSettingsRecipeButton(
          key: const ValueKey('connected-app-editor-submit'),
          label: widget.submitLabel,
          variant: RaftButtonRecipeVariant.accent,
          size: RaftButtonRecipeSize.sm,
          onPressed: widget.onSubmit,
        ),
      ],
    );
    final header = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x4,
        vertical: RaftSpace.x3,
      ),
      decoration: BoxDecoration(
        color: headerFill,
        border: Border(bottom: edge),
      ),
      child: inline
          ? Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: RaftSpace.x3),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x3,
              children: [
                identity,
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ),
    );

    Widget railItem(RaftAppEditorSection s) {
      final selected = s.id == active;
      final key = railKeys.putIfAbsent(s.id, GlobalKey.new);
      final radius = RaftButtonRecipe.resolve(
        theme: t.recipeTheme,
        variant: RaftButtonRecipeVariant.ghost,
        size: RaftButtonRecipeSize.sm,
        states: t.recipeStates(),
        tokens: t.recipeTokens,
      ).root.borderRadius?.resolve(Directionality.of(context));
      final item = RaftInteractive(
        key: key,
        semanticLabel: s.railLabel,
        selected: selected,
        onPressed: () => jumpTo(s.id),
        builder: (context, state) => ConstrainedBox(
          constraints: BoxConstraints(minWidth: wide ? 0 : 155),
          child: RaftSettingsCard.box(
            t,
            radius: radius,
            color: selected ? (t.colors['primary-soft']!) : t.panel,
            padding: const EdgeInsets.symmetric(
              horizontal: RaftSpace.x3,
              vertical: RaftSpace.x2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: RaftSpace.x2,
                  children: [
                    RaftIcon(s.glyph, size: 14, color: text.strong),
                    Flexible(
                      child: Text(
                        tr(s.railLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RaftTypography.body(
                          t,
                          size: 12,
                          line: 16,
                          weight: RaftTypography.black(t),
                          color: text.strong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RaftSpace.x1),
                // `text-[10px]` inherits the Button's 4/3 line height (13.33px);
                // Chromium lays the rail out 1/3px tighter on the phone.
                SizedBox(
                  height: wide ? 10 * 4 / 3 : 13,
                  child: Text(
                    s.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RaftTypography.body(
                      t,
                      size: 10,
                      line: wide ? 10 * 4 / 3 : 13,
                      weight: FontWeight.w700,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return item;
    }

    final railBox = Container(
      key: const ValueKey('connected-app-editor-rail'),
      width: wide ? 220 : null,
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        color: headerFill,
        border: wide ? Border(right: edge) : Border(bottom: edge),
      ),
      child: Semantics(
        container: true,
        label: widget.railLabel,
        child: wide
            ? SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: RaftSpace.x2,
                  children: [for (final s in widget.sections) railItem(s)],
                ),
              )
            : SingleChildScrollView(
                controller: rail,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: RaftSpace.x2,
                  children: [for (final s in widget.sections) railItem(s)],
                ),
              ),
      ),
    );
    final content = Container(
      key: const ValueKey('connected-app-editor-content'),
      color: t.panel,
      child: SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.all(RaftSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x4,
          children: [
            for (final s in widget.sections)
              KeyedSubtree(
                key: sectionKeys[s.id],
                child: RaftAppEditorSectionCard(section: s),
              ),
          ],
        ),
      ),
    );
    return DefaultTextStyle.merge(
      style: RaftTypography.body(t, size: 14, line: 20, color: text.strong),
      child: _EditorCard(
        key: const ValueKey('connected-app-editor'),
        maxWidth: 1024,
        height: maxHeight,
        clip: true,
        fill: t.panel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (widget.banner != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RaftSpace.x4,
                  vertical: RaftSpace.x3,
                ),
                decoration: BoxDecoration(
                  color: t.panel,
                  border: Border(bottom: edge),
                ),
                child: widget.banner,
              ),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        railBox,
                        Expanded(child: content),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        railBox,
                        Expanded(child: content),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `ConnectedAppEditorSection`: a Card with a muted header (title, description,
/// the status chip) over the white body.
class RaftAppEditorSectionCard extends StatelessWidget {
  const RaftAppEditorSectionCard({super.key, required this.section});
  final RaftAppEditorSection section;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final inline = raftBreakpointWidth(context) >= 640;
    final warning = section.warning;
    final fill = warning
        ? (t.colors['warning-soft']!)
        : (t.colors['layer-canvas-muted']!);
    final headerFill = t.colors['layer-canvas-muted']!;
    final title = Wrap(
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            raftText(context, section.title),
            style: RaftTypography.body(
              t,
              size: 16,
              line: 24,
              weight: RaftTypography.black(t),
              color: text.strong,
            ),
          ),
        ),
        if (section.experimentalBadge)
          const RaftSettingsRecipeBadge(
            label: 'Experimental',
            variant: RaftBadgeRecipeVariant.success,
          ),
      ],
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: RaftSpace.half),
        Text(
          raftText(context, section.description),
          style: RaftTypography.body(
            t,
            size: 12,
            line: 12 * 1.625,
            color: text.muted,
          ),
        ),
      ],
    );
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x2,
        vertical: RaftSpace.x1,
      ),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: text.edge, width: 1),
      ),
      child: Text(
        section.status,
        style: RaftTypography.mono(
          t,
          size: 10,
          line: 15,
          color: text.strong,
        ).copyWith(fontWeight: RaftTypography.black(t)),
      ),
    );
    return _EditorCard(
      key: ValueKey('connected-app-editor-section-${section.id}'),
      fill: fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RaftSpace.x4,
              vertical: RaftSpace.x3,
            ),
            decoration: BoxDecoration(
              color: headerFill,
              border: Border(bottom: BorderSide(color: text.edge, width: 2)),
            ),
            child: inline
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: RaftSpace.x2),
                      chip,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x2,
                    children: [copy, chip],
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(RaftSpace.x4),
            color: t.panel,
            child: section.child,
          ),
        ],
      ),
    );
  }
}

/// A `FormField labelStyle="plain" size="compact"` (optional / hint / error).
class RaftAppEditorField extends StatelessWidget {
  const RaftAppEditorField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
    this.hint,
    this.error,
  });
  final String label;
  final Widget child;
  final bool optional;
  final String? hint, error;
  @override
  Widget build(BuildContext context) => RaftField(
    label: raftText(context, label),
    optional: optional,
    optionalLabel: raftText(context, '(optional)'),
    hint: hint == null ? null : raftText(context, hint!),
    error: error,
    compact: true,
    child: child,
  );
}

/// Profile: `grid gap-4 sm:grid-cols-[140px_minmax(0,1fr)]` (logo | fields).
class RaftAppEditorProfileGrid extends StatelessWidget {
  const RaftAppEditorProfileGrid({
    super.key,
    required this.logo,
    required this.fields,
  });
  final Widget logo, fields;
  @override
  Widget build(BuildContext context) => raftBreakpointWidth(context) >= 640
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: logo),
            const SizedBox(width: RaftSpace.x4),
            Expanded(child: fields),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x4,
          children: [logo, fields],
        );
}

/// The 120px dashed logo well with the app logo and (when saved) the
/// upload / reset buttons.
class RaftAppEditorLogoWell extends StatelessWidget {
  const RaftAppEditorLogoWell({
    super.key,
    required this.initials,
    this.logoUrl,
    this.actions = const [],
  });
  final String initials;
  final String? logoUrl;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: RaftSpace.x2,
      children: [
        CustomPaint(
          foregroundPainter: _DashedBorder(
            color: t.colors['line-strong']!,
            width: 2,
          ),
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            color: t.colors['layer-canvas-muted'],
            child: RaftAppLogo(
              initials: initials,
              logoUrl: logoUrl,
              size: RaftAppLogoSize.lg,
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: actions,
          ),
      ],
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    // CSS `border-dashed`: dashes of 2 x width with 2 x width gaps, snapped so
    // each side starts and ends on a dash.
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.fill;
    final dash = width * 3, gapTarget = width * 2;
    void side(double length, Offset origin, bool horizontal) {
      final count = math.max(
        1,
        ((length + gapTarget) / (dash + gapTarget)).round(),
      );
      final gap = count == 1 ? 0.0 : (length - dash * count) / (count - 1);
      for (var i = 0; i < count; i++) {
        final at = i * (dash + gap);
        final rect = horizontal
            ? Rect.fromLTWH(origin.dx + at, origin.dy, dash, width)
            : Rect.fromLTWH(origin.dx, origin.dy + at, width, dash);
        canvas.drawRect(rect, paint);
      }
    }

    side(size.width, Offset.zero, true);
    side(size.width, Offset(0, size.height - width), true);
    side(size.height, Offset.zero, false);
    side(size.height, Offset(size.width - width, 0), false);
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.width != width;
}

/// Callout strips: `border-l-4 ... px-3 py-2 text-xs`.
enum RaftAppEditorCalloutTone { muted, warning, success }

class RaftAppEditorCallout extends StatelessWidget {
  const RaftAppEditorCallout(
    this.message, {
    super.key,
    this.tone = RaftAppEditorCalloutTone.muted,
    this.bold = false,
  });
  final String message;
  final RaftAppEditorCalloutTone tone;

  /// `font-bold` (the muted strips).
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final (edge, fill) = switch (tone) {
      RaftAppEditorCalloutTone.muted => (
        t.colors['line-muted']!,
        t.colors['layer-canvas-muted']!,
      ),
      RaftAppEditorCalloutTone.warning => (
        t.colors['warning']!,
        t.colors['warning-soft']!,
      ),
      RaftAppEditorCalloutTone.success => (
        t.product.brutalLime,
        Color.alphaBlend(t.product.brutalLime.withValues(alpha: .15), t.panel),
      ),
    };
    final color = tone == RaftAppEditorCalloutTone.muted ? t.muted : t.muted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x3,
        vertical: RaftSpace.x2,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: Border(left: BorderSide(color: edge, width: 4)),
      ),
      child: Text(
        raftText(context, message),
        style: RaftTypography.body(
          t,
          size: 12,
          line: bold ? 16 : 12 * 1.625,
          weight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
    );
  }
}

/// A bordered block inside a section: `border bg-layer-panel p-3
/// shadow-raft-sm` (Brutal `border-2 border-black bg-white shadow-brutal-sm`).
class RaftAppEditorBox extends StatelessWidget {
  const RaftAppEditorBox({
    super.key,
    required this.child,
    this.cream = false,
    this.shadow = true,
    this.softBorder = false,
  });
  final Widget child;

  /// `bg-layer-canvas-muted theme-brutal:bg-brutal-cream`.
  final bool cream;

  /// `shadow-raft-sm theme-brutal:shadow-brutal-sm`.
  final bool shadow;

  /// `theme-brutal:border-black/20` (no shadow blocks).
  final bool softBorder;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final fill = cream ? (t.colors['layer-canvas-muted']!) : t.panel;
    if (shadow && !softBorder) {
      return RaftSettingsCard.box(
        t,
        color: fill,
        padding: const EdgeInsets.all(RaftSpace.x3),
        child: child,
      );
    }
    return Container(
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: text.edge, width: 1),
      ),
      child: child,
    );
  }
}

/// `flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between`: a
/// title + copy block with its action.
class RaftAppEditorActionRow extends StatelessWidget {
  const RaftAppEditorActionRow({
    super.key,
    required this.title,
    required this.description,
    required this.action,
    this.extra,
  });
  final String title, description;
  final Widget action;

  /// A line under the copy (`Active link expires …`).
  final String? extra;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftSectionEyebrow(raftText(context, title)),
        const SizedBox(height: RaftSpace.x1),
        Text(
          raftText(context, description),
          style: RaftTypography.body(
            t,
            size: 12,
            line: 12 * 1.625,
            color: text.muted,
          ),
        ),
        if (extra != null) ...[
          const SizedBox(height: RaftSpace.x2),
          Text(
            extra!,
            style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
          ),
        ],
      ],
    );
    return raftBreakpointWidth(context) >= 640
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: RaftSpace.x3),
              action,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: RaftSpace.x3,
            children: [copy, action],
          );
  }
}

/// `renderClientSecretReveal`: the one-time client secret with a copy button.
class RaftAppEditorSecretReveal extends StatelessWidget {
  const RaftAppEditorSecretReveal({
    super.key,
    required this.secret,
    required this.copied,
    required this.onCopy,
  });
  final String secret;
  final bool copied;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final label = raftText(
      context,
      copied ? 'Copied client secret' : 'Copy client secret',
    );
    return Container(
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          t.product.brutalLime.withValues(alpha: .2),
          t.panel,
        ),
        border: Border.all(color: text.edge, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          RaftSectionEyebrow(raftText(context, 'Client Secret')),
          Text(
            raftText(context, 'This secret is only shown once. Copy it now.'),
            style: RaftTypography.body(
              t,
              size: 14,
              line: 20,
              color: text.strong,
            ),
          ),
          Row(
            spacing: RaftSpace.x2,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(RaftSpace.x2),
                  decoration: BoxDecoration(
                    color: t.panel,
                    border: Border.all(color: text.edge, width: 1),
                  ),
                  child: SelectableText(
                    secret,
                    style: RaftTypography.mono(
                      t,
                      size: 12,
                      line: 16,
                      color: text.strong,
                    ),
                  ),
                ),
              ),
              RaftTooltip(
                message: label,
                child: RaftSettingsRecipeButton(
                  key: const ValueKey('connected-app-secret-copy-button'),
                  label: '',
                  semanticLabel: label,
                  glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
                  glyphSize: 14,
                  size: RaftButtonRecipeSize.iconSm,
                  onPressed: onCopy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// DeclaredScopesPicker: identity scopes (fixed + optional `email`) and the
/// agent-messaging scopes as checkable chips.
class RaftDeclaredScopesPicker extends StatelessWidget {
  const RaftDeclaredScopesPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.tooltips,
    required this.fixedIdentity,
    required this.optionalIdentity,
    required this.agentMessaging,
    this.legacyAgentScopeNote,
    this.resourceNote,
  });
  final Set<String> value;
  final ValueChanged<String> onChanged;
  final Map<String, String> tooltips;
  final List<String> fixedIdentity, optionalIdentity, agentMessaging;

  /// `agent:read` already declared.
  final String? legacyAgentScopeNote;

  /// Shown when an agent-messaging scope is selected.
  final String? resourceNote;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final chipBorder = t.colors['line-strong']!;
    final chipText = RaftTypography.body(
      t,
      size: 11,
      line: 11 * 1.5,
      weight: FontWeight.w700,
      color: t.muted,
    );
    Widget chip(String scope, {required bool checkable, double vertical = 4}) {
      final selected = value.contains(scope);
      final label = Text(scope, style: chipText);
      final body = Container(
        padding: EdgeInsets.symmetric(
          horizontal: RaftSpace.x2,
          vertical: vertical,
        ),
        decoration: BoxDecoration(
          color: t.panel,
          border: Border.all(color: chipBorder),
        ),
        child: checkable
            ? Row(
                mainAxisSize: MainAxisSize.min,
                spacing: RaftSpace.x2,
                children: [
                  RaftCheckbox(
                    value: selected,
                    semanticLabel: scope,
                    onChanged: (_) => onChanged(scope),
                  ),
                  label,
                ],
              )
            : label,
      );
      return RaftTooltip(message: tooltips[scope] ?? scope, child: body);
    }

    Widget group(String title, Widget chips, {String? note}) => Container(
      padding: const EdgeInsets.all(RaftSpace.x2),
      decoration: BoxDecoration(
        color: t.colors['layer-canvas-muted'],
        border: Border.all(color: t.colors['line-muted']!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            raftText(context, title),
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              weight: RaftTypography.black(t),
              color: text.strong,
            ),
          ),
          const SizedBox(height: RaftSpace.x2),
          chips,
          if (note != null) ...[
            const SizedBox(height: RaftSpace.x2),
            Text(
              raftText(context, note),
              style: RaftTypography.body(
                t,
                size: 12,
                line: 16,
                weight: FontWeight.w700,
                color: t.muted,
              ),
            ),
          ],
        ],
      ),
    );

    return RaftAppEditorBox(
      key: const ValueKey('connected-app-declared-scopes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (legacyAgentScopeNote != null) ...[
            const SizedBox(height: RaftSpace.x2),
            Text(
              raftText(context, legacyAgentScopeNote!),
              key: const ValueKey('legacy-agent-login-scope'),
              style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
            ),
          ],
          const SizedBox(height: RaftSpace.x3),
          group(
            'Identity',
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in fixedIdentity) chip(s, checkable: false),
                for (final s in optionalIdentity) chip(s, checkable: true),
              ],
            ),
          ),
          const SizedBox(height: RaftSpace.x2),
          group(
            'Agent messaging',
            Wrap(
              spacing: RaftSpace.x2,
              runSpacing: RaftSpace.x2,
              children: [
                for (final s in agentMessaging)
                  chip(s, checkable: true, vertical: 6),
              ],
            ),
            note: agentMessaging.any(value.contains) ? resourceNote : null,
          ),
        ],
      ),
    );
  }
}

/// DeveloperAppPermissions resource table: a Resource column and an Access
/// select (No access / Read-only / Write) per data group.
class RaftAppPermissionRow {
  const RaftAppPermissionRow({
    required this.id,
    required this.label,
    required this.summary,
    required this.selected,
    required this.accessLabel,
    required this.writeAccess,
  });
  final String id, label, summary, accessLabel;
  final bool selected;

  /// `agent_reminder_write` reads "Write" instead of "Read-only".
  final bool writeAccess;
}

class RaftAppPermissionsTable extends StatelessWidget {
  const RaftAppPermissionsTable({
    super.key,
    required this.rows,
    required this.onChanged,
    this.enabled = true,
  });
  final List<RaftAppPermissionRow> rows;
  final void Function(String id, bool enabled) onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftTableRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: tokens,
    );
    String tr(String s) => raftText(context, s);
    Widget head(String label) => RaftRecipeBox(
      style: recipe.head,
      tokens: tokens,
      child: Text(tr(label)),
    );
    return RaftRecipeBox(
      style: recipe.root,
      tokens: tokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftRecipeBox(
            style: recipe.row,
            tokens: tokens,
            child: Row(
              children: [
                Expanded(child: head('Resource')),
                SizedBox(width: 144, child: head('Access')),
              ],
            ),
          ),
          for (final row in rows)
            RaftRecipeBox(
              style: recipe.row,
              tokens: tokens,
              child: Row(
                children: [
                  Expanded(
                    child: RaftRecipeBox(
                      style: recipe.cell,
                      tokens: tokens,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(row.label),
                            style: RaftTypography.body(
                              t,
                              size: 14,
                              line: 20,
                              weight: FontWeight.w700,
                              color: t.strong,
                            ),
                          ),
                          const SizedBox(height: RaftSpace.x1),
                          Text(
                            tr(row.summary),
                            style: RaftTypography.body(
                              t,
                              size: 11,
                              line: 11 * 1.625,
                              color: t.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 144,
                    child: RaftRecipeBox(
                      style: recipe.cell,
                      tokens: tokens,
                      child: RaftSelectField<bool>(
                        key: ValueKey('app-permission-${row.id}'),
                        value: row.selected,
                        label: row.accessLabel,
                        onChanged: enabled
                            ? (v) {
                                if (v != null) onChanged(row.id, v);
                              }
                            : null,
                        items: [
                          RaftSelectItem(value: false, label: tr('No access')),
                          RaftSelectItem(
                            value: true,
                            label: tr(row.writeAccess ? 'Write' : 'Read-only'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A checkable event / group card of AppNotificationPermissionPicker.
class RaftAppEditorCheckTile extends StatelessWidget {
  const RaftAppEditorCheckTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
    this.enabled = true,
  });
  final String label;
  final String? caption;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tile = Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x2,
        vertical: RaftSpace.x1_5,
      ),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.colors['line-muted']!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x2,
        children: [
          RaftCheckbox(
            value: value,
            semanticLabel: label,
            onChanged: enabled ? onChanged : null,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w700,
                    color: t.muted,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: RaftTypography.body(
                      t,
                      size: 10,
                      line: 15,
                      color: t.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Opacity(opacity: enabled ? 1 : .45, child: tile);
  }
}

/// `grid gap-2 sm:grid-cols-2` of [children].
class RaftAppEditorTwoColumn extends StatelessWidget {
  const RaftAppEditorTwoColumn({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (raftBreakpointWidth(context) < 640) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        for (var i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x2,
              children: [
                Expanded(child: children[i]),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The titled bordered panel of DeveloperAppNotifications (`border-2 ... p-3`).
class RaftAppEditorPanel extends StatelessWidget {
  const RaftAppEditorPanel({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.trailing,
  });
  final String title, description;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Container(
      padding: const EdgeInsets.all(RaftSpace.x3),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.colors['line-muted']!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: RaftSpace.x2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: t.colors['line-muted']!, width: 2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        raftText(context, title),
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: RaftTypography.black(t),
                          color: text.strong,
                        ),
                      ),
                      const SizedBox(height: RaftSpace.half),
                      Text(
                        raftText(context, description),
                        style: RaftTypography.body(
                          t,
                          size: 12,
                          line: 12 * 1.625,
                          color: t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: RaftSpace.x2),
                  trailing!,
                ],
              ],
            ),
          ),
          const SizedBox(height: RaftSpace.x3),
          child,
        ],
      ),
    );
  }
}

/// Eyebrow-style heading used inside editor boxes.
class RaftAppEditorFootnote extends StatelessWidget {
  const RaftAppEditorFootnote(this.message, {super.key, this.warning = false});
  final String message;
  final bool warning;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      raftText(context, message),
      style: RaftTypography.body(
        t,
        size: 12,
        line: 16,
        color: warning ? t.colors['warning-strong'] ?? t.muted : t.muted,
      ),
    );
  }
}

/// The Enable Webhook row: title, description and a `size="md"` switch.
class RaftAppEditorSwitchRow extends StatelessWidget {
  const RaftAppEditorSwitchRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.note,
  });
  final String title, description;
  final String? note;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                raftText(context, title),
                style: RaftTypography.body(
                  t,
                  size: 14,
                  line: 20,
                  weight: FontWeight.w700,
                  color: text.strong,
                ),
              ),
              const SizedBox(height: RaftSpace.half),
              Text(
                raftText(context, description),
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 20,
                  color: text.muted,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: RaftSpace.x1),
                Text(
                  raftText(context, note!),
                  style: RaftTypography.body(
                    t,
                    size: 11,
                    line: 16.5,
                    weight: FontWeight.w700,
                    color: t.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: RaftSpace.x4),
        Padding(
          padding: const EdgeInsets.only(top: RaftSpace.half),
          child: RaftSwitch(
            key: const ValueKey('app-notifications-enabled'),
            value: value,
            enabled: onChanged != null,
            onChanged: onChanged,
            size: RaftSwitchSize.md,
            semanticLabel: raftText(context, title),
            semanticDescription: raftText(context, description),
          ),
        ),
      ],
    );
  }
}

/// `flex flex-wrap items-center justify-between gap-2 text-xs`: a status line
/// with its actions.
class RaftAppEditorActionLine extends StatelessWidget {
  const RaftAppEditorActionLine({
    super.key,
    required this.message,
    required this.actions,
  });
  final String message;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: RaftSpace.x2,
      runSpacing: RaftSpace.x2,
      children: [
        Text(
          message,
          style: RaftTypography.body(t, size: 12, line: 16, color: t.muted),
        ),
        Wrap(
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          children: actions,
        ),
      ],
    );
  }
}

/// `flex-col gap-2 sm:flex-row sm:items-end`: a field with its button.
class RaftAppEditorInlineForm extends StatelessWidget {
  const RaftAppEditorInlineForm({
    super.key,
    required this.field,
    required this.action,
  });
  final Widget field, action;
  @override
  Widget build(BuildContext context) => raftBreakpointWidth(context) >= 640
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: RaftSpace.x2,
          children: [
            Expanded(child: field),
            action,
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x2,
          children: [field, action],
        );
}

/// The one-time webhook signing secret strip.
class RaftAppEditorSigningSecret extends StatelessWidget {
  const RaftAppEditorSigningSecret({
    super.key,
    required this.secret,
    required this.copied,
    required this.onCopy,
  });
  final String secret;
  final bool copied;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final code = Container(
      padding: const EdgeInsets.all(RaftSpace.x2),
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.colors['line-strong']!),
      ),
      child: SelectableText(
        secret,
        key: const ValueKey('app-notifications-secret'),
        style: RaftTypography.mono(t, size: 11, line: 16.5, color: text.strong),
      ),
    );
    final button = RaftSettingsRecipeButton(
      label: copied ? 'Copied' : 'Copy',
      glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
      glyphSize: 13,
      size: RaftButtonRecipeSize.sm,
      onPressed: onCopy,
    );
    final wide = raftBreakpointWidth(context) >= 640;
    return Container(
      key: const ValueKey('app-notifications-secret-reveal'),
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x3,
        vertical: RaftSpace.x2,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          t.product.brutalLime.withValues(alpha: .15),
          t.panel,
        ),
        border: Border(left: BorderSide(color: t.product.brutalLime, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: RaftSpace.x2,
        children: [
          Row(
            spacing: RaftSpace.x2,
            children: [
              RaftIcon(RaftGlyph.keyRound, size: 14, color: text.strong),
              Expanded(
                child: Text(
                  raftText(context, 'Signing secret · shown once'),
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 16,
                    weight: RaftTypography.black(t),
                    color: text.strong,
                  ),
                ),
              ),
            ],
          ),
          if (wide)
            Row(
              spacing: RaftSpace.x2,
              children: [
                Expanded(child: code),
                button,
              ],
            )
          else ...[
            code,
            button,
          ],
        ],
      ),
    );
  }
}

/// A read-only value with a copy button (the private share URL).
class RaftAppEditorCopyRow extends StatelessWidget {
  const RaftAppEditorCopyRow({
    super.key,
    required this.value,
    required this.copied,
    required this.onCopy,
    required this.label,
  });
  final String value, label;
  final bool copied;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final field = RaftAppEditorReadonlyInput(value: value, label: label);
    final button = RaftSettingsRecipeButton(
      label: copied ? 'Copied' : 'Copy',
      glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
      glyphSize: 14,
      size: RaftButtonRecipeSize.sm,
      onPressed: onCopy,
    );
    return raftBreakpointWidth(context) >= 640
        ? Row(
            spacing: RaftSpace.x2,
            children: [
              Expanded(child: field),
              button,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x2,
            children: [field, button],
          );
  }
}

/// `details open` of a permission group: a rule, the summary and the event grid.
class RaftAppEditorEventGroup extends StatelessWidget {
  const RaftAppEditorEventGroup({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Container(
      padding: const EdgeInsets.only(top: RaftSpace.x2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.colors['line-muted']!, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: RaftTypography.body(
              t,
              size: 12,
              line: 16,
              weight: RaftTypography.black(t),
              color: text.strong,
            ),
          ),
          const SizedBox(height: RaftSpace.x2),
          RaftAppEditorTwoColumn(children: children),
        ],
      ),
    );
  }
}

/// A read-only mono `Input` (`readOnly`, text selectable) holding [value].
class RaftAppEditorReadonlyInput extends StatefulWidget {
  const RaftAppEditorReadonlyInput({
    super.key,
    required this.value,
    required this.label,
  });
  final String value, label;
  @override
  State<RaftAppEditorReadonlyInput> createState() =>
      _RaftAppEditorReadonlyInputState();
}

class _RaftAppEditorReadonlyInputState
    extends State<RaftAppEditorReadonlyInput> {
  late final controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(RaftAppEditorReadonlyInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) controller.text = widget.value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: raftText(context, widget.label),
    child: RaftRecipeInput(controller: controller, mono: true, readOnly: true),
  );
}
