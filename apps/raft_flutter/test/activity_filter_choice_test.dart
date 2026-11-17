import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(DevicePreferences.reset);

  test('every choice sends Web exact query', () {
    expect(ActivityFilterChoice.all.query, {'filter': 'all'});
    expect(ActivityFilterChoice.unread.query, {'filter': 'unread'});
    expect(ActivityFilterChoice.mentions.query, {'filter': 'mentions'});
    expect(ActivityFilterChoice.pinned.query, {'filter': 'all', 'scope': 'pinned'});
    expect(ActivityFilterChoice.saved.query, {'filter': 'all', 'scope': 'saved'});
    expect(ActivityFilterChoice.artifacts.query, {'filter': 'all', 'scope': 'artifacts'});
  });

  test('page size is 50', () {
    expect(activityPageSize, 50);
  });

  test('the choices that are scopes', () {
    expect(
      ActivityFilterChoice.values.where((c) => c.isScope),
      [ActivityFilterChoice.pinned, ActivityFilterChoice.saved, ActivityFilterChoice.artifacts],
    );
  });

  test('unknown or retired values read as All', () {
    for (final raw in ['done', 'dms', 'unfollowed', 'unread_mentions', '', null, 3]) {
      expect(ActivityFilterChoice.parse(raw), ActivityFilterChoice.all, reason: '$raw');
    }
    expect(ActivityFilterChoice.parse('pinned'), ActivityFilterChoice.pinned);
  });

  test('fromQuery maps an unread-mentions filter to Mentions', () {
    expect(ActivityFilterChoice.fromQuery('unread_mentions', null), ActivityFilterChoice.mentions);
    expect(ActivityFilterChoice.fromQuery('all', 'saved'), ActivityFilterChoice.saved);
    expect(ActivityFilterChoice.fromQuery('unread', null), ActivityFilterChoice.unread);
  });

  test('persistence is per server under Web key and the first read is sync', () async {
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    expect(ActivityFilterPreference.key('s1'), 'raft.activity.filter.s1');
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.all);
    ActivityFilterPreference.write('s1', ActivityFilterChoice.pinned);
    ActivityFilterPreference.write('s2', ActivityFilterChoice.unread);
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.pinned);
    expect(ActivityFilterPreference.read('s2'), ActivityFilterChoice.unread);
    expect(ActivityFilterPreference.read(null), ActivityFilterChoice.all);
    // All removes the key.
    ActivityFilterPreference.write('s1', ActivityFilterChoice.all);
    await Future<void>.delayed(Duration.zero);
    expect(DevicePreferences.current!.containsKey('raft.activity.filter.s1'), isFalse);
    expect(ActivityFilterPreference.read('s1'), ActivityFilterChoice.all);
  });

  test('upgrade: old stored view values read as All with nothing to migrate', () async {
    SharedPreferences.setMockInitialValues({
      'raft.activity.filter.a': 'done',
      'raft.activity.filter.b': 'dms',
      'raft.activity.filter.c': 'unfollowed',
      'raft.activity.view': 'saved',
    });
    DevicePreferences.adopt(await SharedPreferences.getInstance());
    expect(ActivityFilterPreference.read('a'), ActivityFilterChoice.all);
    expect(ActivityFilterPreference.read('b'), ActivityFilterChoice.all);
    expect(ActivityFilterPreference.read('c'), ActivityFilterChoice.all);
    // A key from before this feature is not read for any server.
    expect(ActivityFilterPreference.read('view'), ActivityFilterChoice.all);
  });

  test('empty-state ids per scope, then mentions, then unread, then default', () {
    expect(ActivityFilterChoice.pinned.emptyTitle, 'No pinned conversations');
    expect(ActivityFilterChoice.saved.emptyTitle, 'No saved threads');
    expect(ActivityFilterChoice.artifacts.emptyTitle, 'No Artifacts here');
    expect(ActivityFilterChoice.mentions.emptyTitle, 'No mentions');
    expect(ActivityFilterChoice.unread.emptyTitle, 'No unread conversations');
    expect(ActivityFilterChoice.all.emptyTitle, 'No conversations');
    expect(ActivityFilterChoice.saved.emptyDescription,
        'Save a message and its thread shows up here.');
  });
}
