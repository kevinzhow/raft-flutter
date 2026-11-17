import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('channel sort and display settings each update with one PATCH', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final row = {
      'id': 'c1',
      'name': 'work',
      'joined': true,
      'type': 'channel',
      'channelCapabilities': {'editChannelMetadata': true},
      'threadSort': 'time',
      'collapseLongMessages': false,
    };
    final channel = RaftChannel(row);
    w.channel = channel;
    w.channels = [channel];
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'channel_thread_sort_v0', 'enabled': true},
      ],
    };
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) => <String, dynamic>{};
    api.routes['GET /channels/c1/notification-settings'] = (_) => {
      'activityMuted': false,
    };
    api.routes['GET /channels/c1/message-display-settings'] = (_) => {
      'collapseLongMessages': false,
    };
    api.routes['PATCH /channels/c1'] = (o) => {...row, ...(o.data as Map)};
    api.routes['PATCH /channels/c1/message-display-settings'] = (o) => {
      ...(o.data as Map),
      'prefsVersion': 1,
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelSettings(
            controller: w,
            channel: channel,
            isPanel: true,
            details: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final sort = find.byKey(const Key('channel-settings-thread-sort-switch'));
    final display = find.byKey(const Key('channel-settings-collapse-switch'));
    await t.ensureVisible(sort);
    final beforeSort = api.calls.length;
    await t.tap(sort);
    await t.pumpAndSettle();
    expect(
      api.calls
          .skip(beforeSort)
          .map((r) => [r.method, r.path, r.data])
          .toList(),
      [
        [
          'PATCH',
          '/channels/c1',
          {'threadSort': 'activity'},
        ],
      ],
    );
    expect(w.channels.single.string('threadSort'), 'activity');
    await t.ensureVisible(display);
    final beforeDisplay = api.calls.length;
    await t.tap(display);
    await t.pumpAndSettle();
    expect(
      api.calls
          .skip(beforeDisplay)
          .map((r) => [r.method, r.path, r.data])
          .toList(),
      [
        [
          'PATCH',
          '/channels/c1/message-display-settings',
          {'collapseLongMessages': true},
        ],
      ],
    );
    expect(w.channels.single.flag('collapseLongMessages'), isTrue);
  });
}
