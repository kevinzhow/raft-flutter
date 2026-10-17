import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';

class _AccessReads extends MapBase<String, dynamic> {
  _AccessReads(this.data);
  final Map<String, dynamic> data;
  int permissionReads = 0;
  @override
  dynamic operator [](Object? key) => data[key];
  @override
  void operator []=(String key, dynamic value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  bool containsKey(Object? key) {
    if (key == 'capabilities') permissionReads++;
    return data.containsKey(key);
  }

  @override
  void clear() => data.clear();
  @override
  dynamic remove(Object? key) => data.remove(key);
}

class _ObservedChannel extends RaftChannel {
  _ObservedChannel(this.facts) : super(facts);
  final _AccessReads facts;
  @override
  Map<String, dynamic> get json => facts;
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final routes = <String, dynamic>{};
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      routes[path] ?? [];
}

void main() {
  testWidgets(
    'scrolling Activity does not re-read unrelated channel permissions',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client =
          RaftClient(
              origin: 'https://example.invalid',
              sessionStore: MemorySessionStore(),
            )
            ..user = RaftRecord({'id': 'alice'})
            ..selectServer('s1');
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'});
      addTearDown(client.dispose);
      addTearDown(w.dispose);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      final facts = [
        for (var i = 0; i < 300; i++)
          _AccessReads({
            'id': 'c$i',
            'name': 'Channel $i',
            'joined': true,
            'capabilities': {'viewChannel': true},
          }),
      ];
      w.channels = facts.map(_ObservedChannel.new).toList();
      w.channel = w.channels.first;
      w.loading = false;
      w.routes['/channels/inbox'] = {
        'hasMore': false,
        'totalCount': 300,
        'items': [
          for (var i = 0; i < 300; i++)
            {
              'kind': 'channel',
              'channelId': 'c$i',
              'channelName': 'Channel $i',
              'lastMessagePreview': 'Actual Activity row $i',
              'lastMessageId': 'm$i',
              'lastMessageSeq': '${300 - i}',
              'unreadCount': 0,
            },
        ],
      };
      w.routes['/agents'] = [];
      w.routes['/servers/s1/members'] = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: withAppServices(
            ResourceView(
              controller: w,
              section: 'activity',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      for (var i = 0; i < 50; i++) {
        if (!(tester.state(find.byType(ResourceView)) as dynamic).loading) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1)),
        );
        await tester.pump();
      }
      dynamic page = tester.state(find.byType(ResourceView));
      expect(page.loading, false, reason: '${page.error}');
      expect(page.rows, hasLength(300));
      page = null;
      await tester.pump();
      expect(find.byKey(const ValueKey('activity-channel-c0')), findsOneWidget);
      for (final channel in facts) {
        channel.permissionReads = 0;
      }
      final scroll = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      await tester.drag(scroll, const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scroll).position.pixels,
        greaterThan(1000),
      );
      final reads = facts
          .skip(250)
          .fold<int>(0, (sum, c) => sum + c.permissionReads);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        reads,
        0,
        reason:
            'scrolling changes no authority; offscreen channels need no new '
            'permission reads. Explicit permission changes are covered by the '
            'Activity authority and revocation regressions.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
