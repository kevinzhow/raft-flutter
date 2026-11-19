import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/thread_search.dart';
import 'package:raft_flutter/data/thread_visit.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/thread_outline_fixture.dart';

void main() {
  for (final (platform, size) in [
    (TargetPlatform.linux, const Size(960, 840)),
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets(
      'Timeline opens and jumps in the same thread on $platform $size',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final client = RaftClient(
          origin: 'https://fixture.invalid',
          sessionStore: MemorySessionStore(),
        )..user = RaftRecord({'id': 'u'});
        client.selectServer('s');
        final w = ThreadOutlineTestWorkspace(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'});
        w.messageDomain.state.threadIdentity = const WorkspaceThreadIdentity(
          parentChannelId: 'channel',
          parentMessageId: 'parent',
        );
        w.threadChannelId = 'replies';
        w.messageDomain.state.threadVisit = ThreadVisit.request(
          w.messageDomain,
          'channel',
        );
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });

        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topRight,
                child: ThreadActions(
                  controller: w,
                  parentMessageId: 'parent',
                  menuMode: true,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('thread-options')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('thread-mark-unread')),
          findsOneWidget,
          reason:
              'requests: ${w.requests}; followed: ${w.services.followedThreads.threads}',
        );
        await t.tap(find.byKey(const Key('thread-timeline-menu-item')));
        await t.pumpAndSettle();
        expect(find.text('An older outline reply'), findsOneWidget);
        final touch = platform == TargetPlatform.android;
        expect(find.byType(RaftSheet), touch ? findsOneWidget : findsNothing);
        await t.tap(find.text('An older outline reply'));
        await t.pumpAndSettle();

        expect(w.jumps, ['old-reply']);
        expect(find.text('An older outline reply'), findsNothing);
        expect(
          w.requests.where((path) => path.endsWith('/human-outline')),
          hasLength(1),
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
