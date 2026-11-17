/// Ids of the mobile bottom-bar tabs. They are the `RaftMobileNavItem` ids the
/// bar has always used (`chat` is Home).
abstract final class MobileTabs {
  static const home = 'chat',
      tasks = 'tasks',
      members = 'members',
      computers = 'computers',
      activity = 'activity',
      search = 'search',
      settings = 'settings';

  /// The phone bar (Web v1.24 MainLayout.tsx MobileTabBar): Home, Activity,
  /// Tasks, Search. The server tab always closes the bar. It is fixed: there
  /// is no per-device choice.
  static const bar = [home, activity, tasks, search];
}
