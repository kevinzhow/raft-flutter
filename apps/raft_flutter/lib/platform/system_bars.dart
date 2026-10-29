import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

/// Paints the themed app underneath system bars without hiding system controls.
///
/// Individual pages own their safe interactive bounds. This wrapper deliberately
/// does not consume padding or keyboard insets, so nested sheets and Scaffold
/// retain the real window metrics.
class RaftSystemBars extends StatefulWidget {
  const RaftSystemBars({super.key, required this.child});

  final Widget child;

  @override
  State<RaftSystemBars> createState() => _RaftSystemBarsState();
}

SystemUiOverlayStyle raftSystemOverlayStyle(
  Brightness background, {
  Brightness? navigationBackground,
}) {
  final icons = background == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: background,
    statusBarIconBrightness: icons,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness:
        (navigationBackground ?? background) == Brightness.dark
        ? Brightness.light
        : Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
}

/// Extends a page's actual surfaces under transparent Android system bars.
/// The page keeps ownership of safe bounds; this only paints the status bar
/// background. Nothing is painted under the navigation bar: scroll content runs
/// under it and bottom-anchored controls extend their own background (see
/// `RaftBottomInsetSurface`, which also sets the navigation icon contrast).
///
/// The status bar always shows the colour of the header directly under it:
/// top headers publish their background with `RaftStatusBarSource` and the
/// strip painted here resolves it at paint time (see `status_bar.dart` in
/// raft_ui). [statusBarFallback] is only the page colour used when no header
/// is flush with the top of the page.
class RaftSystemBarSurface extends StatelessWidget {
  const RaftSystemBarSurface({
    super.key,
    required this.statusBarFallback,
    required this.child,
  });

  final Color statusBarFallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return child;
    }
    // ds-allow: Android system-bar contrast reads the platform theme (no raft_ui equivalent).
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: raftSystemOverlayStyle(
        // ds-allow: Android system-bar icon contrast from the bar colour.
        ThemeData.estimateBrightnessForColor(statusBarFallback),
        // ds-allow: Android nav-bar icon contrast; bottom surfaces override it.
        navigationBackground: ThemeData.estimateBrightnessForColor(
          // ds-allow: Android navigation-bar contrast falls back to the scaffold.
          theme.scaffoldBackgroundColor,
        ),
      ),
      child: RaftStatusBarHost(
        fallback: statusBarFallback,
        expand: true,
        child: child,
      ),
    );
  }
}

class _RaftSystemBarsState extends State<RaftSystemBars> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // iOS also needs the explicit show-home-indicator notification, rather
      // than relying only on the view controller's default hide preference.
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ds-allow: Android system-bar contrast reads the platform theme (no raft_ui equivalent).
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: raftSystemOverlayStyle(theme.brightness),
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: widget.child,
      ),
    );
  }
}
