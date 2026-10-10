import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final initial = Completer<dynamic>();
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) =>
      initial.future;
}

void main() {
  for (final revoke in [false, true]) {
    testWidgets(
      'cold thread menu receives the store first membership; revoked=$revoke',
      (t) async {
        final client = RaftClient(
          origin: 'https://fixture.invalid',
          sessionStore: MemorySessionStore(),
        )..user = RaftRecord({'id': 'u'});
        // The shared followed-threads store is scoped to the selected server.
        client.selectServer('s');
        final parent = RaftMessage({
          'id': 'm',
          'channelId': 'c',
          'content': 'Thread parent',
        });
        final w = _Workspace(client)
          ..server = RaftRecord({'id': 's', 'role': 'owner'})
          ..threadParent = parent;
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: ThreadActions(
                controller: w,
                parentMessageId: parent.id,
                menuMode: true,
              ),
            ),
          ),
        );
        await t.tap(find.byKey(const Key('thread-options')));
        await t.pumpAndSettle();
        final entry = find.byKey(const Key('thread-follow-menu-item'));
        expect(t.widget<RaftMenuItem>(entry).onPressed, isNull);
        if (revoke) {
          client.user = RaftRecord({'id': 'next'});
          w.notifyListeners();
          await t.pump();
          expect(entry, findsNothing);
        }
        w.initial.complete({'threads': []});
        await t.pumpAndSettle();
        if (revoke) {
          expect(entry, findsNothing);
        } else {
          expect(t.widget<RaftMenuItem>(entry).onPressed, isNotNull);
          expect(t.widget<RaftMenuItem>(entry).label, 'Follow thread');
          expect(
            t.widget<RaftMenuItem>(entry).glyph,
            RaftGlyph.messageCirclePlus,
          );
          await t.tap(find.byKey(const Key('thread-options')));
          await t.pumpAndSettle();
          expect(entry, findsNothing);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
