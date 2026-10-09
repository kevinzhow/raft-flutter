import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[K09e] $family/$dark mounted Chat/Activity attention owns distinct accepted data and suppresses active',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.channels = [
          w.channel!,
          RaftChannel({
            'id': 'discovery',
            'name': 'Not joined',
            'joined': false,
          }),
        ];
        w.unread['discovery'] = 17;
        w.section = 'search';
        final accepted = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (_) => accepted.future;
        api.routes['GET /agents'] = (_) => [];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/s1/machines'] = (_) => [];
        api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        Finder attention(String id) => find.descendant(
          of: find.byKey(ValueKey('rail-$id')),
          matching: find.byType(RaftRailAttention),
        );
        expect(
          attention('chat'),
          findsNothing,
          reason: 'unjoined discovery rows cannot light Chat',
        );
        expect(attention('activity'), findsNothing);
        expect(find.byType(RaftRailUnreadCount), findsNothing);
        w.unread['c1'] = 3;
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(attention('chat'), findsOneWidget);
        expect(
          attention('activity'),
          findsNothing,
          reason: 'chat unread cannot substitute for Activity total',
        );
        await tester.tap(find.byKey(const ValueKey('rail-activity')));
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            attention('activity'),
            findsNothing,
            reason: 'active Activity suppresses its own indicator',
          );
        }
        await tester.runAsync(() async {
          accepted.complete({'items': [], 'totalUnreadCount': 7});
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rail-search')));
        await tester.pumpAndSettle();
        expect(attention('activity'), findsOneWidget);
        w.unread['c1'] = 0;
        w.notifyListeners();
        await tester.pumpAndSettle();
        expect(attention('chat'), findsNothing);
        expect(
          attention('activity'),
          findsOneWidget,
          reason: 'accepted server Activity total survives section change',
        );
        final zero = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (_) => zero.future;
        await tester.tap(find.byKey(const ValueKey('rail-activity')));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() async {
          zero.complete({'items': [], 'totalUnreadCount': 0});
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rail-search')));
        await tester.pumpAndSettle();
        expect(
          attention('activity'),
          findsNothing,
          reason: 'accepted zero cannot be resurrected by discovery unread',
        );
        final oldWindow = Completer<Map<String, dynamic>>();
        final newWindow = Completer<Map<String, dynamic>>();
        api.routes['GET /channels/inbox'] = (request) =>
            request.headers['X-Server-Id'] == 's1'
            ? oldWindow.future
            : newWindow.future;
        await tester.tap(find.byKey(const ValueKey('rail-activity')));
        await tester.pump(const Duration(milliseconds: 16));
        w.client.selectServer('s2');
        w.server = RaftRecord({'id': 's2', 'role': 'owner'});
        w.notifyListeners();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() async {
          oldWindow.complete({'items': [], 'totalUnreadCount': 99});
          newWindow.complete({'items': [], 'totalUnreadCount': 0});
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rail-search')));
        await tester.pumpAndSettle();
        expect(
          attention('activity'),
          findsNothing,
          reason: 'late old-server acceptance cannot light the new scope',
        );
        expect(find.byType(RaftRailUnreadCount), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '[K09e] $family/$dark actual pinned Agent row uses Source SidebarItemCount',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.section = 'chat';
        w.sidebarOrder = {
          'pinned': [
            {'kind': 'agent', 'id': 'agent-1'},
          ],
        };
        w.dms = [
          RaftChannel({
            'id': 'agent-dm',
            'type': 'dm',
            'peerType': 'agent',
            'peerId': 'agent-1',
            'joined': true,
          }),
        ];
        w.unread['agent-dm'] = 12;
        api.routes['GET /agents'] = (_) => [
          {'id': 'agent-1', 'name': 'Actual Agent'},
        ];
        api.routes['GET /servers/s1/members'] = (_) => [];
        api.routes['GET /servers/s1/machines'] = (_) => [];
        api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: family),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('sidebar-agent:agent-1'));
        expect(row, findsOneWidget);
        final badge = find.descendant(
          of: row,
          matching: find.byType(RaftSidebarUnreadCount),
        );
        expect(badge, findsOneWidget);
        expect(tester.getSize(badge).height, 16);
        expect(
          find.descendant(of: badge, matching: find.text('12')),
          findsOneWidget,
        );
        final box = tester.widget<Container>(
          find.descendant(of: badge, matching: find.byType(Container)),
        );
        final decoration = box.decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(4));
        final text = tester.widget<Text>(
          find.descendant(of: badge, matching: find.text('12')),
        );
        expect(text.style!.fontSize, 10);
        expect(
          text.style!.fontWeight,
          family == RaftFamily.brutal ? FontWeight.w700 : FontWeight.w400,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
