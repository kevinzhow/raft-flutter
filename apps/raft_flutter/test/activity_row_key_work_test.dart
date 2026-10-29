import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, channelRow;

class _RowFacts extends MapBase<String, dynamic> {
  _RowFacts(this.data);
  final Map<String, dynamic> data;
  int keyReads = 0;
  @override
  dynamic operator [](Object? key) {
    if (key == 'kind' || key == 'channelId') keyReads++;
    return data[key];
  }

  @override
  void operator []=(String key, dynamic value) => data[key] = value;
  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  dynamic remove(Object? key) => data.remove(key);
}

class _Workspace extends ActivityWorkspace {
  _Workspace(super.client);
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async =>
      path == '/channels/inbox'
      ? {'items': inbox, 'totalCount': inbox.length, 'hasMore': false}
      : super.query(path, query: query);
}

void main() {
  testWidgets(
    'resizing a 3000-row Activity window does not regenerate offscreen row keys',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          for (var i = 0; i < 3000; i++)
            RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
        ]
        ..inbox = [for (var i = 0; i < 3000; i++) channelRow(i)];
      addTearDown(client.dispose);
      addTearDown(w.dispose);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'activity',
              activitySidebarEnabled: true,
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      dynamic page = tester.state(find.byType(ResourceView));
      expect(page.rows, hasLength(3000));
      final measured = [
        for (final Map<String, dynamic> row in page.rows) _RowFacts(row),
      ];
      page.setState(() {
        page.rows = measured;
      });
      await tester.pumpAndSettle();
      for (final row in measured) {
        row.keyReads = 0;
      }
      tester.view.physicalSize = const Size(1201, 800);
      await tester.pumpAndSettle();
      final reads = measured
          .skip(2500)
          .fold<int>(0, (sum, row) => sum + row.keyReads);
      page = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(
        reads,
        0,
        reason: 'The row identities and order did not change; a viewport resize should only rebuild the visible cards, not regenerate keys for the whole accepted window.',
      );
    },
  );
}
