import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/workspace_dm_header.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final peerType in ['human', 'agent', 'missing']) {
      testWidgets('actual DM avatar routes $peerType correctly at $width', (
        t,
      ) async {
        final (w, api) = await pageFixture(t, section: 'chat');
        addTearDown(() => retire(t));
        final peerId = peerType == 'missing' ? '' : 'peer-1';
        final dm = RaftChannel({
          'id': 'dm-review',
          'type': 'dm',
          'joined': true,
          'peerId': peerId,
          'peerType': peerType,
          'peerName': 'Taylor',
          'peerDisplayName': 'Taylor',
        });
        final agent = <String, dynamic>{
          'id': 'peer-1',
          'name': 'Taylor',
          'displayName': 'Taylor',
          'serverId': 's1',
          'runtime': 'claude',
          'status': 'active',
          'model': 'sonnet',
          'activity': 'offline',
          'avatarUrl': null,
        };
        w.channel = dm;
        w.channels = [];
        w.dms = [dm];
        w.navigation.navigate(
          RaftLocation.at(
            serverSlug: w.location.serverSlug,
            route: RaftRoute.dm,
            entityId: dm.id,
          ),
        );
        api.routes['GET /channels/dm'] = (_) => [dm.json];
        api.routes['GET /announcements/active'] = (_) => null;
        api.routes['GET /servers/s1/machines'] = (_) => [];
        api.routes['GET /agents'] = (_) => [if (peerType == 'agent') agent];
        api.routes['GET /agents/peer-1'] = (_) => agent;
        api.routes['GET /agents/peer-1/skills'] = (_) => {
          'global': [],
          'workspace': [],
        };
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/s1/members/peer-1/profile'] = (_) => {
          'id': 'peer-1',
          'userId': 'peer-1',
          'name': 'Taylor',
          'displayName': 'Taylor',
        };
        await mountShell(t, w, false, width: width);
        final avatar = find.byKey(const Key('dm-header-avatar-button'));
        if (peerType == 'missing') {
          expect(avatar, findsNothing);
          expect(w.location.profile, isNull);
        } else {
          expect(avatar, findsOneWidget);
          await t.tap(avatar);
          expect(w.location.profile?.id, peerId);
          expect(
            w.location.profile?.kind,
            peerType == 'agent' ? RaftProfileKind.agent : RaftProfileKind.human,
          );
          await frames(t, () {});
          await t.pumpAndSettle();
          expect(
            find.byType(
              peerType == 'agent' ? AgentDetailPanel : MemberProfileView,
            ),
            findsOneWidget,
          );
        }
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final agent in [false, true]) {
    testWidgets(
      'DM profile action honours live selection state (agent: $agent)',
      (t) async {
        final (w, _) = await pageFixture(t, section: 'chat');
        addTearDown(() => retire(t));
        var selecting = true;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: WorkspaceDmHeader(
                headerKey: const Key('selection-guard-header'),
                controller: w,
                channel: RaftChannel({'id': 'dm-guard', 'peerId': 'peer-1'}),
                agent: agent,
                name: 'Taylor',
                profile: null,
                avatar: const SizedBox.square(dimension: 36),
                selectionActive: () => selecting,
                onSearch: () {},
                onSettings: () {},
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('dm-header-avatar-button')));
        expect(w.location.profile, isNull);
        selecting = false;
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(w.location.profile?.id, 'peer-1');
        expect(
          w.location.profile?.kind,
          agent ? RaftProfileKind.agent : RaftProfileKind.human,
        );
        w.closeProfile();
        selecting = true;
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pumpAndSettle();
        expect(w.location.profile, isNull);
      },
    );
  }
}
