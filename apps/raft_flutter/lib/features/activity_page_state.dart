import 'package:flutter/foundation.dart';

import '../data/activity_object_rows.dart';
import 'activity_counts_line.dart';
import 'activity_scope_reload.dart';
import 'activity_shown_rows.dart';
import 'activity_swipe_actions.dart';
import 'activity_undo.dart';

/// What one mounted Activity list keeps beside its rows. Held outside the
/// State class (an [Expando] on it) so the resource page's field count does
/// not grow with each Activity facet.
class ActivityPageState {
  ActivityPageState._();
  static final _owners = Expando<ActivityPageState>();
  static ActivityPageState of(Object owner) =>
      _owners[owner] ??= ActivityPageState._();

  /// The header's settled counts (Web `useSettledValue`).
  final counts = ActivityCountsLine();

  /// The object (Artifact) counts of the accepted inbox window.
  ActivityObjectCounts objects = ActivityObjectCounts.none;

  /// Pinned / Saved reload triggers.
  final reload = ActivityScopeReload();

  /// 503 `rw_unconfigured`: Activity is unavailable, not failed.
  bool unavailable = false;

  /// The row open under a swipe, and the Done / Unfollow / Mute waiting out
  /// their Undo.
  final open = ActivitySwipeOpen();
  final shown = ActivityShownRows();
  ActivityUndo? undo;

  /// Ends the Activity visit / the phone re-tap registration on dispose.
  VoidCallback? leaveVisit, unregisterRetap;
}

/// What one mounted Saved page keeps beside its rows (held outside the State
/// class for the same reason as [ActivityPageState]).
class SavedPageState {
  SavedPageState._();
  static final _owners = Expando<SavedPageState>();
  static SavedPageState of(Object owner) => _owners[owner] ??= SavedPageState._();

  /// Saved rows behind the plan's history window (`historyHidden.count` of the
  /// first page); the page says how many in a banner.
  int hiddenCount = 0;
  bool refreshing = false;
  int loadFailures = 0;
}
