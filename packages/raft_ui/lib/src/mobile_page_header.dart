import 'raft/button.dart';

import 'package:flutter/material.dart';

import 'status_bar.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'localization.dart';

/// Shared single-column navigation geometry. The host owns the system inset.
class RaftMobilePageHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const RaftMobilePageHeader({
    super.key,
    required this.title,
    this.leading,
    this.onBack,
    this.backKey,
    this.backLabel = 'Back',
    this.actions = const [],
    this.background,
    this.border,
    this.headerHeight,
    this.inset = 16,
  });

  final Widget title;
  final Widget? leading;
  final VoidCallback? onBack;
  final Key? backKey;
  final String backLabel;
  final List<Widget> actions;
  final Color? background;
  final BorderSide? border;

  /// Overrides the 56px platform height (Web tab roots use the shell header
  /// height: 62 Brutal / 56 Elegant / 48 on short viewports).
  final double? headerHeight;

  /// Horizontal text inset: 16 (Sidebar mobile navbar `px-4`), 20 for the
  /// TasksPanel header (`px-5`).
  final double inset;

  static const height = 56.0;
  static const actionExtent = 48.0;

  /// Web panelHeader bottom edge: brutal `border-b-2 border-black`; elegant
  /// keeps the 1px muted divider the desktop header draws.
  static BorderSide defaultBorder(RaftTokens t) =>
      BorderSide(color: t.colors['line-muted']!, width: 1);

  @override
  Size get preferredSize => Size.fromHeight(headerHeight ?? height);

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftStatusBarSource(
      color: background ?? t.panel,
      child: Container(
        // The header height is a minimum above the default text size, so a
        // large title grows the bar instead of being clipped by it.
        height: RaftScaled.grows(context) ? null : headerHeight ?? height,
        constraints: RaftScaled.grows(context)
            ? BoxConstraints(minHeight: headerHeight ?? height)
            : null,
        padding: EdgeInsets.symmetric(horizontal: inset - 8),
        decoration: BoxDecoration(
          color: background ?? t.panel,
          border: Border(bottom: border ?? defaultBorder(t)),
        ),
        child: Row(
          children: [
            if (onBack != null || leading != null) ...[
              SizedBox.square(
                dimension: actionExtent,
                child: onBack != null
                    ? RaftMobileBackButton(
                        key: backKey,
                        onPressed: onBack,
                        tooltip: backLabel,
                      )
                    : Center(child: leading),
              ),
              const SizedBox(width: 8),
            ] else
              const SizedBox(width: 8),
            Expanded(child: Semantics(header: true, child: title)),
            for (final action in actions)
              action is RaftWideHeaderAction
                  // As wide as its content (none when it has none); the
                  // row's height is the square actions' height.
                  ? SizedBox(
                      height: actionExtent,
                      child: Center(child: action),
                    )
                  : SizedBox.square(
                      dimension: actionExtent,
                      child: Center(child: action),
                    ),
          ],
        ),
      ),
    );
  }
}

/// A header action that is as wide as its content instead of a square slot
/// (the working-agents summary: faces and a count). It takes no room while
/// [child] draws nothing.
class RaftWideHeaderAction extends StatelessWidget {
  const RaftWideHeaderAction({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

/// A platform back glyph in the same 48px slot on every mobile page.
class RaftMobileBackButton extends StatelessWidget {
  const RaftMobileBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => RaftButton.iconAction(
    onPressed: onPressed,
    tooltip: raftText(context, tooltip),
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    padding: EdgeInsets.zero,
    icon: const BackButtonIcon(),
  );
}
