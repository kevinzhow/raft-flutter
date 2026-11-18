import 'tasks_page_model.dart';
import 'tasks_page_params.dart';
import 'tasks_page_store.dart';

/// Web reopens Tasks with a new recent-done cutoff. Keep the previous cutoff
/// on screen until the new counts and any visible dated lanes are ready.
class TasksPageRecentHistory {
  TasksPageRecentHistory(this.store, this.visit) {
    if (visit.visited) {
      final next = store.newDoneSince();
      if (next != visit.doneSince) _refreshing = next;
    }
    visit.visited = true;
  }

  final TasksPageStore store;
  final TasksPageVisitState visit;

  String? _refreshing;
  bool get refreshing => _refreshing != null;
  TasksPageParams get _params => visit.params;

  TasksCountsPlan _planAt(String cutoff) =>
      TasksCountsPlan(_params.tab, _params.view, _params.filters, cutoff);

  TasksCountsPlan get plan => _planAt(visit.doneSince);

  void watch({bool? shown}) => store.watchCounts(
    _planAt(_refreshing ?? visit.doneSince).wanted,
    shown: shown,
  );

  void scopeChanged() {
    final previous = visit.doneSince;
    final abandoned = _refreshing;
    _refreshing = null;
    visit.doneSince = store.newDoneSince();
    watch();
    if (previous != visit.doneSince) store.evictCompletedSince(previous);
    if (abandoned != null && abandoned != visit.doneSince) {
      store.evictCompletedSince(abandoned);
    }
  }

  void _dropRefresh() {
    final cutoff = _refreshing;
    if (cutoff == null) return;
    _refreshing = null;
    store.evictCompletedSince(cutoff);
  }

  void hide() {
    store.setShown(false);
    _dropRefresh();
  }

  String? settle() {
    final cutoff = _refreshing;
    if (cutoff == null || !store.shown) return null;
    final next = _planAt(cutoff);
    final entries = [
      for (final filters in next.wanted.toSet())
        if (filters.completedSince != null) store.counts[filters.key],
    ];
    if (entries.any((entry) => entry?.failed == true)) {
      _dropRefresh();
      watch();
      return null;
    }
    if (entries.any((entry) => entry?.data == null)) return null;

    if (_params.tab == TasksPageTab.mine &&
        _params.view == TasksPageView.list) {
      final lanes = mineSectionLanes(
        MineSection.started,
        _params.filters,
        _params.sort,
        cutoff,
      );
      final count = store.countsOf(next).sections?[MineSection.started];
      if (count != 0 &&
          lanes.any((lane) => lane.filters.completedSince != null)) {
        final view = store.laneView(lanes);
        if (view.failed) {
          _dropRefresh();
          watch();
          return null;
        }
        if (!view.loaded) {
          store.settleLanes(lanes, count: count);
          return null;
        }
      }
    }

    final previous = visit.doneSince;
    visit.doneSince = cutoff;
    _refreshing = null;
    return previous;
  }
}
