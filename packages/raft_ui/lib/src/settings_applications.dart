// Settings > Workspace > Applications from the Web client (raft-source
// 26f77ef, packages/web/src/components/settings/SettingsPanel.tsx
// IntegrationsSection + AppNotificationsControls.tsx +
// SettingsSegmentedControls.tsx ConnectedAppsTabSegmentedControl): the
// Apps toolbar, the three app collections (grid or list), and the listing
// and installed-app detail cards.
// The app supplies the projected rows and callbacks; class lists live here.
import 'raft/segmented_control.dart'
    show RaftSegmentedControl, RaftSegmentedOption;
import 'raft/button.dart';
import 'raft/fit_toolbar.dart';
import 'banner.dart';
import 'card.dart' show RaftCard;

import 'package:flutter/material.dart';

import 'raft_underline.dart';
import 'system_inset.dart';
import 'design_primitives.dart'
    show
        RaftDropdownAlign,
        RaftDropdownMenu,
        RaftInheritedFontScope,
        RaftInteractive,
        RaftMenuEntry,
        RaftTypography;
import 'empty_state.dart';
import 'error_presentation.dart';
import 'icons.dart';
import 'idle_work.dart';
import 'indicators.dart' show RaftSkeleton, RaftSkeletonVariant;
import 'interaction.dart';
import 'list_items.dart' show RaftSectionEyebrow;
import 'localization.dart';
import 'overlays/dialog.dart';
import 'panel_layout.dart' show RaftCssText;
import 'pull_to_refresh.dart';
import 'recipe_min_height.dart' show RaftMinHeightBox;
import 'recipe_surface.dart';
import 'raft/avatar.dart';
import 'raft/badge.dart';
import 'raft/list_row.dart' show RaftListRowSkeleton;
import 'token_geometry.dart';
import 'recipes/badge.g.dart';
import 'recipes/button_variants.g.dart'
    show RaftButtonRecipeSize, RaftButtonRecipeVariant;
import 'recipes/sans.g.dart';
import 'separator.dart';
import 'settings_controls.dart';
import 'settings_layout.dart';
import 'select_field.dart';
import 'surface_background_scope.dart';
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopMetrics, RaftTypeScale;
import 'tooltip.dart';
import 'viewport_breakpoints.dart';
import 'sized_image.dart';

enum RaftConnectedAppsTab { marketplace, installed, myApps }

enum RaftConnectedAppsLayout { grid, list }

/// A raft-ui `Badge` on an app row.
@immutable
class RaftConnectedAppBadge {
  const RaftConnectedAppBadge(this.label, {this.variant, this.appearance});

  /// ConnectedAppDistributionBadge / origin badges.
  const RaftConnectedAppBadge.success(String label)
    : this(
        label,
        variant: RaftBadgeRecipeVariant.success,
        appearance: RaftBadgeRecipeAppearance.soft,
      );
  const RaftConnectedAppBadge.warning(String label)
    : this(
        label,
        variant: RaftBadgeRecipeVariant.warning,
        appearance: RaftBadgeRecipeAppearance.soft,
      );
  const RaftConnectedAppBadge.outline(String label)
    : this(label, appearance: RaftBadgeRecipeAppearance.outline);
  const RaftConnectedAppBadge.muted(String label)
    : this(
        label,
        variant: RaftBadgeRecipeVariant.muted,
        appearance: RaftBadgeRecipeAppearance.soft,
      );
  final String label;
  final RaftBadgeRecipeVariant? variant;
  final RaftBadgeRecipeAppearance? appearance;
}

/// The marketplace card's trailing state.
enum RaftMarketplaceAppState {
  /// `Badge variant="success"` Installed.
  installed,

  /// The `bg-accent-soft … btn-brutal-sm theme-brutal:bg-brutal-pink`
  /// Install pill (managers).
  install,

  /// `Badge appearance="outline"` Available (read-only viewers).
  available,
}

/// ConnectedAppLogo: AvatarSlot `type="app"` (initials placeholder or logo).
enum RaftAppLogoSize {
  xs(27, 11, 13),

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
    this.onReviewPermissions,
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
  final VoidCallback? onReviewPermissions;

  /// Edit (Pencil) / Uninstall.
  final String? actionLabel;
  final RaftGlyph? actionGlyph;
  final VoidCallback? onAction;
}

/// IntegrationsSection page body.
class RaftConnectedAppsSection extends StatelessWidget {
  const RaftConnectedAppsSection({
    super.key,
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
    this.marketplaceFooter,
    this.installedWarning,
    this.installedFooter,
    this.notice,
    this.standalone = false,
    this.typeFilter,
    this.sortFilter,
    this.onClearFilters,
    this.onBrowseMarketplace,
    this.onRetry,
    this.onRefresh,
    this.recommendation,
    this.emptyDetail,
    this.marketplaceLoading = false,
  });

  /// `renderClientSecretReveal` under the filters while the editor is closed.
  final Widget? secretReveal;
  final String? adminNote;
  final bool loading;

  /// Own a bounded settings viewport and mount only visible app rows.
  final bool scrollable;

  /// Register app (managers).
  final VoidCallback? onRegister;
  final RaftConnectedAppsTab tab;

  /// Marketplace is absent in Settings and until its total arrives on the page.
  final ({int? marketplace, int installed, int myApps}) counts;
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
  final String? emptyDetail;
  final String? myAppsIntro, reviewNote;
  final Widget? marketplaceFooter;
  final Widget? installedWarning;
  final Widget? installedFooter;
  final Widget? notice;
  final bool standalone;
  final RaftFitPicker? typeFilter, sortFilter;
  final VoidCallback? onClearFilters, onBrowseMarketplace, onRetry;
  final RefreshCallback? onRefresh;
  final RaftMarketplaceAppTile? recommendation;
  final bool marketplaceLoading;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text = RaftSettingsText(t);
    final pageInset = !t.desktop && raftBreakpointWidth(context) >= 768
        ? RaftSpace.x5
        : RaftSpace.x4;
    final toolbar = _toolbar(context);
    final placeholders = _AppsLoading(
      key: ValueKey(tab),
      tab: tab,
      layout: layout,
      canManage: onRegister != null,
    );
    final pending =
        error == null &&
        (tab == RaftConnectedAppsTab.marketplace
            ? marketplaceLoading
            : loading);
    final empty = switch ((emptyMessage, emptyDetail)) {
      (final String title, final String detail) => RaftEmptyState(
        title: title,
        detail: detail,
        glyph: RaftGlyph.blocks,
        blockPadding: 40,
        action: onBrowseMarketplace == null
            ? null
            : RaftButton(
                label: raftText(context, 'Browse marketplace'),
                onPressed: onBrowseMarketplace,
                uiSize: RaftButtonSize.md,
              ),
      ),
      (final String title, null) => _EmptyBox(title),
      _ => null,
    };
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
          if (marketplace.isNotEmpty && marketplaceFooter != null)
            const SizedBox(height: RaftSpace.x3),
          ?marketplaceFooter,
          if (reviewNote != null) ...[
            const SizedBox(height: 12),
            Text(
              reviewNote!,
              textAlign: TextAlign.center,
              style: RaftTypography.inherited(
                t,
                size: 12,
                line: 16,
                color: t.muted,
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
          if (installedWarning != null) ...[
            const SizedBox(height: RaftSpace.x2),
            installedWarning!,
          ],
          ?installedFooter,
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
      if (!standalone)
        RaftSettingsSectionHeader(
          label: 'Apps',
          glyph: RaftGlyph.appWindow,
          bottom: 0,
          action: onRegister == null
              ? null
              : RaftDropdownMenu(
                  key: const ValueKey('connected-apps-register'),
                  surfaceKey: const ValueKey('settings-apps-add-menu'),
                  label: raftTextZh(context, 'Add app', '添加应用'),
                  align: RaftDropdownAlign.end,
                  entries: _registerOptions(context),
                  triggerBuilder: (context, focus, press) => RaftButton(
                    label: raftTextZh(context, 'Add app', '添加应用'),
                    glyph: RaftGlyph.plus,
                    trailingGlyph: RaftGlyph.chevronDown,
                    glyphSize: 14,
                    gap: RaftSpace.x1_5,
                    uiVariant: RaftButtonVariant.accent,
                    uiSize: RaftButtonSize.md,
                    focusNode: focus,
                    onPressed: press,
                  ),
                ),
        ),
      if (!standalone) toolbar,
      if (adminNote != null)
        Text(
          adminNote!,
          style: t.scale(RaftTypeScale.footnote, color: t.muted),
        ),
      ?notice,
      if (error case final message? when message.isNotEmpty)
        onRetry == null
            ? RaftConnectedAppsError(message)
            : RaftBanner(
                description: message,
                size: RaftBannerRecipeSize.sm,
                live: false,
                action: RaftButton(
                  glyph: RaftGlyph.refreshCw,
                  label: raftText(context, 'Retry'),
                  uiVariant: RaftButtonVariant.outline,
                  onPressed: onRetry,
                ),
              ),
      ?secretReveal,
      pending ? placeholders : body,
    ];
    if (scrollable) {
      final refresh = onRefresh;
      final pullable = refresh != null && RaftInteraction.of(context).touch;
      final cards = <Widget>[
        if (tab == RaftConnectedAppsTab.marketplace)
          for (final app in marketplace)
            _MarketplaceCard(app: app, layout: layout)
        else
          for (final row in rows) _AppRowCard(row: row, layout: layout),
      ];
      Widget gap(double height) =>
          SliverToBoxAdapter(child: SizedBox(height: height));
      Widget heading(String title) => SliverToBoxAdapter(
        child: Semantics(
          header: true,
          child: RaftCssText(
            title,
            style: RaftSansRecipe.resolve(
              size: RaftSansRecipeSize.group,
              states: t.recipeStates(),
              tokens: t.recipeTokens,
            ).base.text(t.recipeTokens),
          ),
        ),
      );
      final scroller = RaftInheritedFont(
        child: CustomScrollView(
          primary: false,
          physics: pullable ? const AlwaysScrollableScrollPhysics() : null,
          slivers: [
            SliverPadding(
              padding: raftScrollPadding(
                context,
                standalone
                    ? EdgeInsets.symmetric(horizontal: pageInset, vertical: 16)
                    : RaftSettingsPanelFrame.contentInset.add(
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
                  if (children.length > 1) gap(16),
                  if (recommendation case final app?) ...[
                    heading(raftTextZh(context, 'Recommended for you', '为你推荐')),
                    gap(8),
                    _SliverCollection(
                      layout: layout,
                      children: [_MarketplaceCard(app: app, layout: layout)],
                    ),
                    gap(16),
                    heading(raftText(context, 'Installed')),
                    gap(8),
                  ],
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
                  if (pending)
                    SliverToBoxAdapter(child: placeholders)
                  else
                    _SliverCollection(layout: layout, children: cards),
                  if (empty != null) ...[
                    if (emptyDetail == null &&
                        tab != RaftConnectedAppsTab.myApps)
                      gap(tab == RaftConnectedAppsTab.marketplace ? 12 : 8),
                    SliverToBoxAdapter(child: empty),
                  ],
                  if (tab == RaftConnectedAppsTab.marketplace &&
                      marketplaceFooter != null) ...[
                    if (marketplace.isNotEmpty) gap(RaftSpace.x3),
                    SliverToBoxAdapter(child: marketplaceFooter),
                  ],
                  if (tab == RaftConnectedAppsTab.installed) ...[
                    if (installedWarning != null) ...[
                      gap(RaftSpace.x2),
                      SliverToBoxAdapter(child: installedWarning),
                    ],
                    if (installedFooter != null) ...[
                      gap(standalone ? RaftSpace.x6 : RaftSpace.x4),
                      SliverToBoxAdapter(child: installedFooter),
                    ],
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
                          color: t.muted,
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
      if (!standalone) return scroller;
      return ColoredBox(
        color: t.canvas,
        child: RaftSurfaceBackgroundScope(
          color: t.canvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _pageToolbar(t, toolbar, pageInset),
              Expanded(
                child: refresh == null
                    ? scroller
                    : RaftPullToRefresh(
                        enabled: pullable,
                        onRefresh: refresh,
                        child: scroller,
                      ),
              ),
            ],
          ),
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

  Widget _pageToolbar(RaftTokens t, Widget toolbar, double inset) {
    final air = t.desktop ? RaftDesktopMetrics.headerAir : 8.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        inset,
        air,
        inset,
        t.desktop ? air - 1 : air,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.ui.lineSeam)),
      ),
      child: toolbar,
    );
  }

  Widget _toolbar(BuildContext context) {
    String tr(String value) => raftText(context, value);
    final filters = [
      ?typeFilter,
      RaftFitPicker(
        key: const ValueKey('connected-apps-category-filter'),
        label:
            categories.where((entry) => entry.$1 == category).firstOrNull?.$2 ??
            tr('All categories'),
        glyph: RaftGlyph.layoutList,
        applied: category != 'all',
        labelOrder: 20,
        menuEntries: [
          for (final (value, label) in categories)
            RaftMenuEntry(
              label: label,
              checked: value == category,
              onPressed: () => onCategory(value),
            ),
        ],
      ),
    ];
    return RaftFitToolbar(
      wrap: true,
      semanticLabel: tr('Apps'),
      children: [
        RaftFitGroup(
          firstLine: true,
          items: [_AppsScope(tab: tab, counts: counts, onTab: onTab)],
        ),
        RaftFitSearch(
          semanticLabel: tr('Search apps'),
          hintText: tr('Search apps…'),
          clearLabel: tr('Clear search'),
          controller: searchController,
          fieldKey: const ValueKey('connected-apps-search'),
          collapseOrder: 70,
          onChanged: onSearch,
        ),
        RaftFitGroup(
          scroll: true,
          wrapOrder: 30,
          end: onClearFilters == null
              ? null
              : RaftButton(
                  uiVariant: RaftButtonVariant.ghost,
                  uiSize: RaftButtonSize.md,
                  label: raftTextZh(context, 'Clear all', '清除筛选'),
                  onPressed: onClearFilters,
                ),
          items: [
            ...filters.where((picker) => picker.applied),
            ...filters.where((picker) => !picker.applied),
          ],
        ),
        RaftFitGroup(
          firstLine: true,
          moreOrder: 60,
          moreItem: [
            if (sortFilter?.menuEntries case final choices?) ...[
              ...choices,
              const RaftMenuEntry.separator(),
            ],
            for (final (value, label) in [
              (RaftConnectedAppsLayout.grid, 'Grid view'),
              (RaftConnectedAppsLayout.list, 'List view'),
            ])
              RaftMenuEntry(
                label: tr(label),
                checked: value == layout,
                onPressed: () => onLayout(value),
              ),
          ],
          items: [
            ?sortFilter,
            _LayoutToggle(value: layout, onChanged: onLayout),
          ],
        ),
        RaftFitGroup(
          firstLine: true,
          items: [
            const RaftFitMore(key: ValueKey('apps-toolbar-more')),
            if (standalone && onRegister != null)
              RaftFitButton(
                key: const ValueKey('register-app-menu-trigger'),
                label: raftTextZh(context, 'Add app', '添加应用'),
                glyph: RaftGlyph.plus,
                variant: RaftButtonVariant.primary,
                plusOrder: 40,
                menuEntries: _registerOptions(context),
              ),
          ],
        ),
      ],
    );
  }

  List<RaftMenuEntry> _registerOptions(BuildContext context) => [
    RaftMenuEntry(
      label: raftTextZh(context, 'Create a Raft app', '创建 Raft 应用'),
      glyph: RaftGlyph.globe,
      onPressed: onRegister,
    ),
  ];
}

class _AppsScope extends RaftFitItem {
  const _AppsScope({
    required this.tab,
    required this.counts,
    required this.onTab,
  }) : super(labelOrder: 50);

  final RaftConnectedAppsTab tab;
  final ({int? marketplace, int installed, int myApps}) counts;
  final ValueChanged<RaftConnectedAppsTab> onTab;

  @override
  bool get hasLabelForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    const installed = RaftConnectedAppsTab.installed;
    const market = RaftConnectedAppsTab.marketplace;
    const developer = RaftConnectedAppsTab.myApps;
    final tabs = [
      (installed, 'Installed', counts.installed, 'installed'),
      (market, 'Marketplace', counts.marketplace, 'marketplace'),
      (developer, 'Developer', counts.myApps, 'my-apps'),
    ];
    String tr(String value) => raftText(context, value);
    final line = RaftTokens.of(context).desktop
        ? RaftDesktopMetrics.controlHeight
        : 32.0;
    if (form == RaftFitForm.full) {
      return Align(
        widthFactor: 1,
        heightFactor: line / (line + 6),
        child: RaftSegmentedControl<RaftConnectedAppsTab>(
          label: tr('Apps'),
          value: tab,
          onChanged: onTab,
          visualHeight: line,
          minimumTargetSize: line,
          items: [
            for (final (value, label, count, id) in tabs)
              RaftSegmentedOption(
                value: value,
                label: tr(label),
                count: count?.toString(),
                itemKey: probe ? null : ValueKey('connected-apps-tab-$id'),
              ),
          ],
        ),
      );
    }
    final active = tabs.firstWhere(
      (entry) => entry.$1 == tab,
      orElse: () => tabs.first,
    );
    final tokens = RaftTokens.of(context);
    return RaftSelectField<RaftConnectedAppsTab>(
      key: probe ? null : const ValueKey('connected-apps-scope-select'),
      label: '${tr('Apps')}, ${tr(active.$2)}',
      toolbarPicker: true,
      popupMinWidth: 160,
      value: tab,
      onChanged: (value) {
        if (value != null) onTab(value);
      },
      items: [
        for (final (value, label, count, id) in tabs)
          RaftSelectItem(
            value: value,
            label: tr(label),
            labelKey: probe ? null : ValueKey('connected-apps-tab-$id'),
            listTrailing: count == null
                ? null
                : Text(
                    '$count',
                    style: tokens.scale(
                      RaftTypeScale.monoMeta,
                      color: tokens.ui.foregroundHint,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// `text-xs leading-relaxed` (12 / 19.5).
TextStyle _relaxed(RaftTokens t, Color color) =>
    RaftTypography.inherited(t, size: 12, line: 12 * 1.625, color: color);

/// The same line box inside a Dialog portal, whose text is Geist.
TextStyle _relaxedDialog(RaftTokens t, Color color) =>
    RaftTypography.body(t, size: 12, line: 12 * 1.625, color: color);

/// ConnectedAppsErrorBanner: `Banner intent="warning" density="sm"`.
class RaftConnectedAppsError extends StatelessWidget {
  const RaftConnectedAppsError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => RaftErrorBanner(message, small: true);
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // Web: `<div className="px-4 py-8 text-center text-callout
    // text-foreground-hint">`, bare text without a card.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: t.scale(RaftTypeScale.callout, color: t.ui.foregroundHint),
        ),
      ),
    );
  }
}

class _AppsLoading extends StatefulWidget {
  const _AppsLoading({
    super.key,
    required this.tab,
    required this.layout,
    required this.canManage,
  });

  final RaftConnectedAppsTab tab;
  final RaftConnectedAppsLayout layout;
  final bool canManage;

  @override
  State<_AppsLoading> createState() => _AppsLoadingState();
}

class _AppsLoadingState extends State<_AppsLoading> {
  final delay = RaftIdleTimer(yieldToAnimation: false);
  var shown = false;

  @override
  void initState() {
    super.initState();
    delay.start(const Duration(seconds: 1), () => setState(() => shown = true));
  }

  @override
  void dispose() {
    delay.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!shown) return const SizedBox.shrink();
    final installed = widget.tab == RaftConnectedAppsTab.installed;
    final marketplace = widget.tab == RaftConnectedAppsTab.marketplace;
    final grid = widget.layout == RaftConnectedAppsLayout.grid;
    final collection = installed || (marketplace && grid);
    final count = marketplace ? 6 : 4;
    Widget placeholder(int index) => collection
        ? _AppCardSkeleton(
            installed: installed,
            grid: grid,
            canManage: widget.canManage,
          )
        : RaftListRowSkeleton(index: index, description: true);
    return _Collection(
      key: ValueKey(
        installed
            ? 'apps-installed-loading-collection'
            : marketplace
            ? 'apps-marketplace-loading-collection'
            : 'apps-developer-loading-collection',
      ),
      layout: collection ? widget.layout : RaftConnectedAppsLayout.list,
      children: [
        for (var index = 0; index < count; index++) placeholder(index),
      ],
    );
  }
}

class _AppCardSkeleton extends StatelessWidget {
  const _AppCardSkeleton({
    required this.installed,
    required this.grid,
    required this.canManage,
  });

  final bool installed, grid, canManage;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    Widget block(double width, double height) =>
        RaftSkeleton(fromRecipe: true, width: width, height: height);
    Widget line(double width, String scale) {
      final size = t.typeSlot(scale);
      return RaftMinHeightBox(
        height: size.lineHeight,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: RaftSkeleton(
            fromRecipe: true,
            variant: RaftSkeletonVariant.line,
            width: width,
            height: size.fontSize * .75,
          ),
        ),
      );
    }

    final logo = installed ? 35.0 : 51.0;
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: RaftSpace.x3,
      children: [
        block(logo, logo),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line(installed ? 128 : 112, 'body'),
              const SizedBox(height: RaftSpace.half),
              line(installed ? 192 : 160, 'footnote'),
              if (raftBreakpointWidth(context) < 768) line(96, 'footnote'),
              if (installed) ...[
                const SizedBox(height: RaftSpace.x2),
                block(80, 22),
                const SizedBox(height: RaftSpace.x1),
                line(grid ? 112 : 256, 'callout'),
              ],
            ],
          ),
        ),
      ],
    );
    final action = canManage
        ? block(
            installed ? 96 : 64,
            t.desktop ? RaftDesktopMetrics.controlHeight : 32,
          )
        : installed
        ? null
        : block(80, 22);
    final body = !grid && raftBreakpointWidth(context) >= 640
        ? Row(
            spacing: RaftSpace.x3,
            children: [
              Expanded(child: info),
              ?action,
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: RaftSpace.x3,
            children: [
              info,
              if (action != null)
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          );
    return ExcludeSemantics(
      child: installed
          ? RaftCard.item(
              interactive: false,
              child: grid
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 184 - 24),
                      child: body,
                    )
                  : body,
            )
          : RaftCard(padding: const EdgeInsets.all(RaftSpace.x3), child: body),
    );
  }
}

/// `grid gap-3 md:grid-cols-2` (rows stretch to the taller card) or
/// `space-y-2`.
class _Collection extends StatelessWidget {
  const _Collection({super.key, required this.layout, required this.children});
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

class _LayoutToggle extends RaftFitItem {
  const _LayoutToggle({required this.value, required this.onChanged})
    : super(labelOrder: 10);
  final RaftConnectedAppsLayout value;
  final ValueChanged<RaftConnectedAppsLayout> onChanged;

  @override
  bool get hasLabelForm => true;

  @override
  Widget buildForm(
    BuildContext context,
    RaftFitForm form, {
    required bool probe,
    List<RaftMenuEntry> moreEntries = const [],
  }) {
    final line = RaftTokens.of(context).desktop
        ? RaftDesktopMetrics.controlHeight
        : 32.0;
    final iconsOnly = form != RaftFitForm.full;
    return Align(
      widthFactor: 1,
      heightFactor: line / (line + 6),
      child: RaftSegmentedControl<RaftConnectedAppsLayout>(
        label: raftText(context, 'App layout'),
        value: value,
        visualHeight: line,
        minimumTargetSize: line,
        iconsOnly: iconsOnly,
        onChanged: (layout) {
          if (layout != value) onChanged(layout);
        },
        items: [
          for (final (layout, label, glyph) in const [
            (RaftConnectedAppsLayout.grid, 'Grid view', RaftGlyph.layoutGrid),
            (RaftConnectedAppsLayout.list, 'List view', RaftGlyph.list),
          ])
            RaftSegmentedOption(
              value: layout,
              glyph: glyph,
              label: label,
              tooltip: iconsOnly && !probe ? label : null,
              itemKey: probe
                  ? null
                  : ValueKey('connected-apps-view-${layout.name}'),
            ),
        ],
      ),
    );
  }
}

/// ConnectedAppLogo uses the identity avatar recipe in each of its slots.
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
    final avatarSize = switch (size) {
      RaftAppLogoSize.xs => RaftAvatarSize.sm,
      RaftAppLogoSize.sm => RaftAvatarSize.md,
      RaftAppLogoSize.md || RaftAppLogoSize.lg => RaftAvatarSize.lg,
    };
    final url = logoUrl?.trim();
    final fallback = RaftAvatarInitials(initials, size: avatarSize);
    return RaftStickerAvatar(
      size: avatarSize,
      type: RaftAvatarType.human,
      child: url == null || url.isEmpty
          ? fallback
          : RaftSizedImage.avatar(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.badge);
  final RaftConnectedAppBadge badge;
  @override
  Widget build(BuildContext context) => RaftBadge(
    label: raftText(context, badge.label),
    variant: badge.variant ?? RaftBadgeRecipeVariant.default_,
    appearance: badge.appearance ?? RaftBadgeRecipeAppearance.solid,
    fontFamily: RaftInheritedFontScope.active(context)
        ? RaftTokens.of(context).headingFont
        : null,
  );
}

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
                  RaftCssText(
                    app.name,
                    style: RaftTypography.inherited(
                      t,
                      size: 16,
                      line: 24,
                      weight: FontWeight.w600,
                      color: text.strong,
                    ),
                  ),
                  if (app.badge != null) _Badge(app.badge!),
                ],
              ),
              const SizedBox(height: 2),
              RaftCssText(
                app.byline,
                style: t.scale(RaftTypeScale.footnote, color: t.muted),
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
        RaftConnectedAppBadge.muted(app.stateLabel),
      ),
      RaftMarketplaceAppState.install => RaftButton(
        label: app.stateLabel,
        uiVariant: RaftButtonVariant.outline,
        uiSize: RaftButtonSize.md,
        inertWhenDisabled: true,
        button: false,
      ),
    };
    return RaftCard.item(
      key: ValueKey('connected-app-${app.id}'),
      onTap: app.onOpen,
      padding: const EdgeInsets.all(12),
      child: grid
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
            color: t.muted,
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
          final color = st.hovered ? (t.strong) : (t.muted);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: RaftUnderlinedText(
                  visible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // `decoration-[1.5px] underline-offset-[3px]`: the line
                  // stops before the arrow.
                  underlineOffset: 3,
                  underlineThickness: 1.5,
                  style: RaftTypography.mono(
                    t,
                    size: 12,
                    line: 16,
                    color: color,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // raft-ui `TextLinkExternalIcon`: ArrowUpRight, 0.857em, 2px
              // after the text.
              const SizedBox(width: 2),
              RaftIcon(
                RaftGlyph.arrowUpRight,
                size: MediaQuery.textScalerOf(context).scale(12) * 0.857,
                color: color,
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
      weight: FontWeight.w600,
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
                      style: _relaxed(t, t.muted),
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
    final actions = row.onReviewPermissions == null
        ? action
        : Wrap(
            alignment: WrapAlignment.end,
            spacing: RaftSpace.x2,
            runSpacing: RaftSpace.x2,
            children: [
              RaftSettingsRecipeButton(
                key: ValueKey('connected-app-review-permissions-${row.id}'),
                label: 'Review permissions',
                size: RaftButtonRecipeSize.md,
                onPressed: row.onReviewPermissions,
              ),
              ?action,
            ],
          );
    final Widget body;
    if (grid) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          info,
          if (actions != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(alignment: Alignment.centerRight, child: actions),
            ),
        ],
      );
    } else if (wide) {
      body = Row(
        children: [
          Expanded(child: info),
          if (actions != null) ...[const SizedBox(width: 12), actions],
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          if (actions != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        ],
      );
    }
    final card = RaftCard.item(interactive: false, child: body);
    return grid
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 184),
            child: card,
          )
        : card;
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
    final fill = cream ? t.ui.fillMuted : t.ui.layerCard;
    final border = fill.a == 1 && t.ui.lineHairline.a < 1
        ? raftChromeBlend(t.ui.lineHairline, fill)
        : t.ui.lineHairline;
    return Container(
      padding: const EdgeInsets.all(RaftSpace.x4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: t.corner('radius.container', fallback: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftSectionEyebrow(raftText(context, title)),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: t.scale(
                RaftTypeScale.footnote,
                color: t.ui.foregroundMuted,
              ),
            ),
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
    final labelStyle = t.scale(
      RaftTypeScale.footnote,
      color: t.ui.foregroundMuted,
    );
    final callout = t.typeSlot('callout');
    final value = DefaultTextStyle.merge(
      style: t.scale(
        RaftTypeScale.callout,
        weight: FontWeight.w600,
        color: text.strong,
      ),
      textAlign: wide ? TextAlign.right : TextAlign.left,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.textScalerOf(context).scale(callout.fontSize) *
              callout.height,
        ),
        child: Align(
          alignment: wide ? Alignment.centerRight : Alignment.centerLeft,
          heightFactor: 1,
          child: child,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: first
          ? null
          : BoxDecoration(
              border: Border(top: BorderSide(color: t.ui.lineHairline)),
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
    final soft = t.ui.lineHairline;
    final summary = t.scale(
      RaftTypeScale.footnote,
      weight: FontWeight.w600,
      color: text.strong,
    );
    Widget chip(String scope) => RaftTooltip(
      message: widget.tooltips[scope] ?? scope,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.resourceScopes.contains(scope)
              ? (Color.alphaBlend(
                  t.colors['accent-soft']!.withValues(alpha: .3),
                  t.panel,
                ))
              : (t.panel),
          border: Border.all(color: t.colors['line-strong']!),
        ),
        child: Text(
          scope,
          style: RaftTypography.body(
            t,
            size: 11,
            line: 11 * 1.5,
            weight: FontWeight.w700,
            color: t.muted,
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
          Text(
            widget.description!,
            style: t.scale(RaftTypeScale.footnote, color: t.ui.foregroundMuted),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.ui.layerCard,
            border: Border.all(color: soft),
            borderRadius: t.corner('radius.container', fallback: 10),
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
                        width: 10,
                        height: summary.fontSize!,
                        child: CustomPaint(
                          painter: _DisclosureMarker(open, text.strong),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          raftText(context, 'Declared access'),
                          style: summary,
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
                      color: t.panel,
                      border: Border.all(color: soft, width: 1),
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

/// The requested or installed App permissions with an inset scope group.
class RaftAppPermissionsSummary extends StatelessWidget {
  const RaftAppPermissionsSummary({
    super.key,
    required this.columns,
    this.description,
    this.badge,
    this.loading,
  });
  final String? description;

  /// (label, values, empty copy) per column.
  final List<(String, List<String>, String)> columns;
  final RaftConnectedAppBadge? badge;

  /// The loading line replaces the section while the state reads.
  final String? loading;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (loading != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: RaftSpace.x3,
        children: [
          const RaftSeparator(),
          Text(
            loading!,
            style: t.scale(RaftTypeScale.footnote, color: t.ui.foregroundHint),
          ),
        ],
      );
    }
    final wide = raftBreakpointWidth(context) >= 640;
    final footnote = t.scale(
      RaftTypeScale.footnote,
      color: t.ui.foregroundHint,
    );
    Widget scopeRow((String, List<String>, String) scope) {
      final label = Text(
        scope.$1,
        style: footnote.copyWith(fontWeight: FontWeight.w500),
      );
      final values = scope.$2.isEmpty
          ? Text(scope.$3, style: footnote)
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in scope.$2)
                  _Badge(
                    RaftConnectedAppBadge(
                      value,
                      appearance: RaftBadgeRecipeAppearance.soft,
                    ),
                  ),
              ],
            );
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x4,
          vertical: RaftSpace.x3,
        ),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.x4,
                children: [
                  SizedBox(
                    width: 176,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: RaftSpace.half,
                      ),
                      child: label,
                    ),
                  ),
                  Expanded(child: values),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: RaftSpace.x2,
                children: [label, values],
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RaftSeparator(),
        const SizedBox(height: RaftSpace.x4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: RaftSpace.x2,
          runSpacing: RaftSpace.x2,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: RaftSpace.x2,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RaftIcon(
                    RaftGlyph.bell,
                    size: 18,
                    color: t.ui.foregroundMuted,
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: RaftSpace.x1,
                    children: [
                      RaftSectionEyebrow(raftText(context, 'App permissions')),
                      if (description case final copy?)
                        Text(
                          copy,
                          style: footnote.copyWith(color: t.ui.foregroundMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (badge != null) _Badge(badge!),
          ],
        ),
        const SizedBox(height: RaftSpace.x3),
        RaftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, scope) in columns.indexed) ...[
                if (index > 0) const RaftSeparator(),
                scopeRow(scope),
              ],
            ],
          ),
        ),
      ],
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
    final footerInset = t.desktop ? RaftSpace.x4 : RaftSpace.x5;
    final identity = Row(
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
                      style: t.scale(
                        RaftTypeScale.headline,
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
                style: t.scale(
                  RaftTypeScale.footnote,
                  color: t.ui.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RaftDialogClose(onPressed: onClose, semanticLabel: closeLabel),
      ],
    );
    return RaftDialog(
      size: RaftDialogSize.lg,
      semanticLabel: name,
      onClose: onClose,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RaftDialogHeader(title: identity, showClose: false),
          Flexible(
            child: RaftDialogBody(
              verticalPadding: RaftSpace.x4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: RaftSpace.x4,
                children: [
                  if (error != null && error!.isNotEmpty)
                    RaftConnectedAppsError(error!),
                  ...sections,
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              footerInset,
              0,
              footerInset,
              footerInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: RaftSpace.x4,
              children: [
                const RaftSeparator(),
                RaftDialogActions(children: footer),
              ],
            ),
          ),
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
    this.size = RaftButtonRecipeSize.md,
  });
  final String label;
  final VoidCallback? onPressed;
  final RaftButtonRecipeVariant variant;
  final RaftButtonRecipeSize size;
  @override
  Widget build(BuildContext context) => RaftSettingsRecipeButton(
    label: label,
    variant: variant,
    size: size,
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
    return Text(
      text,
      style: t.scale(
        small ? RaftTypeScale.footnote : RaftTypeScale.callout,
        color: t.ui.foregroundMuted,
      ),
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
            color: t.muted,
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
                    color: t.panel,
                    border: Border.all(color: t.colors['line-strong']!),
                  ),
                  child: Text(
                    g,
                    style: RaftTypography.body(
                      t,
                      size: 11,
                      line: 11 * 1.5,
                      weight: FontWeight.w700,
                      color: t.muted,
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
        color: t.colors['warning-soft'],
        border: Border(left: BorderSide(color: t.colors['warning']!, width: 4)),
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
