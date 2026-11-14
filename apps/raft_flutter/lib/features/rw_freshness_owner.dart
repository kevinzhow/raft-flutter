import '../data/rw_freshness.dart';
import '../data/workspace_controller.dart';

final _bound = Expando<RwFreshnessStore>();

/// The RisingWave freshness of [w]'s client, with [w]'s own re-reads (Web
/// rwStaleCounts `refetch`) and foreground state bound while [w] lives.
RwFreshnessStore rwFreshnessOf(WorkspaceController w) => _bound[w] ??= () {
  final store = RwFreshnessStore.acquire(w.client);
  Future<void> inbox() async {
    // Not loaded: Activity was never opened, and opening it loads it.
    final store = w.activityUnreadIfBound;
    if (store != null && store.hasAcceptedWindow) await store.refresh();
  }

  final refetch = <RwSurface, Future<void> Function()>{
    RwSurface.unread: w.refreshUnread,
    RwSurface.followed: w.followedThreads.refresh,
    RwSurface.inbox: inbox,
  };
  refetch.forEach(store.register);
  store.visible = () => w.foreground;
  // A return to the foreground reads what is out of date at once.
  void resumed() {
    if (w.foregroundChanges.value) store.nudge();
  }

  w.foregroundChanges.addListener(resumed);
  w.services.disposeWithSession(() {
    w.foregroundChanges.removeListener(resumed);
    refetch.forEach(store.unregister);
    store.release();
  });
  return store;
}();
