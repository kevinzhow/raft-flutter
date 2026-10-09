import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'human', 'name': 'Public Human'});
    selectServer('s');
  }
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'blocksChat': false};
    }
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path == '/channels/unread') return {'channels': {}};
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async => {};
  @override
  void joinChannel(String id) {}
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': []};
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final searches = <String?>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path == '/messages/search') {
      searches.add(query?['channelId'] as String?);
      return {'results': [], 'hasMore': false};
    }
    return [];
  }
}

void main() {
  for (final revoke in ['channel', 'principal']) {
    testWidgets(
      'real channel header seeds a fresh search; $revoke revocation cannot open global search',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final client = _Client();
        final channel = RaftChannel({
          'id': 'c',
          'serverId': 's',
          'name': 'Public channel',
          'type': 'channel',
          'joined': true,
        });
        final w = _Workspace(client)
          ..server = RaftRecord({
            'id': 's',
            'role': 'owner',
            'name': 'Public fixture',
          })
          ..servers = [
            RaftRecord({'id': 's', 'role': 'owner', 'name': 'Public fixture'}),
          ]
          ..channels = [channel]
          ..channel = channel
          ..section = 'home';
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: WorkspaceView(
              controller: w,
              appearance: const RaftAppearance(),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('sidebar-channel-c')));
        await t.pumpAndSettle();
        await t.tap(find.bySemanticsLabel('Search this channel'));
        await t.pumpAndSettle();
        final entry = t.widget<ResourceView>(find.byType(ResourceView));
        expect(entry.initialSearchChannelId, 'c');
        expect(entry.restoreSearchState, isFalse);
        expect(w.searches, ['c']);
        if (revoke == 'channel') {
          w.channels = [];
        } else {
          client.user = RaftRecord({
            'id': 'other',
            'name': 'Other public human',
          });
        }
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(find.byType(ResourceView), findsNothing);
        expect(find.text('Channel is no longer available'), findsOneWidget);
        expect(w.searches, ['c']);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
