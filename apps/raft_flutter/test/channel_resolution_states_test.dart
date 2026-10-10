import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final pendingMetadata = <String, Completer<dynamic>>{};
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('messages:$id');
    return {
      'messages': [
        {
          'id': 'm-$id',
          'channelId': id,
          'serverId': 's',
          'seq': '1',
          'content': 'Public fixture in $id',
          'senderId': 'other',
          'senderType': 'user',
          'createdAt': '2026-10-08T00:00:00Z',
        },
      ],
      'threadSummariesByParentMessageId': {},
    };
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (pendingMetadata[path] case final pending?) return pending.future;
    if (path == '/channels/c') {
      return {'id': 'c', 'serverId': 's', 'name': 'design', 'joined': true};
    }
    if (path == '/channels/unread') {
      return {
        'channels': {'c': 1},
      };
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    if (path == '/auth/providers') return {'providers': []};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      return {'maxReadSeq': '2', 'readStateVersion': '1'};
    }
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }
}

/// MainLayout.tsx:425-490 ChannelById: while the channel row is neither known
/// nor given up on, the page holds only "Loading channel"; a failed lookup is a
/// plain "Select a channel" body with Back. Neither state borrows a header,
/// tabs, message window or composer, and neither may show the empty-channel
/// "Start the conversation" copy.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final resolves in [false, true]) {
      testWidgets(
        '[L08b][K06b] $family/$dark unresolved channel shows Loading channel, then ${resolves ? 'the full channel page' : 'an explicit unavailable state'}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final c = _Client()..selectServer('s');
          final gone = RaftChannel({
            'id': 'gone',
            'name': 'Late channel',
            'joined': true,
          });
          final w = WorkspaceController(c, mobileNavigation: true)
            ..server = RaftRecord({
              'id': 's',
              'name': 'Fixture',
              'role': 'owner',
            })
            ..channels = [...c.channelRows, gone]
            ..channel = c.channelRows.first;
          w.ledger.switchServer('s');
          addTearDown(() async {
            w.dispose();
            await c.stream.close();
          });
          // Accepted selections, then the directory forgets the first channel
          // while the user can still navigate Back to its URL.
          await w.selectChannel(gone);
          await w.selectChannel(c.channelRows.first);
          w.channels = [...c.channelRows];
          final held = Completer<dynamic>();
          c.pendingMetadata['/channels/gone'] = held;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: WorkspaceView(
                controller: w,
                appearance: RaftAppearance(
                  mode: dark ? ThemeMode.dark : ThemeMode.light,
                  light: family,
                ),
                onAppearance: (_) async {},
                onLogout: () async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(RaftComposer), findsOneWidget);
          await tester.tap(find.byKey(const Key('mobile-detail-back')));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(c.calls, contains('GET:/channels/gone'));
            expect(w.location.entityId, 'gone');
            // Identity pending: an explicit loading body and no page chrome.
            expect(find.text('LOADING CHANNEL'), findsOneWidget);
            expect(find.byType(RaftComposer), findsNothing);
            expect(find.byType(RaftChatView), findsNothing);
            expect(find.byKey(const Key('conversation-tabs')), findsNothing);
            expect(find.text('Start the conversation'), findsNothing);
            expect(find.text('SELECT A CHANNEL'), findsNothing);
            expect(find.text('Loading...'), findsNothing);
          }
          if (resolves) {
            held.complete({
              'id': 'gone',
              'serverId': 's',
              'name': 'Late channel',
              'joined': true,
            });
            await tester.pumpAndSettle();
            expect(find.text('LOADING CHANNEL'), findsNothing);
            expect(find.text('SELECT A CHANNEL'), findsNothing);
            expect(find.byType(RaftChatView), findsOneWidget);
            expect(find.byType(RaftComposer), findsOneWidget);
            expect(find.byKey(const Key('conversation-tabs')), findsOneWidget);
            expect(w.channel?.id, 'gone');
            expect(w.messages.map((m) => m.id), ['m-gone']);
            expect(
              find.byKey(const ValueKey('message-m-gone')),
              findsOneWidget,
            );
          } else {
            held.completeError(
              const RaftApiException('Channel not found', status: 404),
            );
            await tester.pumpAndSettle();
            expect(w.missingConversationChannelId, 'gone');
            expect(find.text('LOADING CHANNEL'), findsNothing);
            expect(find.text('SELECT A CHANNEL'), findsOneWidget);
            expect(find.byType(RaftComposer), findsNothing);
            expect(find.byType(RaftChatView), findsNothing);
            expect(find.text('Start the conversation'), findsNothing);
            expect(
              find.descendant(
                of: find.byType(RaftChannelResolutionBody),
                matching: find.byTooltip('Back'),
              ),
              findsOneWidget,
            );
            expect(w.error, isNull);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }
}
