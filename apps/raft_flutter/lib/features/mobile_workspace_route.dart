part of 'workspace_view.dart';

/// Data notifications reach the live page's controller. Only history or
/// authority changes need to reconcile the Navigator's page configuration.
class _MobileNavigationSelection extends ChangeNotifier {
  _MobileNavigationSelection(this.host) : source = host.w {
    inputs = read();
    source.addListener(changed);
  }
  final _WorkspaceViewState host;
  final WorkspaceController source;
  late Object inputs;

  Object read() {
    host.updateChannelAuthority();
    return (
      host.desktopAuthority,
      source.location,
      source.navigation.revision,
      source.navigation.taskRevision,
      source.navigation.index,
      host.mobileTabIds.join(','),
    );
  }

  void changed() {
    final next = read();
    if (next == inputs) return;
    inputs = next;
    notifyListeners();
  }

  @override
  void dispose() {
    source.removeListener(changed);
    super.dispose();
  }
}

class _MobileWorkspaceContent extends WorkspaceView {
  const _MobileWorkspaceContent({
    required super.controller,
    required super.appearance,
    required super.onAppearance,
    required super.onLogout,
    required super.mobileHost,
    super.notifications,
    super.sharing,
    super.presentation,
    super.mobileTabbar,
    super.railSide,
    super.onChooseServer,
    super.onSwitchServer,
  }) : super(mobileRoutePage: true);
}
