import 'package:flutter/widgets.dart';

/// The immediately painted surface behind a descendant component.
///
/// Only a surface that owns its actual paint should declare this scope.
/// A null colour is an explicit unknown, translucent or nonuniform surface:
/// it blocks an outer declaration rather than looking through to an ancestor.
/// This is internal paint context, not a replacement background or theme token.
class RaftSurfaceBackgroundScope extends InheritedWidget {
  const RaftSurfaceBackgroundScope({
    super.key,
    required this.color,
    required super.child,
  });

  final Color? color;

  /// Returns only the nearest declaration; absent and unknown both stay null.
  static Color? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RaftSurfaceBackgroundScope>()
      ?.color;

  @override
  bool updateShouldNotify(RaftSurfaceBackgroundScope oldWidget) =>
      color != oldWidget.color;
}
