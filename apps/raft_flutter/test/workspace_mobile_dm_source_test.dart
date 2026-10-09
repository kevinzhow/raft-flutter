import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_shell_contract_test.dart' show mountShell, retire;
import 'workspace_source_location_contract_test.dart' show pageFixture;

// Source Sidebar.tsx987–1001 and AvatarSlot.tsx90–95/126/229–230.
// The avatar's occupied box and its placeholder glyph are separate sizes.
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K08g] $family/$dark actual mobile human DM keeps Source 18px avatar and 10px placeholder',
      (t) async {
        final (w, api) = await pageFixture(t, section: 'home');
        w.dms = [
          RaftChannel({
            'id': 'dm-human',
            'type': 'dm',
            'joined': true,
            'peerType': 'human',
            'peerId': 'human-two',
            'peerName': 'Taylor',
          }),
        ];
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        await mountShell(t, w, family, dark, width: 390);
        final row = find.byKey(const ValueKey('sidebar-channel-dm-human'));
        final avatar = find.descendant(
          of: row,
          matching: find.byType(RaftAvatar),
        );
        expect(t.getSize(avatar), const Size(18, 18));
        expect(
          t.widget<RaftAvatar>(avatar).mountedContext,
          RaftMountedAvatarContext.sidebarList,
        );
        final placeholder = t.widget<RaftIcon>(
          find.descendant(of: avatar, matching: find.byType(RaftIcon)),
        );
        expect(placeholder.glyph, RaftGlyph.user);
        expect(placeholder.size, 10);
        final label = t.widget<Text>(
          find.descendant(of: row, matching: find.text('Taylor')),
        );
        expect(label.style!.fontSize, 14);
        expect(label.style!.height, 20 / 14);
        expect(label.style!.fontWeight, FontWeight.w500);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
        expect(find.byKey(const Key('mobile-tab-members')), findsOneWidget);
        await retire(t);
      },
    );
  }
}
