// What the Tasks page is showing, as the person set it: the tab, the sort,
// list or board, the search and the filters. Web keeps these in the address
// (`?tab=`, `?sort=`, `?view=`, `?q=`, `?channel=`...); the app has no address
// bar, so the page holds them. The tab (per server and person) and the view
// are also remembered on the device and win over the defaults, 我的 and the
// list.
//
// Source: Web v1.24 components/task/tasksPage/useTasksPageParams.ts.
import 'package:flutter/foundation.dart';

import '../../data/device_preferences.dart';
import '../../data/task_view_mode_preference.dart';
import 'tasks_page_model.dart';

/// The page's tab for a server and a person, as last chosen.
String _tabKey(String? serverId, String? userId) =>
    'raft.tasks.page.tab:${serverId ?? ''}:${userId ?? ''}';

TasksPageTab? readStoredTasksPageTab(String? serverId, String? userId) {
  try {
    return parseTasksPageTab(
      DevicePreferences.current?.getString(_tabKey(serverId, userId)),
    );
  } catch (_) {
    return null;
  }
}

void _writeStoredTab(String? serverId, String? userId, TasksPageTab tab) {
  try {
    DevicePreferences.current?.setString(_tabKey(serverId, userId), tab.name);
  } catch (_) {
    /* optional local storage */
  }
}

class TasksPageParams extends ChangeNotifier {
  TasksPageParams({
    required this.serverId,
    required this.userId,
    TasksPageTab? tab,
    TasksPageView? view,
  }) : _tab =
           tab ?? readStoredTasksPageTab(serverId, userId) ?? TasksPageTab.mine,
       _view =
           view ??
           (TaskViewModePreference.read() == 'board'
               ? TasksPageView.board
               : TasksPageView.list);

  final String? serverId, userId;

  TasksPageTab _tab;
  ServerTaskSort _sort = ServerTaskSort.activity;
  TasksPageView _view;
  PageFilters _filters = PageFilters.none;
  String _rawQuery = '';

  TasksPageTab get tab => _tab;
  ServerTaskSort get sort => _sort;
  TasksPageView get view => _view;
  PageFilters get filters => _filters;

  /// The search as typed (untrimmed), for the field.
  String get rawQuery => _rawQuery;

  /// What the page shows changes with this: the selection and the 你发起的
  /// done-since instant belong to it.
  String get scope => [
    _tab.name,
    _view.name,
    _sort.wire,
    _filters.channelIds.join(','),
    _filters.statuses.join(','),
    _filters.creators.join(','),
    _filters.assignees.join(','),
    _filters.query,
  ].join('|');

  void setTab(TasksPageTab next) {
    _writeStoredTab(serverId, userId, next);
    if (next == _tab) return;
    _tab = next;
    notifyListeners();
  }

  void setSort(ServerTaskSort next) {
    if (next == _sort) return;
    _sort = next;
    notifyListeners();
  }

  void setView(TasksPageView next) {
    TaskViewModePreference.write(next.name);
    if (next == _view) return;
    _view = next;
    notifyListeners();
  }

  void _setFilters(PageFilters next) {
    if (next == _filters) return;
    _filters = next;
    notifyListeners();
  }

  void setChannelIds(List<String> values) =>
      _setFilters(_filters.copyWith(channelIds: values));

  void setStatuses(List<String> values) => _setFilters(
    _filters.copyWith(
      statuses: [
        for (final s in values.toSet())
          if (parseBoardStatus(s) != null) s,
      ],
    ),
  );

  void setCreators(List<String> values) =>
      _setFilters(_filters.copyWith(creators: values));

  void setAssignees(List<String> values) =>
      _setFilters(_filters.copyWith(assignees: values));

  /// The search, as typed; the server takes [taskSearchMaxLength] of it.
  void setQuery(String value) {
    final raw = value.length > taskSearchMaxLength
        ? value.substring(0, taskSearchMaxLength)
        : value;
    if (raw == _rawQuery) return;
    _rawQuery = raw;
    _filters = _filters.copyWith(query: raw.trim());
    notifyListeners();
  }

  /// 清除筛选: every toolbar filter; [withSearch] the search too.
  void clearFilters({bool withSearch = false}) {
    if (withSearch) _rawQuery = '';
    final next = PageFilters(query: withSearch ? '' : _filters.query);
    if (next == _filters && !withSearch) return;
    _filters = next;
    notifyListeners();
  }
}

/// The cutoff and toolbar scope of a Tasks page within a workspace session.
class TasksPageVisitState {
  TasksPageVisitState(this.params, this.doneSince);

  final TasksPageParams params;
  String doneSince;
  bool visited = false;
}
