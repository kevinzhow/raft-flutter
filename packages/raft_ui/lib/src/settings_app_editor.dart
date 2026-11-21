import 'raft/checkbox.dart' show RaftCheckbox;
import 'raft/ui_tokens.dart';

import 'package:flutter/material.dart';

import 'card.dart';
import 'design_primitives.dart' show RaftTypography;
import 'form_controls.dart' show RaftField;
import 'form_presentation.dart' show RaftFormFrame, RaftFormSheet;
import 'icons.dart';

import 'list_items.dart' show RaftSectionEyebrow;
import 'localization.dart';
import 'overlays/dialog.dart';
import 'panel_layout.dart' show RaftCssText, RaftPanelAction;
import 'recipe_surface.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart' show RaftButtonRecipeSize;
import 'recipes/form_section.g.dart';
import 'recipes/recipe_router.dart' show resolveRecipeClasses;
import 'recipes/table.g.dart';
import 'raft/badge.dart' show RaftBadge;
import 'select_field.dart';
import 'settings_applications.dart' show RaftAppLogo, RaftAppLogoSize;
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'tooltip.dart';
import 'tokens/tokens.dart';
import 'viewport_breakpoints.dart' show raftBreakpointWidth;

/// `appEditorSections` entry: the rail button and the section card it scrolls to.
@immutable
class RaftAppEditorSection {
  const RaftAppEditorSection({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.child,
    this.experimentalBadge = false,
  });

  /// `profile`, `login`, `permissions`, `notifications`, `distribution`, `danger`.
  final String id;
  final String title, description, status;

  /// `AppNotificationsLabel`: the title carries the Experimental badge.
  final bool experimentalBadge;

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

class RaftConnectedAppEditorCard extends StatefulWidget {
  const RaftConnectedAppEditorCard({
    super.key,
    required this.formTitle,
    required this.closeLabel,
    required this.onClose,
    required this.submitLabel,
    required this.sections,
    this.onSubmit,
    this.banner,
    this.railLabel = 'App editor sections',
  });
  final String formTitle, closeLabel, submitLabel;
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
  late final Map<String, GlobalKey> sectionKeys = {
    for (final s in widget.sections) s.id: GlobalKey(),
  };
  late String active = widget.sections.first.id;

  @override
  void initState() {
    super.initState();
    scroll.addListener(syncFromScroll);
  }

  @override
  void dispose() {
    scroll.dispose();
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
    if (next != active) setState(() => active = next);
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
        viewport.localToGlobal(Offset.zero).dy;
    scroll.animateTo(
      (scroll.offset + delta).clamp(0, scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final widget = this.widget;
    final sheet = RaftFormFrame.sheetOf(context);
    final commit = RaftButton(
      key: const ValueKey('connected-app-editor-submit'),
      label: widget.submitLabel,
      uiVariant: RaftButtonVariant.accent,
      uiSize: sheet ? RaftButtonSize.md : RaftButtonSize.lg,
      onPressed: widget.onSubmit,
    );
    final edge = BorderSide(color: t.colors['line-seam']!);
    const bodyKey = ValueKey('connected-app-editor-content');
    if (sheet) {
      return RaftFormSheet(
        key: const ValueKey('connected-app-editor'),
        title: widget.formTitle,
        onClose: widget.onClose,
        showHandle: false,
        closeButton: RaftPanelAction(
          glyph: RaftGlyph.x,
          tooltip: widget.closeLabel,
          onPressed: widget.onClose,
        ),
        commit: commit,
        body: Padding(
          padding: const EdgeInsets.only(top: RaftSpace.x4),
          child: Column(
            key: bodyKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.banner case final banner?)
                Padding(
                  padding: const EdgeInsets.only(bottom: RaftSpace.x4),
                  child: banner,
                ),
              for (final (index, section) in widget.sections.indexed)
                RaftAppEditorSectionCard(section: section, first: index == 0),
            ],
          ),
        ),
      );
    }

    final railBox = Container(
      key: const ValueKey('connected-app-editor-rail'),
      width: 208,
      decoration: BoxDecoration(border: Border(right: edge)),
      child: Semantics(
        container: true,
        label: widget.railLabel,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: RaftSpace.x2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.half,
            children: [
              for (final section in widget.sections)
                FocusableActionDetector(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        jumpTo(section.id);
                        return null;
                      },
                    ),
                  },
                  child: RaftSettingsSidebarItem(
                    active: section.id == active,
                    entry: RaftSettingsNavEntry(
                      id: section.id,
                      label: section.title,
                      onTap: () => jumpTo(section.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return RaftDialog(
      contentKey: const ValueKey('connected-app-editor'),
      semanticLabel: widget.formTitle,
      bar: true,
      size: RaftDialogSize.wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftDialogHeader(
            title: widget.formTitle,
            height: t.desktop ? RaftDesktopMetrics.headerHeight : null,
            trailing: RaftDialogClose(
              bar: true,
              onPressed: widget.onClose,
              semanticLabel: widget.closeLabel,
            ),
          ),
          if (widget.banner case final banner?)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RaftSpace.x4,
                vertical: RaftSpace.x3,
              ),
              decoration: BoxDecoration(border: Border(bottom: edge)),
              child: banner,
            ),
          Expanded(
            child: RaftDialogBody(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.sections.length > 1) railBox,
                  Expanded(
                    child: SingleChildScrollView(
                      key: bodyKey,
                      controller: scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: RaftSpace.x4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, section)
                              in widget.sections.indexed)
                            KeyedSubtree(
                              key: sectionKeys[section.id],
                              child: RaftAppEditorSectionCard(
                                section: section,
                                first: index == 0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          RaftDialogFooter(
            children: [
              RaftButton(
                label: raftText(context, 'Cancel'),
                uiVariant: RaftButtonVariant.ghost,
                uiSize: RaftButtonSize.lg,
                onPressed: widget.onClose,
              ),
              commit,
            ],
          ),
        ],
      ),
    );
  }
}

class RaftAppEditorSectionCard extends StatelessWidget {
  const RaftAppEditorSectionCard({
    super.key,
    required this.section,
    required this.first,
  });
  final RaftAppEditorSection section;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final recipe = RaftFormSectionRecipe.resolve(
      states: t.recipeStates(),
      tokens: tokens,
    );
    final sectionInset = recipe.root.padding.bottom;
    return Container(
      key: ValueKey('connected-app-editor-section-${section.id}'),
      padding: EdgeInsets.only(
        top: first ? 0 : sectionInset,
        bottom: sectionInset,
      ),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(
                top: BorderSide(color: t.colors['line-hairline']!),
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: recipe.root.rowGap ?? RaftSpace.x3,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: recipe.head.rowGap ?? 0,
            children: [
              Row(
                spacing: recipe.titleRow.columnGap ?? 0,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Wrap(
                        spacing: RaftSpace.x1_5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          RaftCssText(
                            raftText(context, section.title),
                            style: recipe.title.text(tokens),
                          ),
                          if (section.experimentalBadge)
                            RaftBadge(
                              label: raftText(context, 'Experimental'),
                              variant: RaftBadgeRecipeVariant.success,
                              wrap: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: RaftBadge(
                        label: section.status,
                        appearance: RaftBadgeRecipeAppearance.soft,
                        variant: RaftBadgeRecipeVariant.muted,
                        wrap: true,
                      ),
                    ),
                  ),
                ],
              ),
              RaftCssText(
                raftText(context, section.description),
                style: recipe.description.text(tokens),
              ),
            ],
          ),
          section.child,
        ],
      ),
    );
  }
}

/// The Apps editor's Web `FormField`.
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
    child: child,
  );
}

class RaftAppEditorFieldPair extends StatelessWidget {
  const RaftAppEditorFieldPair({
    super.key,
    required this.first,
    required this.second,
  });
  final Widget first, second;
  @override
  Widget build(BuildContext context) => raftBreakpointWidth(context) >= 640
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x3,
          children: [
            Expanded(child: first),
            Expanded(child: second),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: RaftSpace.x3,
          children: [first, second],
        );
}

class RaftAppEditorLogoActions extends StatelessWidget {
  const RaftAppEditorLogoActions({
    super.key,
    required this.initials,
    this.logoUrl,
    this.actions = const [],
  });
  final String initials;
  final String? logoUrl;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Row(
    spacing: RaftSpace.x4,
    children: [
      RaftAppLogo(
        initials: initials,
        logoUrl: logoUrl,
        size: RaftAppLogoSize.lg,
      ),
      if (actions.isNotEmpty)
        Flexible(
          child: Wrap(
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: actions,
          ),
        ),
    ],
  );
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
    this.action,
    this.extra,
  });
  final String title, description;

  /// Web `ConnectedAppEditorActionRow` without an `action` (a row whose
  /// controls sit under the copy) draws the copy alone.
  final Widget? action;

  /// A line under the copy (`Active link expires …`).
  final String? extra;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          raftText(context, title),
          style: t.scale(
            RaftTypeScale.subhead,
            weight: FontWeight.w600,
            color: text.strong,
          ),
        ),
        const SizedBox(height: RaftSpace.half),
        Text(
          raftText(context, description),
          style: t.scale(RaftTypeScale.footnote, color: text.muted),
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
    final action = this.action;
    if (action == null) return copy;
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
          RaftSectionEyebrow(raftText(context, 'Client secret')),
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
                  Flexible(child: label),
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
    final states = t.recipeStates(responsive: true);
    final recipe = RaftTableRecipe.resolve(states: states, tokens: tokens);
    final labelStyle = resolveRecipeClasses(
      const ['text-subhead', 'font-semibold', 'text-foreground'],
      states,
      tokens,
    ).text(tokens);
    final summaryStyle = resolveRecipeClasses(
      const ['text-footnote', 'text-foreground-muted'],
      states,
      tokens,
    ).text(tokens);
    const accessWidth = 144.0;
    final accessColumnWidth = t.desktop && raftBreakpointWidth(context) >= 768
        ? accessWidth
        : accessWidth + RaftSpace.x1_5;
    String tr(String s) => raftText(context, s);
    Widget head(String label) => RaftRecipeBox(
      style: recipe.head,
      tokens: tokens,
      child: Text(tr(label)),
    );
    return RaftCard(
      clip: true,
      child: RaftRecipeBox(
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
                  SizedBox(width: accessColumnWidth, child: head('Access')),
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
                            RaftCssText(tr(row.label), style: labelStyle),
                            const SizedBox(height: RaftSpace.half),
                            RaftCssText(tr(row.summary), style: summaryStyle),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: accessColumnWidth,
                      child: RaftRecipeBox(
                        style: recipe.cell,
                        tokens: tokens,
                        child: RaftSelectField<bool>(
                          key: ValueKey('app-permission-${row.id}'),
                          value: row.selected,
                          label: row.accessLabel,
                          onChanged: enabled
                              ? (value) {
                                  if (value != null) onChanged(row.id, value);
                                }
                              : null,
                          items: [
                            RaftSelectItem(
                              value: false,
                              label: tr('No access'),
                            ),
                            RaftSelectItem(
                              value: true,
                              label: tr(
                                row.writeAccess ? 'Write' : 'Read-only',
                              ),
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

class RaftAppEditorPanel extends StatelessWidget {
  const RaftAppEditorPanel({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailing,
    this.inset = false,
  });
  final String title;
  final String? description;
  final Widget child;
  final Widget? trailing;
  final bool inset;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: RaftSpace.x2,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: RaftSpace.x2,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    raftText(context, title),
                    style: t.scale(
                      RaftTypeScale.subhead,
                      weight: FontWeight.w600,
                      color: text.strong,
                    ),
                  ),
                  if (description case final description?)
                    Text(
                      raftText(context, description),
                      style: t.scale(RaftTypeScale.footnote, color: text.muted),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (inset)
          RaftCard(padding: const EdgeInsets.all(RaftSpace.x4), child: child)
        else
          child,
      ],
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
      glyphSize: 18,
      size: RaftButtonRecipeSize.lg,
      onPressed: onCopy,
    );
    return Row(
      spacing: RaftSpace.x2,
      children: [
        Expanded(child: field),
        button,
      ],
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
