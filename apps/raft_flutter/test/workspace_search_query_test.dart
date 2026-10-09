import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show pageFixture, mountPage, frames, waitForPainted;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        '$family/$dark width=$width actual Search commits q, preserves raw input/cursor and pauses IME',
        (tester) async {
          final (w, api) = await pageFixture(tester, section: 'search');
          w.navigation.navigate(
            RaftLocation.parse('/s/demo/search?q=seed&keep=accepted'),
            kind: RaftNavigationKind.replace,
          );
          await mountPage(tester, w, family, dark, width: width);
          final field = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == 'Search messages',
          );
          final count = w.navigation.entries.length,
              revision = w.navigationRevision;
          await tester.enterText(field, '  draft 中  ');
          await tester.pump();
          expect(w.location.query('q'), 'draft 中');
          expect(w.location.query('keep'), 'accepted');
          expect(w.navigation.entries.length, count);
          expect(w.navigationRevision, revision);
          final editor = tester.widget<TextField>(field).controller!;
          expect(editor.text, '  draft 中  ');
          await tester.tap(field);
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '  未确定  ',
              selection: TextSelection.collapsed(offset: 3),
              composing: TextRange(start: 2, end: 5),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(editor.text, '  未确定  ');
          expect(w.location.query('q'), 'draft 中');
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: '  未确定  ',
              selection: TextSelection.collapsed(offset: 3),
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(w.location.query('q'), '未确定');
          expect(editor.text, '  未确定  ');
          expect(editor.selection.baseOffset, 3);
          expect(w.navigation.entries.length, count);
          expect(w.navigationRevision, revision);
          await tester.enterText(field, '   ');
          await tester.pump();
          expect(w.location.query('q'), isNull);
          expect(w.location.query('keep'), 'accepted');
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '$family/$dark actual Search query preserves pending thread and adopts external query without stale overwrite',
      (tester) async {
        final (w, api) = await pageFixture(tester, section: 'search');
        w.navigation.navigate(
          RaftLocation.parse('/s/demo/search?q=needle&keep=accepted'),
          kind: RaftNavigationKind.replace,
        );
        final parent = Completer<Map<String, dynamic>>(),
            reply = Completer<Map<String, dynamic>>();
        addTearDown(() {
          if (!parent.isCompleted) parent.complete({'messages': []});
          if (!reply.isCompleted) reply.complete({'messages': []});
        });
        api.routes['GET /messages/search'] = (_) => {
          'results': [
            {
              ...message('reply', 't1'),
              'channelType': 'thread',
              'parentChannelId': 'c1',
              'parentMessageId': 'parent',
              'parentChannelName': 'test',
              'content': 'needle accepted reply',
            },
          ],
          'hasMore': false,
        };
        api.routes['GET /messages/context/parent'] = (_) => parent.future;
        api.routes['GET /messages/context/reply'] = (_) => reply.future;
        await mountPage(tester, w, family, dark);
        await tester.tap(find.byType(RaftSearchResultSurface).first);
        await frames(tester, () {});
        final revision = w.navigationRevision,
            count = w.navigation.entries.length;
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.hintText == 'Search messages',
        );
        await tester.enterText(field, 'changed');
        await frames(tester, () {});
        expect(w.location.query('q'), 'changed');
        expect(w.location.content?.id, 't1');
        expect(w.location.thread?.itemId, 'parent');
        expect(w.location.messageId, 'reply');
        expect(w.navigationRevision, revision);
        expect(w.navigation.entries.length, count);
        await tester.runAsync(() async {
          reply.complete({
            'messages': [message('reply', 't1')],
          });
          parent.complete({
            'messages': [message('parent', 'c1')],
          });
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await waitForPainted(tester, 'reply');
        expect(w.presentedThreadParent?.id, 'parent');
        final editor = tester.widget<TextField>(field).controller!;
        await tester.tap(field);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'uncommitted',
            selection: TextSelection.collapsed(offset: 5),
            composing: TextRange(start: 0, end: 11),
          ),
        );
        await tester.pump();
        w.navigation.navigate(
          w.location.withQuery({'q': 'external'}),
          kind: RaftNavigationKind.replace,
        );
        w.notifyListeners();
        await tester.pump();
        expect(editor.text, 'external');
        expect(editor.value.composing, TextRange.empty);
        await tester.pump(const Duration(milliseconds: 250));
        expect(w.location.query('q'), 'external');
        expect(w.location.query('keep'), 'accepted');
        expect(find.byType(ResourceView), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
