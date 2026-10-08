import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

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
    return Container(
      key: const Key('page-header-surface'),
      height: height,
      padding: EdgeInsets.symmetric(horizontal: RaftLayoutMetrics.panelInset),
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border(bottom: recipe.border),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: RaftLayoutMetrics.panelGap),
          ],
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
            const SizedBox(width: RaftLayoutMetrics.panelGap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: recipe.title,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: recipe.subtitle,
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
