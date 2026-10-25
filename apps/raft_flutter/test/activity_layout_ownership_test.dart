import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, channelRow;

const _flag = ActivityRolloutFlags.activityConversationListKey;
Map<String, dynamic> _evaluation(bool enabled) => {
  'evaluations': [
    {'key': _flag, 'enabled': enabled},
  ],
};

class _Client extends ActivityClient {
  final evaluations = <Map>[];
  final replies = <String, Object>{};

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    if (path != '/feature-flags/evaluate' ||
        !(data['keys'] as List).contains(_flag)) {
      return super.post(path, data: data);
    }
    evaluations.add(Map.of(data as Map));
    return replies[data['serverId']] ?? _evaluation(false);
  }
}

void main() {
  late _Client client;
  late ActivityWorkspace w;

  setUp(() {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({});
    client = _Client()..user = RaftRecord({'id': 'alice'});
    client.responses['GET /servers'] = [
      {'id': 's1', 'role': 'owner'},
    ];
    client.selectServer('s1');
    w = ActivityWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..channels = [
        RaftChannel({'id': 'ch1', 'name': 'Channel 1', 'joined': true}),
      ]
      ..inbox = [channelRow(1, unread: 2)];
  });

  tearDown(() async {
    w.dispose();
    await client.dispose();
    DevicePreferences.reset();
  });

  Future<void> mount(WidgetTester tester, {String section = 'activity'}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ResourceView(
            controller: w,
            section: section,
            onMessage: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opening Activity evaluates its list layout without visiting a sidebar',
    (tester) async {
      client.replies['s1'] = _evaluation(true);
      await mount(tester);
      expect(client.evaluations, hasLength(1));
      expect(find.byType(RaftConversationListRow), findsOneWidget);
      expect(find.byType(RaftConversationCard), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester);
      expect(
        client.evaluations,
        hasLength(1),
        reason: 'Navigation reuses the session owner.',
      );
      expect(find.byType(RaftConversationListRow), findsOneWidget);
    },
  );

  testWidgets(
    'remembered list layout survives pending and failed reconnect checks',
    (tester) async {
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      DevicePreferences.adopt(prefs);
      FeatureFlagMemory.write(
        ['https://fixture.test', 'alice', 's1', 'owner'],
        {_flag: true},
      );
      final pending = Completer<Map<String, dynamic>>();
      client.replies['s1'] = pending.future;
      await mount(tester);
      expect(find.byType(RaftConversationListRow), findsOneWidget);
      expect(find.byType(RaftConversationCard), findsNothing);
      pending.completeError(StateError('temporary evaluation failure'));
      await tester.pumpAndSettle();
      expect(find.byType(RaftConversationListRow), findsOneWidget);
      client.replies['s1'] = _evaluation(true);
      client.emit('connected', null);
      await tester.pumpAndSettle();
      expect(client.evaluations, hasLength(2));
      expect(find.byType(RaftConversationListRow), findsOneWidget);
      expect(find.byType(RaftConversationCard), findsNothing);
    },
  );

  testWidgets('a late enabled answer cannot change a different server layout', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    client.replies['s1'] = pending.future;
    client.replies['s2'] = _evaluation(false);
    await mount(tester);
    expect(client.evaluations, hasLength(1));
    client.selectServer('s2');
    w.server = RaftRecord({'id': 's2', 'role': 'owner'});
    w.notifyListeners();
    await tester.pumpAndSettle();
    expect(client.evaluations.last['serverId'], 's2');
    expect(find.byType(RaftConversationCard), findsOneWidget);
    pending.complete(_evaluation(true));
    await tester.pumpAndSettle();
    expect(find.byType(RaftConversationCard), findsOneWidget);
    expect(find.byType(RaftConversationListRow), findsNothing);
  });

  testWidgets('Saved does not initialize unrelated Activity rollout flags', (
    tester,
  ) async {
    await mount(tester, section: 'saved');
    expect(client.evaluations, isEmpty);
    expect(ActivityRolloutFlags.peek(w), isNull);
  });
}
