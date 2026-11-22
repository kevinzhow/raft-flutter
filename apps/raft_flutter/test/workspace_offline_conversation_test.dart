import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

void main() {
  testWidgets(
    'cached conversation stays visible and becomes writable on recovery',
    (tester) async {
      final (workspace, api) = await pageFixture(tester);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final cached = {
        'id': 'cached-message',
        'channelId': 'c1',
        'seq': '1',
        'senderId': 'alice',
        'senderName': 'Alice',
        'senderType': 'user',
        'content': 'Previously downloaded message',
        'createdAt': '2026-11-22T08:00:00Z',
      };
      final messages = workspace.messageDomain;
      messages.ledger.ingest([
        cached,
      ], expectedGeneration: messages.ledger.generation);
      messages.visibleIds['c1'] = {'cached-message'};
      api.routes['GET /announcements/active'] = (_) => null;
      api.routes['GET /messages/channel/c1'] = (_) => {
        'messages': [cached],
      };
      api.routes['GET /auth/me'] = (_) => (503, {'error': 'Offline'});
      api.routes['POST /v2/messages'] = (request) => {
        'message': {
          ...cached,
          'id': 'sent-message',
          'seq': '2',
          'content': request.data['content'],
          'randomId': request.data['randomId'],
        },
      };
      expect(await tester.runAsync(workspace.client.retrySession), isFalse);
      await mountPage(tester, workspace, false, width: 1280);

      final banner = find.byKey(const Key('offline-messages-notice'));
      final previous = find.text(
        'Previously downloaded message',
        findRichText: true,
      );
      final composer = find.byType(RaftComposer);
      final field = find.descendant(
        of: composer,
        matching: find.byType(TextField),
      );
      final send = find.byWidgetPredicate(
        (widget) =>
            widget is RaftComposerAction && widget.glyph == RaftGlyph.send,
      );
      expect(previous, findsOneWidget);
      expect(banner, findsOneWidget);
      expect(
        find.descendant(
          of: banner,
          matching: find.text(
            "Messages can't be opened right now. They load again once you're back online.",
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).enabled, isFalse);
      await tester.tap(send);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(await workspace.send('Blocked attempt'), isFalse);
      expect(api.calls.where((call) => call.path == '/v2/messages'), isEmpty);

      api.routes['GET /auth/me'] = (_) => {'id': 'alice'};
      expect(await tester.runAsync(workspace.client.retrySession), isTrue);
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(previous, findsOneWidget);
      await tester.enterText(field, 'Sent after recovery');
      await tester.pump();
      await tester.tap(send);
      for (
        var frame = 0;
        frame < 60 && !messages.messages.any((row) => row.id == 'sent-message');
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      final request = api.calls.singleWhere(
        (call) => call.path == '/v2/messages',
      );
      expect(request.data['content'], 'Sent after recovery');
      final accepted = messages.messages.singleWhere(
        (row) => row.id == 'sent-message',
      );
      expect(accepted.content, 'Sent after recovery');
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
