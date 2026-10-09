import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/recipes.dart' as recipes;

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
    this.leading,
    this.actions = const [],
    this.mobile = false,
    this.variant = RaftPanelHeaderVariant.canonical,
  });
  final String title;
  final String? subtitle;
  final Widget? icon, leading;
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
    final canonical = variant == RaftPanelHeaderVariant.canonical;
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
    final subtitleStyle = canonical && !t.brutal
        ? source.meta.text(t.recipeTokens, base: RaftTypography.body(t))
        : recipe.subtitle;
    final gap = canonical && !t.brutal ? 8.0 : RaftLayoutMetrics.panelGap;
    return Container(
      key: const Key('page-header-surface'),
      height: height,
      padding: canonical && !t.brutal && mobile
          ? const EdgeInsets.only(left: 20, right: 14)
          : EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset),
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border(
          bottom: canonical && !t.brutal && mobile
              ? BorderSide(color: t.line)
              : recipe.border,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: gap)],
          if (!mobile && icon != null) ...[
            Container(
              width: RaftLayoutMetrics.panelIcon,
              height: RaftLayoutMetrics.panelIcon,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: recipe.iconBackground,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                if (canonical)
                  RaftCssText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                if (canonical &&
                    !t.brutal &&
                    subtitle != null &&
                    subtitle!.isNotEmpty)
                  const SizedBox(height: 4),
                if (subtitle != null && subtitle!.isNotEmpty)
                  canonical
                      ? RaftCssText(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        )
                      : Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
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
