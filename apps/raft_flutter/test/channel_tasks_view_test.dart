import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'channel tab requests its real channel endpoint and rejects late data after access loss',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 720);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      transport.routes['GET /agents'] = (_) => <dynamic>[];
      transport.routes['GET /servers/s1/members'] = (_) => <dynamic>[];
      final page = Completer<Map<String, dynamic>>();
      transport.routes['GET /tasks/channel/c1'] = (_) => page.future;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ResourceView(
              controller: w,
              section: 'tasks',
              channelId: 'c1',
              onMessage: (_, _) async {},
            ),
          ),
        ),
      );
      for (
        var step = 0;
        step < 20 && !transport.calls.any((r) => r.path == '/tasks/channel/c1');
        step++
      ) {
        await t.pump(const Duration(milliseconds: 10));
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
      }
      expect(
        transport.calls.where((r) => r.path == '/tasks/channel/c1'),
        hasLength(1),
      );
      expect(transport.calls.where((r) => r.path == '/tasks/server'), isEmpty);
      expect(find.bySemanticsLabel('Channel'), findsNothing);
      w.channels = [];
      w.channel = null;
      w.setError(null);
      await t.pump();
      page.complete({
        'tasks': [
          {
            'id': 'private-task',
            'channelId': 'c1',
            'taskNumber': 1,
            'status': 'todo',
            'title': 'Late private title',
          },
        ],
      });
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await t.pumpAndSettle();
      expect(find.text('Late private title'), findsNothing);
      expect(find.text('This channel is not available.'), findsOneWidget);
      expect(
        transport.calls.where((r) => r.path == '/tasks/channel/c1'),
        hasLength(1),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );
}
