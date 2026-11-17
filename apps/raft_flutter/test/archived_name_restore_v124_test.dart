import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  testWidgets(
    'unarchive retries in place and navigates without reporting a creation',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      api.statuses['POST /channels'] = 409;
      api.routes['POST /channels'] = (_) => {
        'error': 'Name held',
        'code': 'archived_name_collision',
        'archivedChannelId': 'archived-1',
        'archivedChannelName': 'held',
        'archivedChannelType': 'channel',
        'canUnarchiveArchivedChannel': true,
      };
      api.statuses['POST /channels/archived-1/unarchive'] = 500;
      api.routes['POST /channels/archived-1/unarchive'] = (_) => {
        'error': 'Restore failed',
      };
      t.view.physicalSize = const Size(1280, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var creations = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: RaftButton(
                label: 'Open',
                onPressed: () => unawaited(
                  showRaftModal<void>(
                    context,
                    builder: (_) => CreateChannelDialog(
                      controller: w,
                      prefilledName: 'held',
                      onCreated: (_) async {
                        creations++;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create Channel').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Unarchive'));
      await t.pumpAndSettle();
      expect(find.byType(RaftArchivedNameBanner), findsOneWidget);
      expect(find.text('Restore failed'), findsOneWidget);
      api.statuses.remove('POST /channels/archived-1/unarchive');
      api.routes['POST /channels/archived-1/unarchive'] = (_) => {
        'id': 'archived-1',
        'name': 'held',
        'type': 'channel',
      };
      await t.tap(find.text('Unarchive'));
      await t.pumpAndSettle();
      expect(w.selected, 'archived-1');
      expect(creations, 0);
      expect(find.byType(CreateChannelDialog), findsNothing);
      expect(
        api.calls.where((c) => c.path == '/channels' && c.method == 'POST'),
        hasLength(1),
      );
      expect(
        api.calls.where((c) => c.path.endsWith('/unarchive')),
        hasLength(2),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.byType(RaftArchivedNameBanner), findsNothing);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
    },
  );
}
