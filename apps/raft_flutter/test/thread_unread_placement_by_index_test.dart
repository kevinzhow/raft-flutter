import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/thread_unread_jump.dart';

void main() {
  test(
    'locates an unmounted parent by loaded order before using its clock',
    () {
      final targets = placeJumpTargets(
        [
          {
            'parentMessageId': 'older-in-list',
            'parentMessageCreatedAt': '2026-11-19T18:00:00Z',
          },
        ],
        const {'visible-row': RowPlacement.visible},
        const LoadedRange(hasNewer: true),
        viewTop: DateTime.utc(2026, 11, 19, 16),
        viewBottom: DateTime.utc(2026, 11, 19, 17),
        loadedIds: ['older-in-list', 'visible-row'],
        visibleIds: ['visible-row'],
      );
      expect(targets.earliestAbove?['parentMessageId'], 'older-in-list');
      expect(targets.nearestBelow, isNull);
    },
  );
}
