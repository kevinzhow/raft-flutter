import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as recipes;

import '../platform/system_bars.dart';

/// Vertical padding floor once a shell header grows. The narrow Web panel
/// header uses this same 8px floor.
const _scaledHeaderPadding = RaftMetrics.fieldVerticalPadding;

/// The product panel header shared by the source's individual page columns.
/// Platform safe-area insets are supplied by the host, outside this rectangle.
double raftPageHeaderHeight(BuildContext context) =>
    RaftLayoutMetrics.shellHeaderHeight(
      RaftTokens.of(context),
      MediaQuery.sizeOf(context).height,
    );

class RaftPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const RaftPageHeader({
    super.key,
    required this.title,
    required this.height,
    this.subtitle,
    this.icon,
    this.onBack,
    this.backKey,
    this.backLabel = 'Back',
    this.actions = const [],
    this.mobile = false,
    this.variant = RaftPanelHeaderVariant.canonical,
    this.leftInset,
    this.bottomRule = false,
    this.iconBackground,
    this.background,
  });

  /// Elegant desktop only: the host's own left padding (ActivityInboxPanel
  /// `pl-3`) and the `border-b` rule it adds under the header.
  final double? leftInset;
  final bool bottomRule;

  /// Callsite `iconBg` (SavedPanel `bg-primary-soft`); null keeps the recipe fill.
  final Color? iconBackground;

  /// The containing page surface; null preserves the header recipe.
  final Color? background;
  final String title;
  final String? subtitle;
  final Widget? icon;

  /// Phone Back (AppPanelHeader `onMobileBack`): Web's boxed PanelAction.
  final VoidCallback? onBack;
  final Key? backKey;
  final String backLabel;
  final List<Widget> actions;
  final double height;
  final bool mobile;
  final RaftPanelHeaderVariant variant;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftPanelHeaderRecipe(
      t,
      viewportHeight: MediaQuery.sizeOf(context).height,
      mobile: mobile,
      variant: variant,
    );
    // v1.21.23 page heads (Tasks, Saved, Activity, Search, ...) carry no icon
    // tile; the pre-theme looks keep it (pageHeader.icon).
    final tile = t.option('pageHeader.icon', or: 'none') == 'tile';
    if (!tile && !mobile && variant == RaftPanelHeaderVariant.tasks) {
      return RaftPanelHeaderBar(
        key: const Key('page-header-surface'),
        title: title,
        background: background,
        subtitle: subtitle,
        leftPadding: leftInset,
        bottomRule: bottomRule,
        actions: actions,
      );
    }
    if (mobile && variant == RaftPanelHeaderVariant.canonical) {
      // Below md Web renders the same AppPanelHeader grid: boxed Back, title
      // (+ meta), actions. The icon tile is `hidden md:flex` on these
      // non-identity surfaces.
      return RaftPanelHeaderBar(
        title: title,
        background: background,
        subtitle: subtitle,
        onBack: onBack,
        backKey: backKey,
        backTooltip: backLabel,
        actions: actions,
      );
    }
    if (mobile) {
      // TasksPanel is a tab-root header with its own Web markup (no back
      // control): the Sidebar navbar bar at `px-5`, h2 `font-bold text-base
      // leading-tight` over a `font-mono text-xs text-foreground-muted` count.
      final root = RaftMobileRootHeaderRecipe(
        t,
        viewportHeight: MediaQuery.sizeOf(context).height,
        inset: RaftLayoutMetrics.panelInset,
      );
      return RaftMobilePageHeader(
        background: t.colors['layer-section-header-mobile'],
        border: root.border,
        headerHeight: root.height,
        inset: root.inset,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.option('listGroup.frame', or: 'framed') == 'plain'
                  ? t.scale(
                      RaftTypeScale.headline,
                      color: t.colors['foreground-on-frame'],
                    )
                  : RaftTypography.heading(t, size: 16, line: 20),
            ),
            if (subtitle?.isNotEmpty == true)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.option('listGroup.frame', or: 'framed') == 'plain'
                    ? t.scale(
                        RaftTypeScale.caption,
                        weight: FontWeight.w500,
                        color: t.colors['foreground-on-frame-muted'],
                      )
                    : RaftTypography.mono(t, color: t.muted),
              ),
          ],
        ),
        actions: actions,
      );
    }
    final canonical = variant == RaftPanelHeaderVariant.canonical;
    if (canonical) {
      // Elegant desktop PanelHeader: the 36px `fill-muted` icon tile and the
      // title with its meta inline (the same bar the Agent / Human panels use).
      return RaftPanelHeaderBar(
        key: const Key('page-header-surface'),
        title: title,
        background: background,
        subtitle: subtitle,
        leftPadding: leftInset,
        bottomRule: bottomRule,
        iconSlot: icon == null || !tile
            ? null
            : RaftPanelHeaderMutedTile(icon: icon!),
        actions: actions,
      );
    }
    final source = recipes.RaftPanelHeaderRecipe.resolve(
      theme: t.recipeTheme,
      states: recipes.RaftRecipeStates(
        {if (t.dark) recipes.RaftRecipeStates.dark},
        MediaQuery.sizeOf(context).width,
        MediaQuery.sizeOf(context).height,
      ),
      tokens: t.recipeTokens,
    );
    final titleStyle = canonical
        ? source.title.text(t.recipeTokens, base: RaftTypography.body(t))
        : recipe.title;
    final subtitleStyle = canonical
        ? source.meta.text(t.recipeTokens, base: RaftTypography.body(t))
        : recipe.subtitle;
    final gap = canonical
        ? RaftResourceMetrics.elegantHeaderGap
        : RaftLayoutMetrics.panelGap;
    // Above the default text size the header height is a minimum and the
    // title / subtitle wrap, the same way the narrow Web panel header grows.
    final grows = RaftScaled.grows(context);
    final lines = grows ? null : 1;
    final clip = grows ? TextOverflow.clip : TextOverflow.ellipsis;
    final restingPadding = canonical && mobile
        ? RaftResourceMetrics.elegantMobileHeaderInset
        : EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset);
    final header = Container(
      key: const Key('page-header-surface'),
      height: grows ? null : height,
      constraints: grows ? BoxConstraints(minHeight: height) : null,
      padding: grows
          ? restingPadding.copyWith(
              top: restingPadding.top < _scaledHeaderPadding
                  ? _scaledHeaderPadding
                  : restingPadding.top,
              bottom: restingPadding.bottom < _scaledHeaderPadding
                  ? _scaledHeaderPadding
                  : restingPadding.bottom,
            )
          : restingPadding,
      decoration: BoxDecoration(
        color: background ?? recipe.background,
        border: Border(
          bottom: canonical && mobile
              ? BorderSide(color: t.line)
              : recipe.border,
        ),
      ),
      child: Row(
        children: [
          if (!mobile && icon != null) ...[
            Container(
              width: RaftLayoutMetrics.panelIcon,
              height: RaftLayoutMetrics.panelIcon,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBackground ?? recipe.iconBackground,
                border: Border.all(color: t.line, width: t.border),
                borderRadius: recipe.iconRadius,
              ),
              child: IconTheme.merge(
                data: IconThemeData(size: 18, color: t.ink),
                child: icon!,
              ),
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!canonical)
                  Text(
                    title,
                    maxLines: lines,
                    overflow: clip,
                    style: titleStyle,
                  ),
                if (canonical)
                  RaftCssText(
                    title,
                    maxLines: lines,
                    overflow: clip,
                    style: titleStyle,
                  ),
                if (canonical && subtitle != null && subtitle!.isNotEmpty)
                  const SizedBox(
                    height: RaftResourceMetrics.elegantHeaderMetaGap,
                  ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  canonical
                      ? RaftCssText(
                          subtitle,
                          maxLines: lines,
                          overflow: clip,
                          style: subtitleStyle,
                        )
                      : Text(
                          subtitle!,
                          maxLines: lines,
                          overflow: clip,
                          style: subtitleStyle,
                        ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
    return RaftStatusBarSource(color: recipe.background, child: header);
  }
}

/// Page body limits from the source's settings forms, independent of viewport.
class RaftSettingsSection extends StatelessWidget {
  const RaftSettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: RaftTypography.heading(t, size: 14, line: 21)),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: RaftTypography.body(t, size: 12, line: 18, color: t.muted),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// Standalone routes wear the same Web PanelHeader as the workspace panels
/// below md (no Web counterpart: these pages are native-only).
PreferredSizeWidget raftPageAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const [],
}) {
  if (MediaQuery.sizeOf(context).width >= RaftLayoutMetrics.desktopBreakpoint) {
    // ds-allow: Native Scaffold AppBar preserves desktop sizing and automatic route Back.
    return AppBar(title: Text(title), actions: actions);
  }
  final navigator = Navigator.of(context);
  return PreferredSize(
    preferredSize: Size.fromHeight(raftPageHeaderHeight(context)),
    child: RaftSystemBarSurface(
      statusBarFallback: RaftTokens.of(context).panel,
      // ds-allow: Native Scaffold appBar ink host and safe-area background; raft_ui owns the header content.
      child: Material(
        color: RaftTokens.of(context).panel,
        child: SafeArea(
          bottom: false,
          child: RaftPanelHeaderBar(
            title: title,
            onBack: navigator.canPop() ? () => navigator.maybePop() : null,
            actions: actions,
          ),
        ),
      ),
    ),
  );
}
