// Settings > Workspace > Applications from the Web client (raft-source
// 26f77ef, packages/web/src/components/settings/SettingsPanel.tsx
// IntegrationsSection + AppNotificationsControls.tsx +
// SettingsSegmentedControls.tsx ConnectedAppsTabSegmentedControl): the
// Applications header, the intro card with the Marketplace / Installed /
// My apps tabs, the search / category / layout filters, the three app
// collections (grid or list), and the listing / installed-app detail cards.
// The app supplies the projected rows and callbacks; class lists live here.
import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'system_inset.dart';
import 'design_primitives.dart'
    show
        RaftInteractive,
        RaftSegmentedControl,
        RaftSegmentedOption,
        RaftTypography;
import 'dialog_card.dart' show RaftCloseButton, RaftRecipeCard;
import 'error_presentation.dart';
import 'icons.dart';
import 'list_items.dart' show RaftSectionEyebrow, RaftSurfaceListItem;
import 'localization.dart';
import 'recipe_min_height.dart' show RaftMinHeightBox;
import 'recipe_surface.dart';
import 'text_scaling.dart' show RaftScaled;
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'recipes/toggle_group.g.dart';
import 'select_field.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'theme.dart';
import 'tokens/shadows.g.dart' show RaftProductShadows;
import 'tooltip.dart';
import 'viewport_breakpoints.dart';
import 'sized_image.dart';

enum RaftConnectedAppsTab { marketplace, installed, myApps }

enum RaftConnectedAppsLayout { grid, list }

/// A raft-ui `Badge` on an app row (`uppercase` unless noted).
@immutable
class RaftConnectedAppBadge {
  const RaftConnectedAppBadge(
    this.label, {
    this.variant,
    this.appearance,
    this.uppercase = true,
  });

  /// ConnectedAppDistributionBadge / origin badges.
  const RaftConnectedAppBadge.success(String label)
    : this(label, variant: RaftBadgeRecipeVariant.success);
  const RaftConnectedAppBadge.warning(String label)
    : this(label, variant: RaftBadgeRecipeVariant.warning);
  const RaftConnectedAppBadge.outline(String label, {bool uppercase = true})
    : this(
        label,
        appearance: RaftBadgeRecipeAppearance.outline,
        uppercase: uppercase,
      );
  final String label;
  final RaftBadgeRecipeVariant? variant;
  final RaftBadgeRecipeAppearance? appearance;
  final bool uppercase;
}

/// The marketplace card's trailing state.
enum RaftMarketplaceAppState {
  /// `Badge variant="success" uppercase` Installed.
  installed,

  /// The `bg-accent-soft … btn-brutal-sm theme-brutal:bg-brutal-pink`
  /// Install pill (managers).
  install,

  /// `Badge appearance="outline" uppercase` Available (read-only viewers).
  available,
}

/// ConnectedAppLogo: AvatarSlot `type="app"` (initials placeholder or logo).
enum RaftAppLogoSize {
  /// `surface-list`: `!size-8 !border-2`, `text-xs`.
  sm(32, 12, 16),

  /// `mention-card`: `!size-12 !border-2`, `text-lg`.
  md(48, 18, 28),

  /// `account-tile`: `!size-14 !border-2`, `text-xl`.
  lg(56, 20, 28);

  const RaftAppLogoSize(this.box, this.fontSize, this.lineHeight);
  final double box, fontSize, lineHeight;
}

/// One marketplace listing card.
@immutable
class RaftMarketplaceAppTile {
  const RaftMarketplaceAppTile({
    required this.id,
    required this.name,
    required this.initials,
    required this.byline,
    required this.state,
    required this.stateLabel,
    this.description,
    this.logoUrl,
    this.badge,
    this.onOpen,
  });
  final String id, name, initials, byline, stateLabel;
  final String? description, logoUrl;
  final RaftConnectedAppBadge? badge;
  final RaftMarketplaceAppState state;
  final VoidCallback? onOpen;
}

/// One Installed / My apps row (SurfaceListItem).
@immutable
class RaftConnectedAppRow {
  const RaftConnectedAppRow({
    required this.id,
    required this.name,
    required this.initials,
    required this.meta,
    this.logoUrl,
    this.badges = const [],
    this.description,
    this.homepageUrl,
    this.homepageLabel,
    this.statusHint,
    this.onOpenName,
    this.actionLabel,
    this.actionGlyph,
    this.onAction,
  });
  final String id, name, initials;

  /// `category · developer` (Installed) or the category (My apps).
  final String meta;
  final String? logoUrl, description, homepageUrl, homepageLabel, statusHint;
  final List<RaftConnectedAppBadge> badges;

  /// Non-editable installed apps: the name is a button opening the access
  /// detail.
  final VoidCallback? onOpenName;

  /// Edit (Pencil) / Uninstall.
  final String? actionLabel;
  final RaftGlyph? actionGlyph;
  final VoidCallback? onAction;
}

/// IntegrationsSection page body.
class RaftConnectedAppsSection extends StatelessWidget {
  const RaftConnectedAppsSection({
    super.key,
    required this.description,
    required this.tab,
    required this.counts,
    required this.onTab,
    required this.searchController,
    required this.category,
    required this.categories,
    required this.onCategory,
    required this.layout,
    required this.onLayout,
    this.adminNote,
    this.loading = false,
    this.scrollable = false,
    this.onRegister,
    this.onSearch,
    this.error,
    this.marketplace = const [],
    this.rows = const [],
    this.emptyMessage,
    this.myAppsIntro,
    this.reviewNote,
    this.secretReveal,
  });

  /// `renderClientSecretReveal` under the filters while the editor is closed.
  final Widget? secretReveal;
  final String description;
  final String? adminNote;
  final bool loading;

  /// Own a bounded settings viewport and mount only visible app rows.
  final bool scrollable;

  /// Register app (managers).
  final VoidCallback? onRegister;
  final RaftConnectedAppsTab tab;

  /// Marketplace / Installed / My apps counts (a zero hides the count).
  final ({int marketplace, int installed, int myApps}) counts;
  final ValueChanged<RaftConnectedAppsTab> onTab;
  final TextEditingController searchController;
  final ValueChanged<String>? onSearch;
  final String category;

  /// Category value → label (`all` first).
  final List<(String, String)> categories;
  final ValueChanged<String> onCategory;
  final RaftConnectedAppsLayout layout;
  final ValueChanged<RaftConnectedAppsLayout> onLayout;
  final String? error;
  final List<RaftMarketplaceAppTile> marketplace;
  final List<RaftConnectedAppRow> rows;

  /// The empty box under an empty collection.
  final String? emptyMessage;
  final String? myAppsIntro, reviewNote;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final band = raftBreakpointWidth(context);
    final intro = RaftSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      raftText(context, 'Third-party apps for this server'),
                      style: text.title,
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 672),
                      child: Text(description, style: _relaxed(t, text.muted)),
                    ),
                    if (adminNote != null) ...[
                      const SizedBox(height: 4),
                      Text(adminNote!, style: _relaxed(t, text.muted)),
                    ],
                  ],
                ),
              ),
              if (loading) ...[
                const SizedBox(width: 12),
                Text(
                  raftText(context, 'Loading...'),
                  style: RaftTypography.inherited(
                    t,
                    size: 12,
                    line: 16,
                    weight: FontWeight.w700,
                    color: text.faint,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          RaftSegmentedControl<RaftConnectedAppsTab>(
            value: tab,
            label: raftText(context, 'Connected apps view'),
            onChanged: onTab,
            items: [
              for (final (value, label, count, key) in [
                (
                  RaftConnectedAppsTab.marketplace,
                  'Marketplace',
                  counts.marketplace,
                  'marketplace',
                ),
                (
                  RaftConnectedAppsTab.installed,
                  'Installed',
                  counts.installed,
                  'installed',
                ),
                (
                  RaftConnectedAppsTab.myApps,
                  'My apps',
                  counts.myApps,
                  'my-apps',
                ),
              ])
                RaftSegmentedOption(
                  value: value,
                  label: raftText(context, label),
                  count: count > 0 ? '$count' : null,
                  itemKey: ValueKey('connected-apps-tab-$key'),
                ),
            ],
          ),
        ],
      ),
    );
    final search = RaftMinHeightBox(
      height: 40,
      child: RaftRecipeInput(
        fieldKey: const ValueKey('connected-apps-search'),
        controller: searchController,
        placeholder: raftText(context, 'Search apps…'),
        onChanged: onSearch,
        height: 40,
      ),
    );
    final select = RaftSelectField<String>(
      key: const ValueKey('connected-apps-category-filter'),
      value: category,
      label: 'Filter connected apps by category',
      height: 40,
      items: [
        for (final (value, label) in categories)
          DropdownMenuItem(value: value, child: Text(label)),
      ],
      onChanged: (value) {
        if (value != null) onCategory(value);
      },
    );
    final toggle = RaftMinHeightBox(
      height: 40,
      child: Align(
        alignment: Alignment.centerRight,
        child: _LayoutToggle(value: layout, onChanged: onLayout),
      ),
    );
    // Scaled text no longer fits the search, category and layout controls on
    // one or two rows: they stack, as on a narrow viewport.
    final stackFilters = RaftScaled.grows(context);
    final Widget filters = stackFilters
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              select,
              const SizedBox(height: 8),
              toggle,
            ],
          )
        : band >= 768
        ? Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 8),
              SizedBox(width: 220, child: select),
              const SizedBox(width: 8),
              toggle,
            ],
          )
        : band >= 640
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 8),
                  toggle,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: select),
                  const SizedBox(width: 8),
                  // `auto` column (the toggle's width) stays empty.
                  const SizedBox(width: 72),
                ],
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 8),
              select,
              const SizedBox(height: 8),
              toggle,
            ],
          );
    final empty = emptyMessage == null ? null : _EmptyBox(emptyMessage!);
    final body = switch (tab) {
      RaftConnectedAppsTab.marketplace => Column(
        key: const ValueKey('connected-apps-marketplace-tab'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Collection(
            layout: layout,
            children: [
              for (final app in marketplace)
                _MarketplaceCard(app: app, layout: layout),
            ],
          ),
          // The (possibly empty) grid keeps its `space-y-3` bottom margin.
          if (empty != null) const SizedBox(height: 12),
          ?empty,
          if (reviewNote != null) ...[
            const SizedBox(height: 12),
            Text(
              reviewNote!,
              textAlign: TextAlign.center,
              style: RaftTypography.inherited(
                t,
                size: 12,
                line: 16,
                color: t.brutal ? Colors.black.withValues(alpha: .55) : t.muted,
              ),
            ),
          ],
        ],
      ),
      RaftConnectedAppsTab.installed => Column(
        key: const ValueKey('connected-apps-installed-tab'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Collection(
            layout: layout,
            children: [
              for (final row in rows) _AppRowCard(row: row, layout: layout),
            ],
          ),
          if (empty != null) const SizedBox(height: 8),
          ?empty,
        ],
      ),
      RaftConnectedAppsTab.myApps => Column(
        key: const ValueKey('connected-apps-my-apps-tab'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (myAppsIntro != null)
            Text(myAppsIntro!, style: _relaxed(t, text.muted)),
          const SizedBox(height: 12),
          if (rows.isEmpty && empty != null)
            empty
          else
            _Collection(
              layout: layout,
              children: [
                for (final row in rows) _AppRowCard(row: row, layout: layout),
              ],
            ),
        ],
      ),
    };
    final children = <Widget>[
      RaftSettingsSectionHeader(
        label: 'Applications',
        glyph: RaftGlyph.link2,
        bottom: 0,
        action: onRegister == null
            ? null
            : RaftSettingsRecipeButton(
                key: const ValueKey('connected-apps-register'),
                label: 'Register app',
                glyph: RaftGlyph.plus,
                glyphSize: 14,
                variant: RaftButtonRecipeVariant.accent,
                size: RaftButtonRecipeSize.sm,
                onPressed: onRegister,
              ),
      ),
      intro,
      filters,
      if (error != null && error!.isNotEmpty) RaftConnectedAppsError(error!),
      ?secretReveal,
      body,
    ];
    if (scrollable) {
      final cards = <Widget>[
        if (tab == RaftConnectedAppsTab.marketplace)
          for (final app in marketplace)
            _MarketplaceCard(app: app, layout: layout)
        else
          for (final row in rows) _AppRowCard(row: row, layout: layout),
      ];
      Widget gap(double height) =>
          SliverToBoxAdapter(child: SizedBox(height: height));
      return RaftInheritedFont(
        child: CustomScrollView(
          primary: false,
          slivers: [
            SliverPadding(
              padding: raftScrollPadding(
                context,
                RaftSettingsPanelFrame.contentInset.add(
                  const EdgeInsets.only(bottom: 24),
                ),
              ),
              sliver: SliverMainAxisGroup(
                slivers: [
                  for (final (i, child)
                      in children.take(children.length - 1).indexed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                        child: child,
                      ),
                    ),
                  gap(16),
                  if (tab == RaftConnectedAppsTab.myApps) ...[
                    if (myAppsIntro != null)
                      SliverToBoxAdapter(
                        child: Text(
                          myAppsIntro!,
                          style: _relaxed(t, text.muted),
                        ),
                      ),
                    gap(12),
                  ],
                  _SliverCollection(layout: layout, children: cards),
                  if (empty != null) ...[
                    if (tab != RaftConnectedAppsTab.myApps)
                      gap(tab == RaftConnectedAppsTab.marketplace ? 12 : 8),
                    SliverToBoxAdapter(child: empty),
                  ],
                  if (tab == RaftConnectedAppsTab.marketplace &&
                      reviewNote != null) ...[
                    gap(12),
                    SliverToBoxAdapter(
                      child: Text(
                        reviewNote!,
                        textAlign: TextAlign.center,
                        style: RaftTypography.inherited(
                          t,
                          size: 12,
                          line: 16,
                          color: t.brutal
                              ? Colors.black.withValues(alpha: .55)
                              : t.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RaftInheritedFont(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          key: const ValueKey('connected-apps-section'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[
              if (i > 0) const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// `text-xs leading-relaxed` (12 / 19.5).
TextStyle _relaxed(RaftTokens t, Color color) =>
    RaftTypography.inherited(t, size: 12, line: 12 * 1.625, color: color);

/// The same line box inside a Dialog portal, whose text is Geist.
TextStyle _relaxedDialog(RaftTokens t, Color color) =>
    RaftTypography.body(t, size: 12, line: 12 * 1.625, color: color);

/// ConnectedAppsErrorBanner: `Banner intent="warning" density="sm"
/// className="font-bold"`.
class RaftConnectedAppsError extends StatelessWidget {
  const RaftConnectedAppsError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) =>
      RaftErrorBanner(message, small: true, bold: true);
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftSettingsCard(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: RaftSettingsText(t).bodyMuted,
      ),
    );
  }
}

/// `grid gap-3 md:grid-cols-2` (rows stretch to the taller card) or
/// `space-y-2`.
class _Collection extends StatelessWidget {
  const _Collection({required this.layout, required this.children});
  final RaftConnectedAppsLayout layout;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final columns =
        layout == RaftConnectedAppsLayout.grid &&
            raftBreakpointWidth(context) >= 768
        ? 2
        : 1;
    final gap = layout == RaftConnectedAppsLayout.grid ? 12.0 : 8.0;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        columns == 1
            ? children[i]
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: children[i]),
                    SizedBox(width: gap),
                    Expanded(
                      child: i + 1 < children.length
                          ? children[i + 1]
                          : const SizedBox.shrink(),
                    ),
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

/// Variable-height app cards retain the source's equal-height grid pairs.
/// Only visible pairs perform the intrinsic measurement.
class _SliverCollection extends StatelessWidget {
  const _SliverCollection({required this.layout, required this.children});
  final RaftConnectedAppsLayout layout;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final columns =
        layout == RaftConnectedAppsLayout.grid &&
            raftBreakpointWidth(context) >= 768
        ? 2
        : 1;
    final gap = layout == RaftConnectedAppsLayout.grid ? 12.0 : 8.0;
    return SliverList.builder(
      itemCount: (children.length / columns).ceil(),
      itemBuilder: (context, index) {
        final first = index * columns;
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
          child: columns == 1
              ? children[first]
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: children[first]),
                      SizedBox(width: gap),
                      Expanded(
                        child: first + 1 < children.length
                            ? children[first + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// ConnectedAppsViewToggle: raft-ui ToggleGroup with two `h-8 w-8 p-0`
/// icon items (LayoutGrid 16 / List 17).
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.value, required this.onChanged});
  final RaftConnectedAppsLayout value;
  final ValueChanged<RaftConnectedAppsLayout> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final root = RaftToggleGroupRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    final items = [
      for (final (layout, glyph, size, label, key) in [
        (
          RaftConnectedAppsLayout.grid,
          RaftGlyph.layoutGrid,
          16.0,
          'Grid view',
          'grid',
        ),
        (
          RaftConnectedAppsLayout.list,
          RaftGlyph.list,
          17.0,
          'List view',
          'list',
        ),
      ])
        RaftTooltip(
          message: raftText(context, label),
          child: RaftInteractive(
            key: ValueKey('connected-apps-view-$key'),
            semanticLabel: raftText(context, label),
            selected: value == layout,
            onPressed: () => onChanged(layout),
            builder: (context, st) {
              final s = RaftToggleGroupRecipe.resolve(
                theme: t.recipeTheme,
                states: t.recipeStates(
                  hovered: st.hovered,
                  pressed: st.pressed,
                  focusVisible: st.focusVisible,
                  extra: [
                    value == layout ? 'data-pressed' : 'not-data-pressed',
                  ],
                ),
                tokens: t.recipeTokens,
              ).item;
              return RaftRecipeBox(
                style: s,
                tokens: t.recipeTokens,
                width: 32,
                height: 32,
                padding: EdgeInsets.zero,
                alignment: Alignment.center,
                child: Builder(
                  builder: (context) => RaftIcon(
                    glyph,
                    size: size,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
              );
            },
          ),
        ),
    ];
    return Semantics(
      label: raftText(context, 'App layout'),
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          items[0],
          SizedBox(width: root.columnGap ?? 4),
          items[1],
        ],
      ),
    );
  }
}

/// ConnectedAppLogo (AvatarSlot `type="app"` + `shadow-raft-sm
/// theme-brutal:shadow-brutal-sm`): Brutal a square `bg-soft-signal` tile
/// with `font-display font-black text-black` initials; Elegant the human
/// Avatar's `border-2 border-transparent bg-clip-padding` circle with the
/// `bg-fill-muted text-sm text-foreground-placeholder/70` fallback.
class RaftAppLogo extends StatelessWidget {
  const RaftAppLogo({
    super.key,
    required this.initials,
    this.logoUrl,
    this.size = RaftAppLogoSize.md,
  });
  final String initials;
  final String? logoUrl;
  final RaftAppLogoSize size;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final box = size.box;
    final url = logoUrl?.trim();
    // The initials sit in a fixed tile (the app name is beside it): they keep
    // their size instead of outgrowing the logo.
    Widget fallback(TextStyle style) => Center(
      child: Text(
        initials,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: style,
      ),
    );
    Widget content(TextStyle style) => url == null || url.isEmpty
        ? fallback(style)
        : RaftSizedImage.avatar(
            url,
            fit: BoxFit.cover,
            width: box,
            height: box,
            errorBuilder: (_, _, _) => fallback(style),
          );
    if (t.brutal) {
      return Container(
        width: box,
        height: box,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: t.product.softSignal,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: RaftProductShadows.shadowBrutalSm.outer,
        ),
        child: content(
          RaftTypography.heading(
            t,
            size: size.fontSize,
            line: size.lineHeight,
            weight: FontWeight.w700,
          ).copyWith(color: Colors.black),
        ),
      );
    }
    final placeholder = t.colors['foreground-placeholder']!;
    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: t.themeShadows.sm.outer,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: ColoredBox(
          color: t.colors['fill-muted']!,
          child: content(
            RaftTypography.heading(
              t,
              size: 14,
              line: 20,
              weight: FontWeight.w700,
            ).copyWith(
              color: placeholder.withValues(alpha: placeholder.a * .7),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.badge);
  final RaftConnectedAppBadge badge;
  @override
  Widget build(BuildContext context) => RaftSettingsRecipeBadge(
    label: badge.label,
    variant: badge.variant,
    appearance: badge.appearance,
    uppercase: badge.uppercase,
  );
}

/// The marketplace listing button: `w-full border border-line-muted
/// bg-layer-panel p-3 shadow-raft-sm hover:shadow-raft-md` (Brutal
/// `border-2 border-black bg-white shadow-brutal-sm hover:shadow-brutal`).
class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({required this.app, required this.layout});
  final RaftMarketplaceAppTile app;
  final RaftConnectedAppsLayout layout;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final grid = layout == RaftConnectedAppsLayout.grid;
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftAppLogo(initials: app.initials, logoUrl: app.logoUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    app.name,
                    style: RaftTypography.inherited(
                      t,
                      size: 16,
                      line: 24,
                      weight: FontWeight.w700,
                      color: text.strong,
                    ),
                  ),
                  if (app.badge != null) _Badge(app.badge!),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                app.byline,
                style: RaftTypography.inherited(
                  t,
                  size: 12,
                  line: 16,
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .55)
                      : t.muted,
                ),
              ),
              if (!grid && app.description != null) _Summary(app.description!),
            ],
          ),
        ),
      ],
    );
    final trailing = switch (app.state) {
      RaftMarketplaceAppState.installed => _Badge(
        RaftConnectedAppBadge.success(app.stateLabel),
      ),
      RaftMarketplaceAppState.available => _Badge(
        RaftConnectedAppBadge.outline(app.stateLabel),
      ),
      RaftMarketplaceAppState.install => _InstallPill(app.stateLabel),
    };
    return RaftInteractive(
      key: ValueKey('connected-app-${app.id}'),
      onPressed: app.onOpen,
      semanticLabel: app.name,
      builder: (context, st) {
        final hovered = st.hovered;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.brutal ? Colors.white : t.panel,
            border: Border.all(
              color: t.brutal ? Colors.black : t.colors['line-muted']!,
              width: t.brutal ? 2 : 1,
            ),
            boxShadow: t.brutal
                ? (hovered
                      ? RaftProductShadows.shadowBrutal.outer
                      : RaftProductShadows.shadowBrutalSm.outer)
                : (hovered ? t.themeShadows.md : t.themeShadows.sm).outer,
          ),
          child: grid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // `flex-1` spacer: pushes the chip down when the row gives
                  // the card a height, shrink-wraps in a single column.
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    info,
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    trailing,
                  ],
                ),
        );
      },
    );
  }
}

/// `rounded-sm bg-accent-soft px-2.5 py-1 text-xs text-accent-strong
/// btn-brutal-sm theme-brutal:rounded-none theme-brutal:bg-brutal-pink
/// theme-brutal:text-black` (`.btn-brutal-sm`: `border border-line-strong
/// font-display font-bold shadow-raft-xs`).
class _InstallPill extends StatelessWidget {
  const _InstallPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // Translucent fills sit over the card, not over its outer shadow.
        color: t.brutal
            ? t.product.brutalPink
            : Color.alphaBlend(t.colors['accent-soft']!, t.panel),
        borderRadius: t.brutal ? null : BorderRadius.circular(4),
        border: Border.all(color: t.colors['line-strong']!),
        boxShadow: t.themeShadows.xs.outer,
      ),
      child: Text(
        label,
        style: RaftTypography.heading(
          t,
          size: 12,
          line: 16,
          weight: FontWeight.w700,
        ).copyWith(color: t.brutal ? Colors.black : t.colors['accent-strong']),
      ),
    );
  }
}

/// ConnectedAppSummary: `mt-1 line-clamp-2 break-words text-sm leading-snug
/// text-foreground-muted theme-brutal:text-black/65` (+ Tooltip).
class _Summary extends StatelessWidget {
  const _Summary(this.description);
  final String description;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final value = description.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RaftTooltip(
        message: value,
        onlyWhenTruncated: true,
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: RaftTypography.inherited(
            t,
            size: 14,
            line: 14 * 1.375,
            color: t.brutal ? Colors.black.withValues(alpha: .65) : t.muted,
          ),
        ),
      ),
    );
  }
}

/// ConnectedAppUrlLink: `inline-flex items-center gap-1.5 text-xs font-mono
/// font-bold text-foreground-muted underline decoration-2 underline-offset-2`
/// with the ExternalLink 12 icon.
class RaftConnectedAppUrlLink extends StatelessWidget {
  const RaftConnectedAppUrlLink({
    super.key,
    required this.url,
    this.label,
    this.onOpen,
  });
  final String url;
  final String? label;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final href = url.trim();
    final visible = label?.trim().isNotEmpty == true ? label!.trim() : href;
    return RaftTooltip(
      message: href,
      child: RaftInteractive(
        onPressed: onOpen,
        semanticLabel: visible,
        builder: (context, st) {
          final color = st.hovered
              ? (t.brutal ? Colors.black : t.strong)
              : (t.brutal ? Colors.black.withValues(alpha: .55) : t.muted);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RaftIcon(RaftGlyph.externalLink, size: 12, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: RaftUnderlinedText(
                  visible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RaftTypography.mono(
                    t,
                    size: 12,
                    line: 16,
                    color: color,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Installed / My apps row: `SurfaceListItem interactive={false}`; grid
/// `flex min-h-[184px] flex-col gap-3`, list `flex-col gap-3
/// sm:flex-row sm:items-center sm:justify-between`.
class _AppRowCard extends StatelessWidget {
  const _AppRowCard({required this.row, required this.layout});
  final RaftConnectedAppRow row;
  final RaftConnectedAppsLayout layout;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final grid = layout == RaftConnectedAppsLayout.grid;
    final wide = raftBreakpointWidth(context) >= 640;
    final nameStyle = RaftTypography.inherited(
      t,
      size: 16,
      line: 24,
      weight: FontWeight.w700,
      color: text.strong,
    );
    final name = row.onOpenName == null
        ? Text(row.name, style: nameStyle)
        : RaftInteractive(
            key: ValueKey('connected-app-installed-${row.id}'),
            semanticLabel: row.name,
            onPressed: row.onOpenName,
            builder: (context, st) => RaftUnderlinedText(
              row.name,
              style: nameStyle,
              underline: st.hovered,
            ),
          );
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftAppLogo(
          initials: row.initials,
          logoUrl: row.logoUrl,
          size: RaftAppLogoSize.sm,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              name,
              const SizedBox(height: 2),
              Text(
                row.meta,
                style: RaftTypography.inherited(
                  t,
                  size: 12,
                  line: 16,
                  color: text.faint,
                ),
              ),
              if (row.badges.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final b in row.badges) _Badge(b)],
                ),
              ],
              if (!grid && row.description != null) _Summary(row.description!),
              if (grid && row.statusHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RaftTooltip(
                    message: row.statusHint!,
                    onlyWhenTruncated: true,
                    child: Text(
                      row.statusHint!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _relaxed(
                        t,
                        t.brutal
                            ? Colors.black.withValues(alpha: .55)
                            : t.muted,
                      ),
                    ),
                  ),
                ),
              if (grid && row.homepageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RaftConnectedAppUrlLink(
                    url: row.homepageUrl!,
                    label: row.homepageLabel,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    final action = row.actionLabel == null
        ? null
        : RaftSettingsRecipeButton(
            key: ValueKey('connected-app-action-${row.id}'),
            label: row.actionLabel!,
            glyph: row.actionGlyph,
            glyphSize: 14,
            size: RaftButtonRecipeSize.sm,
            onPressed: row.onAction,
          );
    final Widget body;
    if (grid) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 184 - 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            info,
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(alignment: Alignment.centerRight, child: action),
              ),
          ],
        ),
      );
    } else if (wide) {
      body = Row(
        children: [
          Expanded(child: info),
          if (action != null) ...[const SizedBox(width: 12), action],
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        ],
      );
    }
    return RaftSurfaceListItem(interactive: false, child: body);
  }
}

// ── Detail modals ──

/// ConnectedAppDetailSection: `border … p-3 shadow-raft-sm` on
/// `bg-layer-panel` (white) or `bg-layer-canvas-muted
/// theme-brutal:bg-brutal-cream` (cream), SectionEyebrow title, optional
/// `mt-1 text-xs leading-relaxed` description, `mt-3` content.
class RaftConnectedAppDetailSection extends StatelessWidget {
  const RaftConnectedAppDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.cream = false,
  });
  final String title;
  final String? description;
  final bool cream;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: RaftSettingsCard.decoration(t).copyWith(
        color: cream
            ? (t.brutal
                  ? t.product.brutalCream
                  : t.colors['layer-canvas-muted'])
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionEyebrow(raftText(context, title)),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: _relaxedDialog(t, text.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ConnectedAppDetailRow: `flex-col gap-1 py-2 sm:flex-row sm:items-start
/// sm:justify-between sm:gap-3`, muted label, bold right-aligned value.
class RaftConnectedAppDetailRow extends StatelessWidget {
  const RaftConnectedAppDetailRow({
    super.key,
    required this.label,
    required this.child,
    this.first = false,
  });
  final String label;
  final Widget child;
  final bool first;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final wide = raftBreakpointWidth(context) >= 640;
    final labelStyle = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      color: t.brutal ? Colors.black.withValues(alpha: .55) : t.muted,
    );
    final value = DefaultTextStyle.merge(
      style: RaftTypography.body(
        t,
        size: 14,
        line: 20,
        weight: FontWeight.w700,
        color: text.strong,
      ),
      textAlign: wide ? TextAlign.right : TextAlign.left,
      child: child,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: first
          ? null
          : BoxDecoration(
              // `divide-y-2 divide-black/10`.
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: .1),
                  width: 2,
                ),
              ),
            ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(raftText(context, label), style: labelStyle),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(alignment: Alignment.topRight, child: value),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(raftText(context, label), style: labelStyle),
                const SizedBox(height: 4),
                value,
              ],
            ),
    );
  }
}

/// `break-all font-mono text-xs font-bold` detail value.
class RaftConnectedAppMonoValue extends StatelessWidget {
  const RaftConnectedAppMonoValue(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      value,
      style: RaftTypography.mono(
        t,
        size: 12,
        line: 16,
        color: RaftSettingsText(t).strong,
      ).copyWith(fontWeight: FontWeight.w700),
    );
  }
}

/// OAuthScopeSummaryPanel: SectionEyebrow title, optional description, and
/// the `<details>` box (`border … bg-layer-canvas-muted
/// theme-brutal:bg-brutal-cream p-2`) whose `Declared access` summary
/// discloses the compact scope chips.
class RaftOAuthScopeSummary extends StatefulWidget {
  const RaftOAuthScopeSummary({
    super.key,
    required this.title,
    required this.scopes,
    this.description,
    this.tooltips = const {},
    this.emptyLabel,
    this.resourceScopes = const {},
  });
  final String title;
  final String? description;

  /// Visible scopes (already normalised by the caller).
  final List<String> scopes;
  final Map<String, String> tooltips;

  /// `requiresResource` scopes (`bg-accent-soft/30` chips).
  final Set<String> resourceScopes;

  /// `No active grant scopes…` when [scopes] is empty.
  final String? emptyLabel;
  @override
  State<RaftOAuthScopeSummary> createState() => _RaftOAuthScopeSummaryState();
}

class _RaftOAuthScopeSummaryState extends State<RaftOAuthScopeSummary> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final soft = t.brutal
        ? Colors.black.withValues(alpha: .15)
        : t.colors['line-muted']!;
    final summary = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      weight: FontWeight.w700,
      color: text.strong,
    );
    Widget chip(String scope) => RaftTooltip(
      message: widget.tooltips[scope] ?? scope,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.resourceScopes.contains(scope)
              ? (t.brutal
                    ? Color.alphaBlend(
                        t.product.softSignal.withValues(alpha: .2),
                        Colors.white,
                      )
                    : Color.alphaBlend(
                        t.colors['accent-soft']!.withValues(alpha: .3),
                        t.panel,
                      ))
              : (t.brutal ? Colors.white : t.panel),
          border: Border.all(
            color: t.brutal
                ? Colors.black.withValues(alpha: .2)
                : t.colors['line-strong']!,
          ),
        ),
        child: Text(
          scope,
          style: RaftTypography.body(
            t,
            size: 11,
            line: 11 * 1.5,
            weight: FontWeight.w700,
            color: t.brutal ? Colors.black.withValues(alpha: .7) : t.muted,
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSectionEyebrow(widget.title),
        if (widget.description != null) ...[
          // `space-y-2` bottom margin collapses with the description's `mt-2`.
          const SizedBox(height: 8),
          Text(widget.description!, style: _relaxedDialog(t, text.muted)),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: t.brutal
                ? t.product.brutalCream
                : t.colors['layer-canvas-muted'],
            border: Border.all(color: soft, width: t.brutal ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => open = !open),
                child: Semantics(
                  button: true,
                  expanded: open,
                  child: Row(
                    children: [
                      // The `<summary>` disclosure marker.
                      SizedBox(
                        width: 13,
                        height: 16,
                        child: CustomPaint(
                          painter: _DisclosureMarker(open, text.strong),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          raftText(context, 'Declared access'),
                          style: summary.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (open) ...[
                const SizedBox(height: 8),
                if (widget.scopes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: t.brutal ? Colors.white : t.panel,
                      border: Border.all(color: soft, width: t.brutal ? 2 : 1),
                    ),
                    child: Text(
                      widget.emptyLabel ?? '',
                      style: summary.copyWith(color: text.faint),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final s in widget.scopes) chip(s)],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Blink's painted `<summary>` marker: a solid triangle (6 x 8 closed,
/// 8 x 6 open) centred in the 13px marker box.
class _DisclosureMarker extends CustomPainter {
  const _DisclosureMarker(this.open, this.color);
  final bool open;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(open ? 4.0 : 3.0, size.height / 2);
    final path = open
        ? (Path()
            ..moveTo(c.dx - 4, c.dy - 3)
            ..lineTo(c.dx + 4, c.dy - 3)
            ..lineTo(c.dx, c.dy + 3)
            ..close())
        : (Path()
            ..moveTo(c.dx - 3, c.dy - 4)
            ..lineTo(c.dx + 3, c.dy)
            ..lineTo(c.dx - 3, c.dy + 4)
            ..close());
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DisclosureMarker old) =>
      old.open != open || old.color != color;
}

/// AppNotificationRequestSummary / InstalledAppNotifications: the
/// `border-t-2 border-line-strong pt-4` section with the Bell 18 header,
/// the App permissions eyebrow, a description, an optional status badge and
/// the `sm:grid-cols-N` columns of scope chips.
class RaftAppPermissionsSummary extends StatelessWidget {
  const RaftAppPermissionsSummary({
    super.key,
    required this.description,
    required this.columns,
    this.badge,
    this.loading,
  });
  final String description;

  /// (label, values, empty copy) per column.
  final List<(String, List<String>, String)> columns;
  final RaftConnectedAppBadge? badge;

  /// The loading line replaces the section while the state reads.
  final String? loading;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final topRule = BoxDecoration(
      border: Border(
        top: BorderSide(
          color: t.brutal ? Colors.black : t.colors['line-strong']!,
          width: 2,
        ),
      ),
    );
    if (loading != null) {
      return Container(
        padding: const EdgeInsets.only(top: 12),
        decoration: topRule,
        child: Text(
          loading!,
          style: RaftTypography.body(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
            color: text.faint,
          ),
        ),
      );
    }
    final columnLabel = RaftTypography.body(
      t,
      size: 10,
      line: 15,
      weight: FontWeight.w700,
      color: text.faint,
    ).copyWith(letterSpacing: 1);
    Widget column((String, List<String>, String) c) => Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: t.brutal
                ? Colors.black.withValues(alpha: .15)
                : t.colors['line-muted']!,
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.$1.toUpperCase(), style: columnLabel),
          const SizedBox(height: 8),
          if (c.$2.isEmpty)
            // A `text-xs` inline span inside a block: the line box keeps the
            // 16px / 24px parent strut, so the 12px text sits 5px lower.
            Padding(
              // ds-allow: Web AppNotificationsControls.tsx scope column `text-xs` span in the 24px line box (5 + 16 + 3)
              padding: const EdgeInsets.only(top: 5, bottom: 3),
              child: Text(
                c.$3,
                style: RaftTypography.body(
                  t,
                  size: 12,
                  line: 16,
                  weight: FontWeight.w700,
                  color: t.brutal
                      ? Colors.black.withValues(alpha: .45)
                      : t.muted,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in c.$2)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.brutal ? Colors.white : t.panel,
                      border: Border.all(
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .2)
                            : t.colors['line-strong']!,
                      ),
                    ),
                    child: Text(
                      v,
                      style: RaftTypography.body(
                        t,
                        size: 11,
                        line: 11 * 1.5,
                        weight: FontWeight.w700,
                        color: t.brutal
                            ? Colors.black.withValues(alpha: .7)
                            : t.muted,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
    final wide = raftBreakpointWidth(context) >= 640;
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: topRule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `flex flex-wrap items-start justify-between gap-2`: the badge
          // wraps below the description when the pair does not fit.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RaftIcon(
                      RaftGlyph.bell,
                      size: 18,
                      color: text.strong,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaftSectionEyebrow(
                          raftText(context, 'App permissions'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: RaftTypography.body(
                            t,
                            size: 12,
                            line: 16,
                            color: t.brutal
                                ? Colors.black.withValues(alpha: .55)
                                : t.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (badge != null) _Badge(badge!),
            ],
          ),
          const SizedBox(height: 12),
          if (wide)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in columns.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: column(c)),
                  ],
                ],
              ),
            )
          else
            for (final (i, c) in columns.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              column(c),
            ],
        ],
      ),
    );
  }
}

/// The listing / installed-app detail `Card` (`w-full max-w-2xl space-y-4
/// p-5`) in the Web `Modal` layer: logo, SectionEyebrow, `text-xl font-bold`
/// title with badge, byline, close button, then [sections] and the
/// `border-t-2 pt-4` footer.
class RaftConnectedAppDetailCard extends StatelessWidget {
  const RaftConnectedAppDetailCard({
    super.key,
    required this.eyebrow,
    required this.name,
    required this.initials,
    required this.byline,
    required this.onClose,
    required this.closeLabel,
    required this.sections,
    required this.footer,
    this.logoUrl,
    this.badge,
    this.error,
  });
  final String eyebrow, name, initials, byline, closeLabel;
  final String? logoUrl, error;
  final RaftConnectedAppBadge? badge;
  final VoidCallback onClose;
  final List<Widget> sections;

  /// Footer buttons (`flex items-center justify-end gap-2`).
  final List<Widget> footer;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftAppLogo(
            initials: initials,
            logoUrl: logoUrl,
            size: RaftAppLogoSize.lg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RaftSectionEyebrow(raftText(context, eyebrow)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        name,
                        style: RaftTypography.body(
                          t,
                          size: 20,
                          line: 28,
                          weight: FontWeight.w700,
                          color: text.strong,
                        ),
                      ),
                    ),
                    if (badge != null) _Badge(badge!),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  byline,
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 16,
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .55)
                        : t.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          RaftCloseButton(onPressed: onClose, tooltip: closeLabel),
        ],
      ),
      if (error != null && error!.isNotEmpty) RaftConnectedAppsError(error!),
      ...sections,
      Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: text.edge, width: 2)),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: footer,
        ),
      ),
    ];
    return RaftRecipeCard(
      maxWidth: 672,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: 16),
            child,
          ],
        ],
      ),
    );
  }
}

/// A modal footer / danger-zone `Button` (`size="md"`).
class RaftConnectedAppButton extends StatelessWidget {
  const RaftConnectedAppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = RaftButtonRecipeVariant.default_,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant variant;
  @override
  Widget build(BuildContext context) => RaftSettingsRecipeButton(
    label: label,
    variant: variant,
    size: RaftButtonRecipeSize.md,
    onPressed: onPressed,
  );
}

/// Danger zone body: `flex-col gap-3 sm:flex-row sm:items-center
/// sm:justify-between`, `text-xs leading-relaxed` copy and the action.
class RaftConnectedAppDangerRow extends StatelessWidget {
  const RaftConnectedAppDangerRow({
    super.key,
    required this.description,
    required this.action,
  });
  final String description;
  final Widget action;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final copy = Text(
      description,
      style: _relaxedDialog(t, RaftSettingsText(t).muted),
    );
    return raftBreakpointWidth(context) >= 640
        ? Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 12),
              action,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 12), action],
          );
  }
}

/// `text-sm leading-relaxed` paragraph inside a detail section
/// (`mb-2 … text-foreground-muted theme-brutal:text-black/70`).
class RaftConnectedAppParagraph extends StatelessWidget {
  const RaftConnectedAppParagraph(this.text, {super.key, this.small = false});
  final String text;

  /// `text-xs` (Distribution note).
  final bool small;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.brutal ? Colors.black.withValues(alpha: .7) : t.muted;
    return Text(
      text,
      style: small
          ? _relaxedDialog(t, color)
          : RaftTypography.body(t, size: 14, line: 14 * 1.625, color: color),
    );
  }
}

/// ConfirmDialog message with an inline `<code className="font-mono
/// font-bold">` value between the catalog prefix and suffix.
class RaftInlineCodeMessage extends StatelessWidget {
  const RaftInlineCodeMessage({
    super.key,
    required this.prefix,
    required this.code,
    required this.suffix,
  });
  final String prefix, code, suffix;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: code,
            style: TextStyle(
              fontFamily: t.monoFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: suffix),
        ],
      ),
    );
  }
}

/// InstalledAppNotifications `approval_required` strip: `border-l-4
/// border-warning bg-warning-soft px-3 py-2` with the notice, the newly
/// requested groups and the approve action.
class RaftAppPermissionsApproval extends StatelessWidget {
  const RaftAppPermissionsApproval({
    super.key,
    required this.notice,
    required this.groups,
    this.action,
  });
  final String notice;
  final List<String> groups;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notice,
          style: RaftTypography.body(
            t,
            size: 12,
            line: 16,
            weight: FontWeight.w700,
            color: t.brutal ? Colors.black.withValues(alpha: .7) : t.muted,
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final g in groups)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.brutal ? Colors.white : t.panel,
                    border: Border.all(
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .2)
                          : t.colors['line-strong']!,
                    ),
                  ),
                  child: Text(
                    g,
                    style: RaftTypography.body(
                      t,
                      size: 11,
                      line: 11 * 1.5,
                      weight: FontWeight.w700,
                      color: t.brutal
                          ? Colors.black.withValues(alpha: .7)
                          : t.muted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.brutal
            ? Color.alphaBlend(
                t.product.softSignal.withValues(alpha: .2),
                Colors.white,
              )
            : t.colors['warning-soft'],
        border: Border(
          left: BorderSide(
            color: t.brutal ? t.product.softSignal : t.colors['warning']!,
            width: 4,
          ),
        ),
      ),
      child: raftBreakpointWidth(context) >= 640 && action != null
          ? Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 12),
                action!,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
    );
  }
}
