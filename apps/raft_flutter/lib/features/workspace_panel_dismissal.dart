part of 'workspace_view.dart';

extension _WorkspacePanelDismissal on _WorkspaceViewState {
  void escapePanel() {
    if (takeDetailFieldEscape()) return;
    if (mobileHost != null ||
        w.location.channelPage != null ||
        wide && desktopNavigation.target != null ||
        w.location.profile != null ||
        w.location.task != null ||
        w.location.legacyTask != null ||
        w.location.thread != null ||
        threadSelection.active ||
        mainSelection.active ||
        scaffold.currentState?.isDrawerOpen == true ||
        w.messageDomain.state.threadParent != null && w.section == 'chat') {
      dismissPanel(fromEscape: true);
    }
  }

  void dismissPanel({bool fromEscape = false}) {
    final host = mobileHost;
    if (host != null) {
      if (threadSelection.dismiss() || mainSelection.dismiss()) return;
      host.dismissPanel();
      return;
    }
    if (wide && taskSlotId(w.location) != null && w.location.profile != null) {
      w.closeProfile();
      return;
    }
    if (w.location.task != null || w.location.legacyTask != null) {
      if (wide) {
        w.navigation.back();
      } else {
        backMobilePage(w.navigation);
      }
      w.notifyListeners();
      return;
    }
    if (threadSelection.dismiss() || mainSelection.dismiss()) return;
    if (scaffold.currentState?.isDrawerOpen == true) {
      scaffold.currentState?.closeDrawer();
      return;
    }
    if (wide) {
      final target = desktopNavigation.target;
      final panels = DesktopNavigationPolicy.sidePanels(
        route: w.section,
        wide: wide,
        location: w.location,
        target: target?.kind,
      );
      if (panels.profile || panels.thread) {
        if (panels.profile && (!panels.thread || profileOpenedLast())) {
          w.closeProfile();
        } else {
          closeThreadPanel();
        }
        return;
      }
      if (target != null) {
        final contentSlot = w.section == 'search' || w.section == 'activity';
        if (!fromEscape || !contentSlot) closeDesktopDetail();
        return;
      }
      if (w.messageDomain.state.threadParent != null && w.section == 'chat') {
        closeThreadPanel();
        return;
      }
      if (fromEscape) return;
    }
    final previous = w.location;
    final next = wide ? w.navigation.back() : backMobilePage(w.navigation);
    pendingDesktopSelection = false;
    if (next.thread == null) w.closeThread(navigate: false);
    mobileSettingsRevision++;
    w.notifyListeners();
    if ({RaftRoute.channel, RaftRoute.dm}.contains(next.route) &&
        (w.channel?.id != next.entityId ||
            next.messageId != null && next.messageId != previous.messageId)) {
      unawaited(
        w.jumpToMessage(next.entityId!, next.messageId, navigate: false),
      );
    }
    refreshPanelDismissal();
  }

  bool profileOpenedLast() {
    final history = w.navigation;
    final thread = w.location.query('thread');
    final profile = w.location.query('profile');
    for (var index = history.index - 1; index >= 0; index--) {
      final earlier = history.entries[index];
      final keptThread = earlier.query('thread') == thread;
      final keptProfile = earlier.query('profile') == profile;
      if (keptProfile != keptThread) return keptThread;
      if (!keptProfile) break;
    }
    return true;
  }
}
