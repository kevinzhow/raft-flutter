import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, channelRow;

class _MeasuredRow extends MapBase<String, dynamic> {
  _MeasuredRow(this.data);
  final Map<String, dynamic> data;
  int reads = 0;
  @override
  dynamic operator [](Object? key) {
    reads++;
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
  for (final size in [100, 3000]) {
    testWidgets('a message only reads its affected row in a $size-row window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = ActivityClient()..user = RaftRecord({'id': 'alice'});
      client.selectServer('s1');
      final w = _Workspace(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          for (var i = 0; i < size; i++)
            RaftChannel({'id': 'ch$i', 'name': 'Channel $i', 'joined': true}),
        ]
        ..inbox = [for (var i = 0; i < size; i++) channelRow(i)];
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
      final measured = [
        for (final Map<String, dynamic> row in page.rows) _MeasuredRow(row),
      ];
      page.setState(() {
        page.rows = measured;
        page.acceptedActivityItems = measured;
      });
      await tester.pumpAndSettle();
      for (final row in measured) {
        row.reads = 0;
      }
      final oldRows = page.rows;
      page.advanceActivity({
        'id': 'new-message',
        'channelId': 'ch${size - 1}',
        'seq': 100000,
        'content': 'Only the last conversation changed',
        'senderId': 'bob',
      });
      final unrelatedReads = measured
          .take(size - 1)
          .fold<int>(0, (sum, row) => sum + row.reads);
      final first = page.rows.first;
      final oldFirst = oldRows.first;
      final oldLast = oldRows.last;
      final acceptedLast = page.acceptedActivityItems.last;
      final batchReads = <int>[];
      if (size == 3000) {
        // One continuously retained window: do not reset its indexes between
        // batches, so accumulated update state remains part of the regression.
        for (var batch = 0; batch < 6; batch++) {
          for (final row in measured.take(size - 50)) {
            row.reads = 0;
          }
          for (var n = 0; n < 1000; n++) {
            final event = batch * 1000 + n;
            page.advanceActivity({
              'id': 'continuous-$event',
              'channelId': 'ch${size - 1 - event % 50}',
              'seq': 100001 + event,
              'content': 'Continuous message $event',
              'senderId': 'bob',
            });
            page.observeListUpdates();
          }
          batchReads.add(
            measured
                .take(size - 50)
                .fold<int>(0, (sum, row) => sum + row.reads),
          );
        }
      }
      page = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(first['channelId'], 'ch${size - 1}');
      expect(first['lastMessageId'], 'new-message');
      expect(oldFirst['channelId'], 'ch0');
      expect(oldLast['lastMessageId'], isNot('new-message'));
      expect(acceptedLast['lastMessageId'], 'new-message');
      if (size == 3000) {
        expect(
          batchReads,
          [0, 0, 0, 0, 0, 0],
          reason: '6000 messages in one window must not accumulate full-window row reads in later batches.',
        );
      }
      expect(
        unrelatedReads,
        0,
        reason: 'Locate and replace only the affected conversation; scanning or copying every row makes each live message grow with the accepted window.',
      );
    });
  }
}
