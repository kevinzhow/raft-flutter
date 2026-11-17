// Source: packages/web/src/features/thread/ThreadsInbox.tsx (counts line) and
// packages/web/src/hooks/useSettledValue.ts at v1.24.0.
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/activity_object_rows.dart';

/// The header's counts, kept as Web keeps them (`useSettledValue`): they change
/// only when a page has settled, so a refilter keeps the last settled numbers
/// until the new page lands, and before any page has settled the line is
/// [known] false (it keeps its height but shows nothing).
///
/// Both numbers include object rows: `active` is `totalCount + objectCount`,
/// `unread` is `totalUnreadCount` plus the object unread of the filter. Before
/// the first page, `unread` is the filter-independent unread hint.
class ActivityCountsLine {
  int _active = 0, _unread = 0;
  bool _started = false, _known = false;

  bool get known => _known;
  int get active => _active;
  int get unread => _unread;

  /// Feeds the line with what the Activity state holds now. [loaded] is true
  /// while the shown page answers the shown filter.
  void settle({
    required bool loaded,
    required int totalCount,
    required ActivityObjectCounts objects,
    required int totalUnread,
    required String filter,
    required int activeUnreadHint,
  }) {
    final active = totalCount + objects.objectCount;
    final unread = totalUnread + objects.unreadForFilter(filter);
    if (!_started) {
      _started = true;
      _active = active;
      _unread = loaded ? unread : activeUnreadHint + objects.objectUnreadCount;
    }
    if (loaded) {
      _active = active;
      _unread = unread;
      _known = true;
    }
  }

  /// Back to nothing settled (another server or account).
  void reset() {
    _active = _unread = 0;
    _started = _known = false;
  }
}

/// `thread.header.subtitle` as rich text: the numbers in the mono face.
List<InlineSpan> activityCountsSpans(
  BuildContext context,
  ActivityCountsLine line,
) => raftRichText(
  context,
  '<mono>{activeCount}</mono> in progress · <mono>{unreadCount}</mono> unread',
  {
    'mono': (inner) => TextSpan(
      text: inner,
      // ds-allow: only the face changes (Web `font-mono`); size and colour come from the header's own text
      style: TextStyle(fontFamily: RaftTokens.of(context).monoFont),
    ),
  },
  values: {'activeCount': line.active, 'unreadCount': line.unread},
);

/// The counts line as a widget: before the first page it keeps its line but
/// is invisible and out of semantics (Web `inbox-loading-counts`).
Widget activityCountsLine(
  BuildContext context,
  ActivityCountsLine line, {
  TextStyle? style,
}) {
  final text = Text.rich(
    TextSpan(children: activityCountsSpans(context, line)),
    key: const ValueKey('activity-counts-line'),
    style: style,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
  if (line.known) return text;
  return ExcludeSemantics(
    child: Opacity(
      opacity: 0,
      key: const ValueKey('activity-counts-loading'),
      child: text,
    ),
  );
}

/// The counts line as the String the existing headers take (no mono face
/// there): the wording of `thread.header.subtitle`, or a no-break space while
/// nothing has settled, which keeps the line's height.
String activityCountsString(BuildContext context, ActivityCountsLine line) =>
    line.known
    ? raftFormat(
        context,
        '{activeCount} in progress · {unreadCount} unread',
        {'activeCount': line.active, 'unreadCount': line.unread},
      )
    : ' ';
