import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_section_select.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets('creating a section also moves the channel in the same write', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    final channel = RaftChannel({
      'id': 'c1',
      'type': 'channel',
      'joined': true,
    });
    w.sidebarOrder = {'sectionsVersion': 3};
    api.routes['PATCH /servers/s1/sidebar-order'] = (request) => {
      ...w.sidebarOrder,
      ...(request.data as Map),
    };
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ChannelSectionSelect(controller: w, channel: channel),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('channel-settings-section-select')));
    await t.pumpAndSettle();
    await t.tap(find.text('Create section'));
    await t.pumpAndSettle();
    expect(find.byType(RaftSidebarSectionDialog), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'Projects');
    await t.pumpAndSettle();
    await t.tap(find.text('Create section').last);
    await t.pumpAndSettle();
    final request = api.calls.singleWhere(
      (request) => request.method == 'PATCH',
    );
    final custom = (request.data['customSections'] as List).single as Map;
    expect(custom['name'], 'Projects');
    expect(request.data['sectionPlacements'], [
      {'kind': 'channel', 'id': 'c1', 'sectionId': custom['id'], 'position': 0},
    ]);
    expect(request.data['sectionsVersion'], 3);
    expect(find.byType(RaftSidebarSectionDialog), findsNothing);
    expect(find.text('Projects'), findsOneWidget);
  });

  testWidgets(
    'moving a channel from Pinned to a section submits one placement update',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel({
        'id': 'c1',
        'type': 'channel',
        'joined': true,
      });
      w.sidebarOrder = {
        'pinned': [
          {'kind': 'channel', 'id': 'c1'},
        ],
        'customSections': [
          {'id': 'work', 'name': 'Work'},
        ],
        'sectionPlacements': <Map<String, dynamic>>[],
        'sectionsVersion': 4,
      };
      api.routes['PATCH /servers/s1/sidebar-order'] = (o) => {
        ...w.sidebarOrder,
        ...(o.data as Map),
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: ChannelSectionSelect(controller: w, channel: channel),
          ),
        ),
      );
      await t.tap(find.text('Pinned'));
      await t.pumpAndSettle();
      await t.tap(find.text('Work'));
      await t.pumpAndSettle();
      final request = api.calls.singleWhere((r) => r.method == 'PATCH');
      expect(request.path, '/servers/s1/sidebar-order');
      expect(request.data, {
        'pinned': [],
        'sectionPlacements': [
          {'kind': 'channel', 'id': 'c1', 'sectionId': 'work', 'position': 0},
        ],
        'sectionsVersion': 4,
      });
      expect(find.text('Work'), findsOneWidget);
    },
  );
}
