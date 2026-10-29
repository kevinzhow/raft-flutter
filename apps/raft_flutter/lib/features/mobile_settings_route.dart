part of 'workspace_view.dart';

/// A live widget tree per platform route, borrowing the workspace's accepted
/// data. Historical routes keep their location, not an image of the page.
class _MobileWorkspaceRoute extends StatefulWidget {
  const _MobileWorkspaceRoute({required this.host, required this.location});
  final _WorkspaceViewState host;
  final RaftLocation location;
  @override
  State<_MobileWorkspaceRoute> createState() => _MobileWorkspaceRouteState();
}

class _MobileWorkspaceRouteState extends State<_MobileWorkspaceRoute> {
  Widget? content;

  /// Active on the previous build. The route rebuilds once when this flips
  /// so tickers and focus follow the page that is on screen.
  bool routeWasActive = false;

  WorkspaceController get source => widget.host.w;
  bool get active =>
      mobilePageIdentity(source.location) ==
      mobilePageIdentity(widget.location);
  bool get chatRoute =>
      widget.location.route == RaftRoute.channel ||
      widget.location.route == RaftRoute.dm;

  @override
  void initState() {
    super.initState();
    MobileRouteGate.follow(this, () => !active);
    MobileRouteGate.write(this, covered: !active, location: widget.location);
    source.addListener(sourceChanged);
  }

  void sourceChanged() {
    if (!mounted) return;
    final now = active;
    MobileRouteGate.write(this, covered: !now, location: widget.location);
    if (now == routeWasActive) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(_MobileWorkspaceRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    MobileRouteGate.write(this, covered: !active, location: widget.location);
  }

  @override
  void dispose() {
    source.removeListener(sourceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    final now = active;
    routeWasActive = now;
    final page = _MobileWorkspaceContent(
      controller: source,
      mobileHost: host,
      appearance: host.widget.appearance,
      onAppearance: host.widget.onAppearance,
      onLogout: host.widget.onLogout,
      notifications: host.widget.notifications,
      sharing: host.widget.sharing,
      presentation: host.presentation,
      mobileTabbar: host.mobileTabbar,
      railSide: host.railSideStore,
      onChooseServer: host.widget.onChooseServer,
      onSwitchServer: host.widget.onSwitchServer,
    );
    final Widget paced = WorkspaceHostScope.inherit(
      host.context,
      child: TickerMode(enabled: now, child: page),
    );
    final Widget shown = chatRoute
        ? ExcludeFocus(excluding: !now, child: paced)
        : paced;
    return MobileRouteGate(
      child: IgnorePointer(
        ignoring: !now,
        child: ExcludeSemantics(
          excluding: !now,
          child: RouteFrameDiagnostics.enabled
              ? RouteFrameProbe(child: shown)
              : shown,
        ),
      ),
    );
  }
}
