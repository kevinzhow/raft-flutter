import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/mobile_route_gate.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'app_global_server_selector_test.dart' show RootFixture;
import 'mobile_back_history_test.dart' show finishBackTransition;

Finder composeField(String channelId) => find.descendant(
  of: find.byKey(ValueKey('compose-$channelId')),
  matching: find.byType(TextField),
);

/// True when the phone page for [entityId] contains [text]. The page leaving
/// the screen can still paint its own rows during the transition.
bool pageShows(WidgetTester tester, String entityId, String text) {
  for (final element in find.text(text, skipOffstage: false).evaluate()) {
    final location = MobileRouteGate.locationOf(element);
    if (location?.entityId == entityId) return true;
  }
  return false;
}

List<WorkspaceView> phonePages(WidgetTester tester) => tester
    .widgetList<WorkspaceView>(
      find.byWidgetPredicate(
        (widget) => widget is WorkspaceView && widget.mobileRoutePage,
        skipOffstage: false,
      ),
    )
    .toList();

void main() {
  for (final theme in ['brutal', 'elegant-dark']) {
    testWidgets('phone Chat and Activity share one draft $theme', (
      tester,
    ) async {
      final f = RootFixture();
      f.overrides['GET /channels/inbox'] = (_) => {
        'items': [
          {
            ...activityRow('channel', unread: 0, seq: '1'),
            'channelId': 'ca',
            'channelName': 'general-a',
            'lastMessageId': 'ma',
            'firstUnreadMessageId': null,
          },
        ],
        'hasMore': false,
        'totalCount': 1,
        'totalUnreadCount': 0,
      };
      f.overrides['POST /channels/ca/read-all'] = (_) => {
        'maxReadSeq': 1,
        'readStateVersion': 1,
      };
      await f.mount(tester, theme, 390, uri: Uri.parse('/s/alpha/channel/ca'));
      await f.flush(tester);
      await finishBackTransition(tester);
      final source = f.workspace(tester);
      Future<void> expectDraft(String text) async {
        expect(
          tester.widget<TextField>(composeField('ca')).controller!.text,
          text,
        );
        expect(source.drafts['ca'], text);
      }

      await tester.enterText(composeField('ca'), 'From normal Chat 草稿');
      await tester.pump();
      await expectDraft('From normal Chat 草稿');
      tester.testTextInput.hide();
      await tester.tap(find.byKey(const Key('mobile-detail-back')));
      await f.flush(tester);
      await finishBackTransition(tester);
      await tester.tap(find.byKey(const Key('nav-activity')));
      await f.flush(tester);
      await finishBackTransition(tester);
      expect(source.location.route.name, 'activity');
      await tester.tap(find.byKey(const ValueKey('activity-channel-ca')));
      await f.flush(tester);
      await finishBackTransition(tester);
      expect(source.channel?.id, 'ca');
      await expectDraft('From normal Chat 草稿');
      await tester.enterText(composeField('ca'), 'Edited through Activity 活动');
      await tester.pump();
      await expectDraft('Edited through Activity 活动');
      tester.testTextInput.hide();
      for (var level = 0; level < 2; level++) {
        await tester.binding.handlePopRoute();
        await f.flush(tester);
        await finishBackTransition(tester);
      }
      await tester.tap(find.byKey(const ValueKey('sidebar-channel-ca')));
      await f.flush(tester);
      await finishBackTransition(tester);
      await expectDraft('Edited through Activity 活动');
      final pages = phonePages(tester);
      expect(pages, isNotEmpty);
      for (final page in pages) {
        expect(identical(page.controller, source), isTrue);
      }
      await f.close(tester);
    });
  }

  testWidgets(
    'one phone controller keeps each channel draft and Back paints the retained channel',
    (tester) async {
      final accepted = Completer<Map<String, dynamic>>();
      final f = RootFixture();
      f.overrides['GET /channels'] = (_) => [
        for (final id in ['ca', 'cb'])
          {
            'id': id,
            'name': id,
            'type': 'channel',
            'serverId': 'a',
            'joined': true,
          },
      ];
      f.overrides['POST /v2/messages'] = (_) => accepted.future;
      await f.mount(
        tester,
        'brutal',
        390,
        uri: Uri.parse('/s/alpha/channel/ca'),
      );
      await f.flush(tester);
      await finishBackTransition(tester);
      final source = f.workspace(tester);
      unawaited(source.selectChannel(source.channels.first, navigate: false));
      await f.flush(tester);
      expect(find.text('Accepted a'), findsOneWidget);
      source.saveDraft('Channel A draft');
      expect(source.drafts['ca'], 'Channel A draft');
      final evaluations = f.adapter.calls
          .where((call) => call.path == '/feature-flags/evaluate')
          .length;

      unawaited(source.selectChannel(source.channels.last));
      await f.flush(tester);
      await finishBackTransition(tester);
      expect(source.channel?.id, 'cb');
      expect(source.drafts['ca'], 'Channel A draft');
      source.saveDraft('Channel B draft');
      expect(source.drafts['cb'], 'Channel B draft');
      expect(source.drafts['ca'], 'Channel A draft');
      final pages = phonePages(tester);
      expect(pages.length, greaterThanOrEqualTo(2));
      for (final page in pages) {
        expect(identical(page.controller, source), isTrue);
      }
      expect(
        f.adapter.calls
            .where((call) => call.path == '/feature-flags/evaluate')
            .length,
        evaluations,
      );

      final sending = source.send('Pending B', randomId: 'route-owner-send');
      await f.flush(tester);
      expect(source.messageDomain.timeline().last.content, 'Pending B');
      expect(pageShows(tester, 'cb', 'Pending B'), isTrue);
      final key = source.messageDomain.messageKey(
        source.messageDomain.timeline().last,
      );
      accepted.complete({
        'message': {
          'id': 'accepted-b',
          'channelId': 'cb',
          'seq': '2',
          'senderId': 'alice',
          'senderName': 'Alice',
          'content': 'Pending B',
          'randomId': 'route-owner-send',
          'createdAt': '2026-10-11T00:00:00Z',
        },
      });
      await f.flush(tester);
      expect(await tester.runAsync(() => sending), isTrue);
      expect(source.messageDomain.timeline().last.id, 'accepted-b');
      expect(
        source.messageDomain.messageKey(source.messageDomain.timeline().last),
        key,
      );
      expect(f.client.disposalCount, 0);
      // The first Back frame paints retained A while the source may still be
      // resolving B. It must not paint B on the active page.
      final seen = <String>[];
      f.onFrame = () {
        if (source.location.entityId != 'ca') return;
        expect(pageShows(tester, 'ca', 'Accepted b'), isFalse);
        expect(pageShows(tester, 'ca', 'Pending B'), isFalse);
        if (pageShows(tester, 'ca', 'Accepted a')) seen.add('Accepted a');
      };
      await tester.binding.handlePopRoute();
      await f.flush(tester);
      await finishBackTransition(tester);
      expect(seen, isNotEmpty);
      expect(source.location.entityId, 'ca');
      expect(source.drafts['ca'], 'Channel A draft');
      expect(source.drafts['cb'], 'Channel B draft');
      f.onFrame = null;
      await f.close(tester);
    },
  );
}
