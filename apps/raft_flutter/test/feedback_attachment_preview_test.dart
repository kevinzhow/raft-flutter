// Settings > Feedback: a ticket's screenshot and a picked, not yet sent one
// open in a lightbox (Web AboutFeedbackDialog onOpenAttachment /
// onOpenPendingAttachment) instead of staying inert rows.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_feedback_store.dart';
import 'package:raft_flutter/features/source_feedback_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'source_feedback_store_test.dart' as fx;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAGUlEQVR4nGP8V7uCgRTARJLqUQ2jGoaUBgC7qgJDBU0aZAAAAABJRU5ErkJggg==',
);

Map<String, dynamic> _withAttachment() => {
  ...fx.detail(fx.first),
  'attachments': [
    {
      'id': 'att-1',
      'filename': 'shot.png',
      'content_type': 'image/png',
      'size_bytes': 2048,
    },
  ],
};

Future<SourceFeedbackStore> _store({
  List<SourceFeedbackFile> picked = const [],
}) async {
  final store = SourceFeedbackStore(
    authority: () => 'account',
    newId: () => 'id-${picked.length}',
    get: (path, {query}) async => path == '/product-feedback/tickets'
        ? fx.page([fx.ticket(fx.first)])
        : _withAttachment(),
    post: (path, {json, form, onProgress, abort}) async => {'id': fx.first},
  );
  await store.loadList();
  return store;
}

Future<void> _pump(
  WidgetTester t,
  SourceFeedbackStore store, {
  FeedbackAttachmentLoader? load,
  List<SourceFeedbackFile> picked = const [],
}) async {
  t.view
    ..physicalSize = const Size(1000, 1000)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      builder: (context, child) => RaftToastHost(child: child!),
      home: Scaffold(
        body: SourceFeedbackProjectionView(
          store: store,
          loadAttachment: load,
          pickFiles: () async => picked,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> _openTicket(WidgetTester t) async {
  await t.tap(find.byKey(ValueKey('feedback-ticket-${fx.first}')));
  await t.pumpAndSettle();
}

Future<void> _settleImage(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('a sent screenshot is read with the session and opens', (
    t,
  ) async {
    final reads = <(String, String)>[];
    final store = await _store();
    addTearDown(store.dispose);
    await _pump(
      t,
      store,
      load: (ticket, attachment) async {
        reads.add((ticket, attachment));
        return _png;
      },
    );
    await _openTicket(t);
    expect(find.text('shot.png · 2 kB'), findsOneWidget);

    await t.tap(find.byKey(ValueKey('feedback-attachment-${fx.first}-0')));
    await t.pump();
    await _settleImage(t);

    expect(reads, [(fx.first, 'att-1')]);
    expect(find.byType(RaftAttachmentLightbox), findsOneWidget);
    expect(find.text('shot.png'), findsOneWidget, reason: 'the title');
    expect(find.byTooltip('Download'), findsOneWidget);
    await t.tap(find.byTooltip('Close preview'));
    await t.pumpAndSettle();
    expect(find.byType(RaftAttachmentLightbox), findsNothing);
  });

  testWidgets('a screenshot that cannot be read says so and shows nothing', (
    t,
  ) async {
    final store = await _store();
    addTearDown(store.dispose);
    await _pump(t, store, load: (_, _) async => throw StateError('offline'));
    await _openTicket(t);
    await t.tap(find.byKey(ValueKey('feedback-attachment-${fx.first}-0')));
    await t.pump();
    await t.pump();
    expect(find.byType(RaftAttachmentLightbox), findsNothing);
    expect(
      find.text('The attachment could not be opened. Try again.'),
      findsOneWidget,
    );
    await t.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('without a loader the rows stay plain text', (t) async {
    final store = await _store();
    addTearDown(store.dispose);
    await _pump(t, store);
    await _openTicket(t);
    expect(find.text('shot.png · 2 kB'), findsOneWidget);
    expect(
      find.byKey(ValueKey('feedback-attachment-${fx.first}-0')),
      findsNothing,
    );
  });

  testWidgets('a picked screenshot can be looked at before it is sent', (
    t,
  ) async {
    final picked = [
      SourceFeedbackFile(
        name: 'draft.png',
        contentType: 'image/png',
        bytes: _png,
      ),
    ];
    final store = await _store(picked: picked);
    addTearDown(store.dispose);
    await _pump(t, store, load: (_, _) async => _png, picked: picked);
    await _openTicket(t);
    await t.tap(find.byTooltip('Attach image'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('feedback-pending-open-id-1')));
    await t.pump();
    await _settleImage(t);
    expect(find.byType(RaftAttachmentLightbox), findsOneWidget);
    expect(find.text('draft.png'), findsWidgets);
    await t.tap(find.byTooltip('Close preview'));
    await t.pumpAndSettle();
    expect(find.byType(RaftAttachmentLightbox), findsNothing);
    expect(store.replyAttachments, hasLength(1), reason: 'still attached');
    await t.pumpWidget(const SizedBox());
    await _settleImage(t);
  });
}
