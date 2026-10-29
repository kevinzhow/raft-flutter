import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/channel_activity_scope.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/features/resource_filters.dart';

void main() {
  test('DM scope composes the mounted inbox search/channel/sort contract', () {
    final filters = ResourceFilters()
      ..channelId = 'peer'
      ..direction = 'asc';
    final dm = filters.list('  search text  ', activityView: 'dms', offset: 30);
    expect(dm, {
      'limit': 30,
      'offset': 30,
      'sort': 'asc',
      'q': 'search text',
      'channelId': 'peer',
      'filter': 'all',
      'scope': 'dms',
    });
    final all = filters.list('search text', activityView: 'all');
    expect(all.containsKey('scope'), isFalse);
    expect(
      ResourceFilters.viewKey('/channels/inbox', dm),
      isNot(ResourceFilters.viewKey('/channels/inbox', all)),
    );
    expect(const ChannelActivityScope('dms').globalInbox, isFalse);
  });

  test('Saved and Done retain their independent mounted endpoints', () {
    for (final view in ['saved', 'done', 'unfollowed']) {
      final scope = ChannelActivityScope(view);
      expect(scope.parameters({'sort': 'desc'}), {'sort': 'desc'});
      expect(
        scope.path,
        '/channels/${view == 'saved' ? 'saved' : 'inbox/$view'}',
      );
    }
    expect(const ChannelActivityScope('dms').path, '/channels/inbox');
    expect(
      const ChannelActivityScope('unread').parameters({})['filter'],
      'unread',
    );
  });

  test('DM count follows its accepted window across other view visits', () {
    final windows = {
      ResourceFilters.viewKey('/channels/inbox', {
        'filter': 'all',
        'scope': 'dms',
      }): const ResourceViewWindow(
        rows: [],
        hasMore: false,
        totalCount: 2,
        totalUnreadCount: 17,
      ),
      ResourceFilters.viewKey('/channels/inbox', {
        'filter': 'all',
      }): const ResourceViewWindow(
        rows: [],
        hasMore: false,
        totalCount: 34,
        totalUnreadCount: 17,
      ),
    };
    expect(ChannelActivityScope.directMessagesTotal(null, 34, windows), 2);
    expect(
      ChannelActivityScope.directMessagesTotal(windows.keys.first, 3, windows),
      3,
    );
    expect(ChannelActivityScope.directMessagesTotal(null, 34, {}), 0);
    for (var i = 0; i < 12; i++) {
      windows[ResourceFilters.viewKey('/channels/inbox', {
            'filter': 'all',
            'q': '$i',
          })] =
          windows.values.last;
      if (windows.length > 8) {
        windows.remove(ChannelActivityScope.evictionKey(windows));
      }
    }
    expect(windows.length, 8);
    expect(ChannelActivityScope.directMessagesTotal(null, 34, windows), 2);
  });

  test('DM empty copy yields to the selected source, like ThreadsInbox', () {
    const scope = ChannelActivityScope('dms');
    expect(scope.emptyState().title, 'No DM activity');
    expect(scope.emptyState(channelLabel: 'Room').title, 'No activity in Room');
    expect(
      scope.emptyState(channelLabel: 'Room').detail,
      'Try another channel or clear the channel filter.',
    );
  });
}
