part of 'workspace_view.dart';

extension _WorkspacePanelDismissal on _WorkspaceViewState {
  Widget workspaceSideThread(bool wide, Widget child) =>
      wide && !RaftInteraction.of(context).touch
      ? desktopThreadFocus(child)
      : child;

  void escapePanel() {
    if (takeDetailFieldEscape()) return;
    if (ChannelSideArea.restoreForWorkspace(this)) return;
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
      if (fromEscape && takeChannelSideEscape(panels)) return;
      if (panels.profile || panels.thread && (fromEscape || target != null)) {
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
      if (w.messageDomain.state.threadParent != null &&
          w.location.thread == null &&
          w.section == 'chat') {
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

  /// Escape on the panes beside a conversation, where that area owns the ones
  /// the person can see ([ChannelSideArea.stackForWorkspace]). It acts on a
  /// pane on screen and on no other: a profile or thread waiting behind another
  /// pane is not on screen, so closing it would take away something the person
  /// never pressed Escape on while the pane they did see stayed put. Where no
  /// pane on screen has an Escape of its own, Escape stops there rather than
  /// reaching past them.
  ///
  /// False where the pane the person can see is none of this area's: then the
  /// rest of [dismissPanel] decides as before.
  bool takeChannelSideEscape(({bool thread, bool profile}) panels) {
    if (ChannelSideCards.conversation(w) == null) return false;
    final stack = ChannelSideArea.stackForWorkspace(this);
    if (stack == null) return false;
    // A profile and a thread together are the adaptive workspace's own pair
    // (it lays the profile over the thread or beside it, outside this area),
    // and a profile this area does not host is not under its panes: both keep
    // the location-driven rule below.
    if (panels.profile &&
        (panels.thread || !stack.open.contains(ChannelSideSection.profile))) {
      return false;
    }
    if (w.section != 'chat' && panels.thread) return false;
    // Covering, the whole conversation column is behind the pane on top: the
    // chat, a folded thread and every pane waiting under it. Beside the chat,
    // only a pane in this area's stack is this area's to name.
    final inStack =
        panels.profile ||
        panels.thread && stack.open.contains(ChannelSideSection.thread);
    if (!stack.covering && !inStack) return false;
    // The panes on screen, newest first: the first that closes on Escape
    // closes (docs/close-affordances.md: the profile, the thread, Details and
    // the Artifact). The Tasks and Files cards have no Escape (Web
    // ChannelSideCard closes by its X or Back only), so Escape passes over a
    // card to a pane beside it, but never to one waiting behind it: those are
    // not in [OpenChannelSideStack.shown].
    final newestFirst = [...stack.shown]
      ..sort(
        (a, b) => (stack.openedAt[b] ?? 0).compareTo(stack.openedAt[a] ?? 0),
      );
    for (final section in newestFirst) {
      switch (section) {
        case ChannelSideSection.tasks:
        case ChannelSideSection.files:
          continue;
        case ChannelSideSection.profile:
        case ChannelSideSection.context:
        case ChannelSideSection.thread:
        case ChannelSideSection.details:
        case ChannelSideSection.artifact:
          closeChannelSideSection(w, section);
          pendingDesktopSelection = false;
          refreshPanelDismissal();
          return true;
      }
    }
    return true;
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
