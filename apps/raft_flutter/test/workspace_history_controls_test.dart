import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/workspace_history_controls.dart';

import 'mounted_message_navigation_test.dart' show pageFixture, mountPage;

void main() {
  for (final language in ['en', 'zh']) {
    for (final width in [856.0, 1280.0]) {
      testWidgets(
        'history buttons have localized accessible names/$language/$width',
        (t) async {
          final handle = t.ensureSemantics();
          final (w, _) = await pageFixture(t);
          // Bind the initial location before adding the second history entry.
          final initial = w.location;
          w.setSection('home');
          expect(w.navigation.entries.first.uri, initial.uri);
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          Future<void> mount() => t.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('zh')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: raftTheme(),
              home: Scaffold(body: WorkspaceHistoryControls(controller: w)),
            ),
          );
          void button(String label, {required bool enabled}) {
            final finder = find.bySemanticsLabel(label);
            expect(finder, findsOneWidget);
            final data = t.getSemantics(finder).getSemanticsData();
            expect(data.label, label);
            expect(data.flagsCollection.isButton, isTrue);
            expect(data.hasAction(SemanticsAction.tap), enabled);
          }

          final back = language == 'zh' ? '后退' : 'Go back';
          final forward = language == 'zh' ? '前进' : 'Go forward';
          final history = language == 'zh' ? '历史' : 'History';
          await mount();
          await t.pumpAndSettle();
          button(history, enabled: true);
          // The real header chooses Button's on-frame compound, not the
          // default 32px icon. Its source border box and glyph are 36/20.
          for (final key in [
            'topbar-history',
            if (width >= 1000) ...['topbar-back', 'topbar-forward'],
          ]) {
            final action = find.byKey(Key(key));
            final face = find
                .descendant(of: action, matching: find.byType(RaftRecipeBox))
                .first;
            expect(t.getSize(face), const Size.square(36), reason: key);
            final glyph = find.descendant(
              of: action,
              matching: find.byType(RaftIcon),
            );
            expect(t.widget<RaftIcon>(glyph).size, 20, reason: key);
          }
          if (width >= 1000) {
            button(back, enabled: true);
            button(forward, enabled: false);
            // Both disabled and enabled navigation buttons keep their names.
            w.navigation.back();
            await mount();
            await t.pumpAndSettle();
            button(back, enabled: false);
            button(forward, enabled: true);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
          handle.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
    }
  }
  for (final width in [856.0, 1280.0]) {
    testWidgets('desktop history restores channels and forward branch/$width', (
      t,
    ) async {
      final (w, api) = await pageFixture(t);
      w.channels = [
        RaftChannel({'id': 'c1', 'name': 'first', 'joined': true}),
        RaftChannel({'id': 'c2', 'name': 'second', 'joined': true}),
      ];
      for (final id in ['c1', 'c2']) {
        api.routes['GET /messages/channel/$id'] = (_) => {
          'messages': [
            {
              'id': 'm-$id',
              'channelId': id,
              'seq': '1',
              'senderId': 'alice',
              'senderName': 'Alice',
              'content': 'Content of $id',
              'createdAt': '2026-10-25T00:00:00Z',
            },
          ],
          'hasMore': false,
        };
      }
      await t.runAsync(() => w.selectChannel(w.channels.first));
      await mountPage(t, w, false, width: width);
      await t.runAsync(() => w.selectChannel(w.channels.last));
      await t.pumpAndSettle();
      expect(find.text('Content of c2'), findsWidgets);
      final depth = w.navigation.entries.length, index = w.navigation.index;
      Future<void> press(String key, String label) async {
        if (width < 1000) {
          await t.tap(find.byKey(const Key('topbar-history')));
          await t.pumpAndSettle();
          await t.tap(find.text(label).last);
        } else {
          await t.tap(find.byKey(Key(key)));
        }
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
      }

      await press('topbar-back', 'Go back');
      expect(w.navigation.index, index - 1);
      expect(w.location.entityId, 'c1');
      expect(w.channel?.id, 'c1');
      expect(find.text('Content of c1', findRichText: true), findsWidgets);
      await press('topbar-forward', 'Go forward');
      expect(w.navigation.index, index);
      expect(w.channel?.id, 'c2');
      expect(find.text('Content of c2'), findsWidgets);
      expect(w.navigation.entries, hasLength(depth));
      await t.tap(find.byKey(const Key('topbar-history')));
      await t.pumpAndSettle();
      await t.tap(find.text('#first').last);
      await t.pumpAndSettle();
      expect(w.channel?.id, 'c1');
      expect(w.navigation.entries, hasLength(depth));
      expect(w.navigation.entries.last.entityId, 'c2');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
  for (final focusReply in [false, true]) {
    testWidgets('history restores a side thread and its focus/$focusReply', (
      t,
    ) async {
      final (w, api) = await pageFixture(t);
      final parent = {
        'id': 'parent',
        'channelId': 'c1',
        'seq': '1',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content': 'Parent message',
        'createdAt': '2026-10-25T00:00:00Z',
      };
      final reply = {
        ...parent,
        'id': 'reply',
        'channelId': 't1',
        'content': 'Thread reply',
      };
      w.channels = [
        w.channel!,
        RaftChannel({'id': 'c2', 'name': 'second', 'joined': true}),
      ];
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [parent],
      };
      api.routes['GET /messages/channel/c2'] = (_) => {
        'messages': [
          {
            ...parent,
            'id': 'second',
            'channelId': 'c2',
            'content': 'Second channel message',
          },
        ],
      };
      api.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 't1',
      };
      api.routes['GET /messages/channel/t1'] = (_) => {
        'messages': [reply],
      };
      api.routes['GET /messages/context/parent'] = (_) => {
        'channelId': 'c1',
        'messages': [parent],
      };
      api.routes['GET /messages/context/reply'] = (_) => {
        'channelId': 't1',
        'messages': [reply],
      };
      await t.runAsync(() => w.selectChannel(w.channels.first));
      // A parent permalink's msg is not a focused reply. A reply permalink
      // uses msg for the thread and must not load it into the main channel.
      await t.runAsync(() => w.jumpToMessage('c1', 'parent'));
      await t.runAsync(
        () => w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'parent',
          focusedMessageId: focusReply ? 'reply' : null,
        ),
      );
      await mountPage(t, w, false, width: 1280);
      expect(find.byType(RaftThreadHeader), findsOneWidget);
      expect(find.text('Thread reply', findRichText: true), findsWidgets);
      await t.runAsync(() => w.selectChannel(w.channels.last));
      await t.pumpAndSettle();
      final depth = w.navigation.entries.length;
      final returned = w.navigation.entries[w.navigation.index - 1];
      api.calls.clear();
      expect(returned.thread?.itemId, 'parent');
      await t.tap(find.byKey(const Key('topbar-back')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await t.pumpAndSettle();
      expect(w.location.uri, returned.uri);
      expect(w.channel?.id, 'c1');
      expect(w.threadIdentity?.parentMessageId, 'parent');
      expect(w.messageDomain.contextLoadError, isNull);
      expect(
        api.calls.where(
          (c) =>
              c.path == '/messages/context/reply' &&
              c.queryParameters['channelId'] == 'c1',
        ),
        isEmpty,
      );
      expect(w.threadIdentity?.focusedMessageId, focusReply ? 'reply' : null);
      expect(find.byType(RaftThreadHeader), findsOneWidget);
      expect(find.text('Thread reply', findRichText: true), findsWidgets);
      expect(w.navigation.entries, hasLength(depth));
      await t.tap(find.byKey(const Key('topbar-forward')));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await t.pumpAndSettle();
      expect(w.channel?.id, 'c2');
      expect(find.byType(RaftThreadHeader), findsNothing);
      expect(
        find.text('Second channel message', findRichText: true),
        findsWidgets,
      );
      expect(w.navigation.entries, hasLength(depth));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }
  testWidgets(
    'stale history cannot cross a workspace epoch or replace its entry',
    (t) async {
      final (w, _) = await pageFixture(t);
      final start = w.location;
      w.setSection('home');
      final authority = w.navigationAuthority;
      final index = w.navigation.index;
      // The observed menu entry is replaced before its delayed action runs.
      w.navigation.navigate(
        RaftLocation.at(serverSlug: start.serverSlug, route: RaftRoute.search),
        kind: RaftNavigationKind.replace,
      );
      final current = w.location;
      await visitWorkspaceHistory(
        w,
        index,
        authority: authority,
        expectedUri: RaftLocation.at(
          serverSlug: start.serverSlug,
          route: RaftRoute.home,
        ).uri,
      );
      expect(w.location.uri, current.uri);
      w.server = RaftRecord({'id': 'other', 'slug': 'other', 'role': 'owner'});
      final next = w.location;
      await visitWorkspaceHistory(
        w,
        0,
        authority: authority,
        expectedUri: start.uri,
      );
      expect(w.location.uri, next.uri);
      expect(w.navigation.entries, hasLength(1));
    },
  );
}
