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

SystemUiOverlayStyle raftSystemOverlayStyle(Brightness background) {
  final icons = background == Brightness.dark
      ? Brightness.light
      : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: background,
    statusBarIconBrightness: icons,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );
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
