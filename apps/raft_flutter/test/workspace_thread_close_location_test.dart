import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_activity_activation_test.dart' show message;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '[N07a] $family/$dark desktop Close replaces the mounted pending thread slot',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.loading = false;
        w.ledger.switchServer('s1');
        w.section = 'chat';
        w.ledger.ingest([
          message('main-tail', 'c1'),
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'main-tail'};
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        api.routes['POST /channels/c1/read'] = (_) => {};
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
        final parent = Completer<Map<String, dynamic>>(),
            resolution = Completer<Map<String, dynamic>>();
        api.routes['GET /messages/context/parent'] = (_) => parent.future;
        api.routes['GET /channels/c1/threads/parent'] = (_) =>
            resolution.future;
        w.navigation.navigate(
          w.location.withQuery({
            'task': 'c2:independent-task',
            'profile': 'human:alice',
            'keep': 'encoded value:1',
          }),
        );
        final opening = w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'parent',
          focusedMessageId: 'unrelated-focus',
        );
        await tester.pump();
        expect(find.byType(RaftThreadHeader), findsOneWidget);
        expect(w.threadIdentity?.parentMessageId, 'parent');
        final before = Map<String, String>.from(w.location.uri.queryParameters),
            entries = w.navigation.entries.length,
            index = w.navigation.index,
            revision = w.navigationRevision;
        await tester.tap(find.byKey(const Key('thread-close')));
        await tester.pump();
        expect(w.location.uri.queryParameters, {...before}..remove('thread'));
        expect(w.navigation.entries.length, entries);
        expect(w.navigation.index, index);
        expect(w.navigationRevision, revision + 1);
        expect(w.threadIdentity, isNull);
        expect(find.byType(RaftThreadHeader), findsNothing);
        await tester.runAsync(() async {
          parent.complete({
            'messages': [message('parent', 'c1')],
          });
          resolution.complete({'threadChannelId': 'thread-1'});
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        await opening;
        expect(w.location.thread, isNull);
        expect(w.threadIdentity, isNull);
        expect(w.navigation.index, index);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
