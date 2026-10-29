import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage, frames;

void main() {
  for (final state in ['loaded', 'pending', 'pending-back']) {
    testWidgets('Search $state thread survives the desktop to phone projection', (
      t,
    ) async {
      final (w, api) = await pageFixture(t, section: 'search');
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
      w.navigation.navigate(
        RaftLocation.parse('/s/demo/search?q=needle&keep=accepted'),
        kind: RaftNavigationKind.replace,
      );
      final parent = Completer<Map<String, dynamic>>(),
          reply = Completer<Map<String, dynamic>>();
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [],
        'hasMore': false,
      };
      api.routes['GET /tasks/channel/c1'] = (_) => {'tasks': []};
      api.routes['GET /announcements/active'] = (_) => {'announcements': []};
      api.routes['GET /messages/search'] = (_) => {
        'results': [
          {
            ...message('reply', 't1'),
            'channelType': 'thread',
            'parentChannelId': 'c1',
            'parentMessageId': 'parent',
            'parentChannelName': 'test',
            'content': 'Needle reply',
          },
        ],
        'hasMore': false,
      };
      api.routes['GET /messages/context/parent'] = (_) => parent.future;
      api.routes['GET /messages/context/reply'] = (_) => reply.future;
      addTearDown(() {
        if (!parent.isCompleted) parent.complete({'messages': []});
        if (!reply.isCompleted) reply.complete({'messages': []});
      });
      await mountPage(t, w, false, width: 1440);
      await t.tap(find.byType(RaftSearchResultSurface).first);
      await frames(t, () {});
      Future<void> finish() async {
        await t.runAsync(() async {
          parent.complete({
            'messages': [message('parent', 'c1')],
          });
          reply.complete({
            'messages': [message('reply', 't1')],
          });
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await t.pumpAndSettle();
      }

      if (state == 'loaded') await finish();
      expect(w.location.route, RaftRoute.search);
      expect(w.location.content?.kind, RaftContentKind.thread);
      final accepted = find.byKey(const ValueKey('message-reply'));
      expect(
        w.threadIdentity?.parentMessageId,
        'parent',
        reason:
            'before resize: ${w.location} rev=${w.navigationRevision}, raw=${w.messageDomain.state.threadIdentity?.parentMessageId}',
      );
      if (state == 'loaded') {
        expect(
          accepted,
          findsOneWidget,
          reason: 'the desktop thread must already be painted',
        );
      }
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      if (state == 'pending-back') {
        await t.tap(find.byKey(const Key('mobile-detail-back')));
        await t.pumpAndSettle();
        await finish();
        expect(w.location.route, RaftRoute.search);
        expect(w.location.query('q'), 'needle');
        expect(w.threadIdentity, isNull);
        expect(accepted, findsNothing);
        expect(t.takeException(), isNull);
        return;
      }
      if (state == 'pending') await finish();
      for (final size in [
        const Size(390, 844),
        const Size(1440, 900),
        const Size(767, 900),
      ]) {
        t.view.physicalSize = size;
        await t.pumpAndSettle();
        expect(
          w.threadIdentity?.parentMessageId,
          'parent',
          reason:
              'at $size: ${w.location}, rev=${w.navigationRevision}, raw=${w.messageDomain.state.threadIdentity?.parentMessageId}, rows=${w.messageDomain.visibleIds["t1"]}',
        );
        expect(w.threadChannelId, 't1');
        expect(accepted, findsOneWidget);
        expect(t.getRect(accepted).overlaps(Offset.zero & size), isTrue);
        expect(t.takeException(), isNull);
      }
      await t.tap(find.byKey(const Key('mobile-detail-back')));
      await t.pumpAndSettle();
      expect(w.location.route, RaftRoute.search);
      expect(w.location.query('q'), 'needle');
      expect(w.threadIdentity, isNull);
      expect(find.byType(RaftSearchResultSurface), findsOneWidget);
    });
  }
}
