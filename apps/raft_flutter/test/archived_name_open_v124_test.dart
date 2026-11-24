import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

void main() {
  test('collision parser only accepts visible allowed channels with complete metadata', () {
    const body = {
      'code': 'archived_name_collision',
      'archivedChannelId': 'archived-1',
      'archivedChannelName': 'held',
      'archivedChannelType': 'private',
      'canUnarchiveArchivedChannel': true,
    };
    Object error(Map<String, dynamic> payload) =>
        RaftApiException.response('Name held', body: payload);
    expect(parseArchivedChannelNameCollision(error(body)), (
      id: 'archived-1',
      name: 'held',
      type: 'private',
      canUnarchive: true,
    ));
    for (final invalid in [
      {...body, 'archivedChannelId': ''},
      {...body, 'archivedChannelName': 1},
      {...body, 'archivedChannelType': 'dm'},
      {...body, 'code': 'name_taken'},
    ]) {
      expect(parseArchivedChannelNameCollision(error(invalid)), isNull);
    }
    expect(
      parseArchivedChannelNameCollision(
        error({...body, 'archivedChannelType': 'joint'}),
        types: const {'channel', 'private'},
      ),
      isNull,
    );
    expect(
      parseArchivedChannelNameCollision(const RaftApiException('Failure')),
      isNull,
    );
  });
  testWidgets(
    'archived collision opens the channel without unarchiving or creating it',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      api.statuses['POST /channels'] = 409;
      api.routes['POST /channels'] = (_) => {
        'error': 'Name held',
        'code': 'archived_name_collision',
        'archivedChannelId': 'archive-1',
        'archivedChannelName': 'held',
        'archivedChannelType': 'channel',
        'canUnarchiveArchivedChannel': false,
      };
      t.view.physicalSize = const Size(1280, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var created = false;
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
                      onCreated: (_) async => created = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
      }

      await open();
      await t.enterText(find.byType(TextField).first, 'held');
      await t.tap(find.text('Create Channel').last);
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('archived-name-collision')),
        findsOneWidget,
      );
      await t.tap(find.text('Open channel'));
      await t.pumpAndSettle();
      expect(w.selected, 'archive-1');
      expect(created, isFalse);
      expect(find.byType(CreateChannelDialog), findsNothing);
      expect(api.calls.where((c) => c.path.endsWith('/unarchive')), isEmpty);
      expect(
        api.calls.where((c) => c.method == 'POST' && c.path == '/channels'),
        hasLength(1),
      );
      await open();
      expect(
        find.byKey(const ValueKey('archived-name-collision')),
        findsNothing,
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
    },
  );
}
