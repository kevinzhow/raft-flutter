// Settings > Feedback write flows through the real view: New feedback,
// reply, Close ticket (conversation and inbox row), failures and the
// first-frame preview of an opened ticket.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_feedback_store_test.dart' as fx;

class _Harness {
  _Harness({List<Map<String, dynamic>>? tickets})
    : tickets = tickets ?? [fx.ticket(fx.first), fx.ticket(fx.second)];
  final List<Map<String, dynamic>> tickets;
  final details = <String, Map<String, dynamic>>{};
  final posts = <(String, Map<String, dynamic>?, SourceFeedbackForm?)>[];
  Object? Function(String path) answer = (_) => {'id': fx.second};
  Completer<dynamic>? detailGate;
  List<SourceFeedbackFile> picked = const [];
  var ids = 0;

  late final store = SourceFeedbackStore(
    authority: () => 'account',
    newId: () => 'id-${++ids}',
    get: (path, {query}) async {
      if (path == '/product-feedback/tickets') return fx.page(tickets);
      if (detailGate != null) await detailGate!.future;
      final id = path.split('/').last;
      return details[id] ?? fx.detail(id);
    },
    post: (path, {json, form, onProgress, abort}) async {
      posts.add((path, json, form));
      final value = answer(path);
      if (value is Future) return await value;
      if (value is Exception) throw value;
      return value;
    },
  );

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    await store.loadList();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark),
        home: Scaffold(
          body: SourceFeedbackProjectionView(
            store: store,
            pickFiles: () async => picked,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, dynamic> _closed(String id, String reason) => {
  ...fx.detail(id),
  'ticket': {
    ...fx.ticket(id, status: 'closed', unread: false),
    'closure_reason': reason,
  },
};

void main() {
  testWidgets('New feedback: Submit waits for text, posts the form and opens '
      'the created ticket', (tester) async {
    final h = _Harness(tickets: [fx.ticket(fx.first)]);
    await h.pump(tester);
    expect(find.text('New Feedback'), findsOneWidget);
    await tester.tap(_key('feedback-new'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like us to know?'), findsWidgets);
    expect(find.text('Up to 3 images.'), findsOneWidget);
    expect(find.text('0/10000'), findsOneWidget);
    await tester.tap(_key('feedback-new-submit'));
    await tester.pump();
    expect(h.posts, isEmpty);
    await tester.tap(_key('feedback-kind-bug'));
    await tester.enterText(_key('feedback-new-message'), 'Paste crashes');
    await tester.pump();
    expect(find.text('13/10000'), findsOneWidget);
    h.details[fx.second] = {
      ...fx.detail(fx.second),
      'ticket': {
        ...fx.ticket(fx.second, unread: false),
        'kind': 'bug',
        'message': 'Paste crashes',
      },
    };
    await tester.tap(_key('feedback-new-submit'));
    await tester.pumpAndSettle();
    expect(h.posts.single.$1, '/product-feedback');
    expect(h.posts.single.$3!.fields['type'], 'problem');
    expect(h.posts.single.$3!.fields['message'], 'Paste crashes');
    expect(find.text('My Feedback'), findsOneWidget);
    expect(find.text('Paste crashes'), findsOneWidget);
    expect(_key('feedback-reply-input'), findsOneWidget);
    await tester.tap(_key('feedback-back'));
    await tester.pumpAndSettle();
    final cards = tester
        .widgetList<RaftFeedbackTicketCard>(find.byType(RaftFeedbackTicketCard))
        .map((card) => card.ticket.id);
    expect(cards.first, fx.second);
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  testWidgets('a failed create shows the safe error and keeps the message; '
      'Cancel aborts an in-flight submit', (tester) async {
    final h = _Harness()
      ..answer = (_) => const SourceFeedbackFailure(SourceFeedbackError.invalid);
    await h.pump(tester);
    await tester.tap(_key('feedback-new'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('feedback-new-message'), 'Idea');
    await tester.pump();
    await tester.tap(_key('feedback-new-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Check the feedback details and try again.'), findsOne);
    expect(find.text('Idea'), findsWidgets);
    final pending = Completer<Object?>();
    h.answer = (_) => pending.future;
    await tester.tap(_key('feedback-new-submit'));
    await tester.pump();
    expect(find.text('Submitting…'), findsOneWidget);
    await tester.tap(_key('feedback-new-cancel'));
    await tester.pump();
    expect(find.text('Submit'), findsOneWidget);
    expect(_key('feedback-new-message'), findsOneWidget);
    pending.complete({'id': fx.second});
    await tester.pumpAndSettle();
    expect(_key('feedback-new-message'), findsOneWidget);
    await tester.tap(_key('feedback-new-cancel'));
    await tester.pumpAndSettle();
    expect(_key('feedback-inbox'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  testWidgets('attachments: the picker adds images, a rejected file explains '
      'why and adds nothing', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(_key('feedback-new'));
    await tester.pumpAndSettle();
    h.picked = [
      SourceFeedbackFile(
        name: 'notes.svg',
        contentType: 'image/svg+xml',
        bytes: Uint8List(3),
      ),
    ];
    await tester.tap(_key('feedback-attach-image'));
    await tester.pumpAndSettle();
    expect(find.text('notes.svg is not a supported image.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    h.picked = [
      SourceFeedbackFile(
        name: 'shot.gif',
        contentType: 'image/gif',
        bytes: Uint8List(0),
        declaredSize: sourceFeedbackMaxAttachmentBytes + 1,
      ),
    ];
    await tester.tap(_key('feedback-attach-file'));
    await tester.pumpAndSettle();
    expect(find.text('shot.gif is larger than 10 MB.'), findsOneWidget);
    expect(h.store.newAttachments, isEmpty);
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  testWidgets('opening a ticket shows the row preview first, then the '
      'conversation; Enter sends a reply, Shift+Enter does not', (
    tester,
  ) async {
    final h = _Harness()..answer = (_) => {'id': 'c'};
    h.detailGate = Completer<void>();
    await h.pump(tester);
    await tester.tap(_key('feedback-ticket-${fx.first}'));
    await tester.pump();
    // First frame: the ticket message from the inbox row, no skeleton.
    expect(find.text('Fixture ${fx.first}'), findsOneWidget);
    expect(find.byType(RaftSkeleton), findsNothing);
    h.detailGate!.complete();
    h.detailGate = null;
    await tester.pumpAndSettle();
    expect(find.text('Fixture ${fx.first}'), findsOneWidget);
    await tester.enterText(_key('feedback-reply-input'), 'First line');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(h.posts, isEmpty);
    h.details[fx.first] = fx.detail(
      fx.first,
      comments: [
        {...fx.reply('mine', 3000, body: 'First line'), 'author_type': 'reporter'},
      ],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.posts.single.$1, '/product-feedback/tickets/${fx.first}/comments');
    expect(_key('feedback-comment-mine'), findsOneWidget);
    expect(
      tester.widget<TextField>(_key('feedback-reply-input')).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  testWidgets('a failed reply keeps the draft and shows the banner', (
    tester,
  ) async {
    final h = _Harness()
      ..answer = (_) =>
          const SourceFeedbackFailure(SourceFeedbackError.rateLimited);
    await h.pump(tester);
    await tester.tap(_key('feedback-ticket-${fx.first}'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('feedback-reply-input'), 'Hello');
    await tester.pump();
    await tester.tap(_key('feedback-reply-send'));
    await tester.pumpAndSettle();
    expect(
      find.text('Too many feedback requests. Try again later.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(_key('feedback-reply-input')).controller!.text,
      'Hello',
    );
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('close from the conversation (dark: $dark): the reason menu, '
        'a busy dialog that cannot be dismissed, then the closed ticket', (
      tester,
    ) async {
      final h = _Harness();
      final pending = Completer<Object?>();
      h.answer = (_) => pending.future;
      await h.pump(tester, dark: dark);
      await tester.tap(_key('feedback-ticket-${fx.first}'));
      await tester.pumpAndSettle();
      await tester.tap(_key('feedback-close-caret'));
      await tester.pumpAndSettle();
      expect(_key('feedback-close-menu'), findsOneWidget);
      expect(find.text('Confirm resolved and close.'), findsOneWidget);
      await tester.tap(_key('feedback-close-reason-completed'));
      await tester.pumpAndSettle();
      expect(find.text('Issue resolved — close this ticket?'), findsOneWidget);
      await tester.tap(_key('feedback-close-confirm'));
      await tester.pump();
      expect(h.posts.single.$2, {'reason': 'completed'});
      await tester.tap(_key('feedback-close-cancel'), warnIfMissed: false);
      await tester.pump();
      expect(_key('feedback-close-dialog'), findsOneWidget);
      h.details[fx.first] = _closed(fx.first, 'completed');
      pending.complete({'ok': true});
      await tester.pumpAndSettle();
      expect(_key('feedback-close-dialog'), findsNothing);
      expect(_key('feedback-reply-input'), findsNothing);
      expect(_key('feedback-close-main'), findsNothing);
      expect(find.text('Closed as Completed'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      h.store.dispose();
    });
  }

  testWidgets('a failed close keeps the dialog open with the error; Cancel '
      'then dismisses it', (tester) async {
    final h = _Harness()
      ..answer = (_) =>
          const SourceFeedbackFailure(SourceFeedbackError.unavailable);
    await h.pump(tester);
    await tester.tap(_key('feedback-ticket-${fx.first}'));
    await tester.pumpAndSettle();
    await tester.tap(_key('feedback-close-main'));
    await tester.pumpAndSettle();
    expect(
      find.text('No longer need help — close this ticket?'),
      findsOneWidget,
    );
    await tester.tap(_key('feedback-close-confirm'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: _key('feedback-close-dialog'),
        matching: find.text("Couldn't load feedback. Try again."),
      ),
      findsOneWidget,
    );
    await tester.tap(_key('feedback-close-cancel'));
    await tester.pumpAndSettle();
    expect(_key('feedback-close-dialog'), findsNothing);
    expect(_key('feedback-reply-input'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });

  testWidgets('close from an inbox row confirms in place and keeps the row '
      'order; the row without a split stays openable', (tester) async {
    final h = _Harness(
      tickets: [fx.ticket(fx.first), fx.ticket(fx.second, status: 'resolved')],
    )..answer = (_) => {'ok': true};
    h.details[fx.second] = _closed(fx.second, 'completed');
    await h.pump(tester);
    await tester.tap(_key('feedback-close-main-${fx.second}'));
    await tester.pumpAndSettle();
    expect(find.text('Issue resolved — close this ticket?'), findsOneWidget);
    expect(h.store.route, SourceFeedbackRoute.inbox);
    await tester.tap(_key('feedback-close-confirm'));
    await tester.pumpAndSettle();
    expect(h.posts.single.$1, '/product-feedback/tickets/${fx.second}/close');
    expect(_key('feedback-close-main-${fx.second}'), findsNothing);
    expect(_key('feedback-close-main-${fx.first}'), findsOneWidget);
    final ids = tester
        .widgetList<RaftFeedbackTicketCard>(find.byType(RaftFeedbackTicketCard))
        .map((card) => card.ticket.id);
    expect(ids, [fx.first, fx.second]);
    await tester.tap(_key('feedback-ticket-${fx.second}'));
    await tester.pumpAndSettle();
    expect(h.store.selectedId, fx.second);
    await tester.pumpWidget(const SizedBox());
    h.store.dispose();
  });
}
