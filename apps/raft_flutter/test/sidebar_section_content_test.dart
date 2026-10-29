import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Raft $dark runtime metadata survives descriptions and yields to unread counts',
      (t) async {
        final (w, api) = await pageFixture(t);
        api.routes['GET /agents'] = (_) => [
          {
            'id': 'runtime-agent',
            'name': 'Cindy',
            'displayName': 'Cindy',
            'description': 'Keeps visual tests honest',
            'runtime': 'codex',
            'status': 'active',
            'activity': 'idle',
            'serverId': 's1',
          },
        ];
        w.dms = [
          RaftChannel({
            'id': 'runtime-dm',
            'type': 'dm',
            'peerType': 'agent',
            'peerId': 'runtime-agent',
            'name': 'Cindy',
            'peerDisplayName': 'Cindy',
            'peerDescription': 'Keeps visual tests honest',
            'joined': true,
          }),
        ];
        await mountPage(t, w, dark);
        final row = find.byKey(const ValueKey('sidebar-channel-runtime-dm'));
        expect(
          find.descendant(of: row, matching: find.text('Codex CLI')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text('Keeps visual tests honest'),
          ),
          findsOneWidget,
        );
        w.conversationReads.unread['runtime-dm'] = 2;
        w.notifyListeners();
        await t.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.text('Codex CLI')),
          findsNothing,
        );
        expect(
          find.descendant(of: row, matching: find.text('2')),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'Raft $dark adjacent sidebar margins collapse like the mounted source',
      (t) async {
        final (w, _) = await pageFixture(t);
        w.channels = [
          for (final id in ['first', 'second'])
            RaftChannel({
              'id': id,
              'name': id,
              'type': 'channel',
              'joined': true,
            }),
        ];
        w.dms = [];
        await mountPage(t, w, dark);
        final first = find.byKey(const ValueKey('sidebar-channel-first'));
        final second = find.byKey(const ValueKey('sidebar-channel-second'));
        expect(t.getTopLeft(second).dy - t.getTopLeft(first).dy, 37);
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'Raft $dark retains conversation content across sidebar sections',
      (t) async {
        final (w, _) = await pageFixture(t);
        w.dms = [
          RaftChannel({
            'id': 'uniform-peer',
            'type': 'dm',
            'peerType': 'agent',
            'peerId': 'uniform-agent',
            'name': 'Cindy',
            'peerDisplayName': 'Cindy',
            'peerDescription': 'Keeps visual tests honest',
            'joined': true,
          }),
        ];
        await mountPage(t, w, dark);
        final row = find.byKey(const ValueKey('sidebar-channel-uniform-peer'));
        for (final section in ['normal', 'pinned', 'custom']) {
          w.sidebarOrder = switch (section) {
            'pinned' => {
              'pinned': [
                {'kind': 'agent', 'id': 'uniform-agent'},
              ],
            },
            'custom' => {
              'customSections': [
                {'id': 'launch', 'name': 'Launch', 'sortMode': 'manual'},
              ],
              'sectionPlacements': [
                {
                  'kind': 'channel',
                  'id': 'uniform-peer',
                  'sectionId': 'launch',
                  'position': 0,
                },
              ],
            },
            _ => {},
          };
          w.notifyListeners();
          await t.pumpAndSettle();
          expect(row, findsOneWidget);
          final item = t.widget<RaftNavItem>(row);
          expect(
            item.description,
            'Keeps visual tests honest',
            reason: section,
          );
          expect(item.wrap, false, reason: section);
          expect(
            find.descendant(
              of: row,
              matching: find.text('Keeps visual tests honest'),
            ),
            findsOneWidget,
          );
        }
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}
