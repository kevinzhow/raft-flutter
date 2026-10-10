import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// The page keeps ownership of safe bounds; this only paints their background.
class RaftSystemBarSurface extends StatelessWidget {
  const RaftSystemBarSurface({
    super.key,
    required this.statusBarBackground,
    required this.child,
    this.navigationBarBackground,
  });

  final Color statusBarBackground;
  final Color? navigationBarBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return child;
    final padding = MediaQuery.paddingOf(context);
    // ds-allow: Android system-bar contrast reads the platform theme (no raft_ui equivalent).
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: raftSystemOverlayStyle(
        // ds-allow: Android system-bar icon contrast from the bar colour.
        ThemeData.estimateBrightnessForColor(statusBarBackground),
        // ds-allow: Android system-bar icon contrast from the bar colour.
        navigationBackground: ThemeData.estimateBrightnessForColor(
          navigationBarBackground ?? theme.scaffoldBackgroundColor,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (padding.top > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: padding.top,
              child: IgnorePointer(
                child: ColoredBox(color: statusBarBackground),
              ),
            ),
          if (padding.bottom > 0 && navigationBarBackground != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: padding.bottom,
              child: IgnorePointer(
                child: ColoredBox(color: navigationBarBackground!),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _RaftSystemBarsState extends State<RaftSystemBars> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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
