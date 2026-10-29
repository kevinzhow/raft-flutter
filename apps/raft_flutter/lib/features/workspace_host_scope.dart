import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

/// Host configuration shared by the workspace and the pages it opens.
/// Production defaults to the compiled target; browser previews override it.
class WorkspaceHostScope extends InheritedWidget {
  const WorkspaceHostScope({
    super.key,
    required this.browser,
    required super.child,
  });

  /// Carries the launching workspace's host through a Navigator route boundary.
  WorkspaceHostScope.inherit(
    BuildContext source, {
    super.key,
    required super.child,
  }) : browser = browserOf(source);

  final bool browser;

  static bool browserOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkspaceHostScope>()
          ?.browser ??
      kIsWeb;

  static bool showsTopBar(BuildContext context) => raftShowsWorkspaceTopBar(
    tokens: RaftTokens.of(context),
    width: MediaQuery.sizeOf(context).width,
    nativeWindowChrome: nativeDesktopOf(context),
  );

  static bool nativeDesktopOf(BuildContext context) =>
      !browserOf(context) &&
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };

  /// Native phone Home uses edge-to-edge chrome even on a wide foldable.
  static bool nativePhoneOf(BuildContext context) =>
      !browserOf(context) &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool navigationOnRight(
    BuildContext context, {
    required bool followsSide,
    required RaftRailSide railSide,
    required double columnWidth,
  }) =>
      !RaftAdaptiveWorkspace.compactOf(context) &&
      RaftWindowClass.desktopNavigationOnRight(
        MediaQuery.sizeOf(context),
        followsSide: followsSide,
        railSide: railSide,
        textDirection: Directionality.of(context),
        columnWidth: columnWidth,
        displayFeatures: () => MediaQuery.displayFeaturesOf(context),
      );

  @override
  bool updateShouldNotify(WorkspaceHostScope oldWidget) =>
      browser != oldWidget.browser;
}
