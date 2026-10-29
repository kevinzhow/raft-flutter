import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

// Exercise both real mounted dialogs, including the server's collision reply
// and the action that removes its cause. Shared Banner composition alone does
// not establish that the notice disappears or stays gone when reopened.
void main() {
  for (final joint in [false, true]) {
    for (final restore in [false, true]) {
      testWidgets('${joint ? 'joint' : 'ordinary'} archived name resolves by '
          '${restore ? 'unarchive' : 'rename'} and stays clear on reopen', (
        tester,
      ) async {
        final (workspace, api) = (await tester.runAsync(() => fixture()))!;
        addTearDown(workspace.dispose);
        addTearDown(workspace.client.dispose);
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        api.statuses['POST /channels'] = 409;
        api.routes['POST /channels'] = (_) => {
          'error': 'The channel name is already held.',
          'code': 'archived_name_collision',
          'archivedChannelId': 'archived-1',
          'archivedChannelName': 'archive-me',
          'archivedChannelType': joint ? 'joint' : 'channel',
          'canUnarchiveArchivedChannel': true,
        };
        api.routes['POST /channels/archived-1/unarchive'] = (_) => {
          'id': 'archived-1',
          'name': 'archive-me',
          'type': 'channel',
        };
        String? resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: RaftButton(
                  label: 'Open',
                  onPressed: () {
                    unawaited(
                      showRaftModal<Object?>(
                        context,
                        builder: (_) => joint
                            ? CreateJointChannelDialog(
                                agents: const [],
                                users: const [],
                                onCreate: (payload) async =>
                                    Map<String, dynamic>.from(
                                      await workspace.command(
                                        'POST',
                                        '/channels',
                                        data: payload,
                                      ) as Map,
                                    ),
                                onUnarchive: (id) async =>
                                    Map<String, dynamic>.from(
                                      await workspace.command(
                                        'POST',
                                        '/channels/$id/unarchive',
                                      ) as Map,
                                    ),
                              )
                            : CreateChannelDialog(
                                controller: workspace,
                                onCreated: (channel) async {
                                  resolved = channel.id;
                                },
                              ),
                      ).then((value) {
                        if (value is Map) resolved = '${value['id']}';
                      }),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byType(RaftArchivedNameBanner), findsNothing);
        }

        await open();
        await tester.enterText(
          joint
              ? find.byKey(const ValueKey('joint-name'))
              : find.byType(TextField).first,
          'archive-me',
        );
        if (joint) {
          await tester.enterText(
            find.byKey(const ValueKey('joint-slug-0')),
            'partner',
          );
          await tester.enterText(
            find.byKey(const ValueKey('joint-people-0')),
            '@guest',
          );
        }
        final submit = joint
            ? find.byKey(const ValueKey('joint-create-submit'))
            : find.text('Create Channel').last;
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(RaftArchivedNameBanner), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RaftArchivedNameBanner),
            matching: find.byType(RaftBanner),
          ),
          findsOneWidget,
        );
        final action = find.text(restore ? 'Unarchive' : 'Change name');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(RaftArchivedNameBanner), findsNothing);
        final restoreCalls = api.calls.where(
          (call) =>
              call.method == 'POST' &&
              call.path == '/channels/archived-1/unarchive',
        );
        expect(restoreCalls.length, restore ? 1 : 0);
        if (restore) {
          expect(resolved, 'archived-1');
        } else {
          expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .controller!
                .text,
            isEmpty,
          );
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
        }
        await open();
        expect(find.byType(RaftArchivedNameBanner), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
      });
    }
  }
}
