import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/message_image_export.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

/// Captures the actual selected-message PNG before cancellation; no fixture
/// pixels, OS picker, or save destination are supplied to this native flow.
Future<void> verifyMessageSelection(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  final marker = DateTime.now().microsecondsSinceEpoch;
  final body =
      'Selection export $marker\n\n**中文内容** and 日本語\n\n'
      '```mermaid\nflowchart LR\n A[Select] --> B[Review]\n```';
  await w.send(body);
  final message = w.messages.singleWhere((m) => m.content == body);
  await w.jumpToMessage(w.channel!.id, message.id);
  final tile = find.byKey(ValueKey('message-${message.id}'));
  for (var i = 0; i < 50 && tile.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (tile.evaluate().isEmpty) {
    for (final view in find.byType(RaftChatView).evaluate()) {
      final dynamic state = (view as StatefulElement).state;
      debugPrint(
        'Selection viewport diagnostic: role=${(view.widget as RaftChatView).thread} adapter=${state.adapter.messages.length} target=${state.adapter.messages.any((dynamic m) => m.id == message.id)} scope=${state.scope == w.channel?.id} locale=${Localizations.localeOf(view).languageCode} attached=${state.viewport.hasClients} offset=${state.viewport.hasClients ? state.viewport.offset : null} max=${state.viewport.hasClients ? state.viewport.position.maxScrollExtent : null}',
      );
    }
    debugPrint(
      'Selection context diagnostic: loaded=${w.messages.any((m) => m.id == message.id)} loading=${w.channelLoading} highlighted=${w.highlightedMessageId == message.id} rows=${w.messages.length}',
    );
    await capture('linux-failure-selection-context');
  }
  expect(tile, findsOneWidget, reason: 'The context target must be rendered.');
  final actions = find.descendant(
    of: tile,
    matching: find.byTooltip('Message actions'),
  );
  await tester.ensureVisible(actions);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(actions);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Select messages'));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(RaftSelectionToolbar), findsOneWidget);
  expect(find.text('1 selected'), findsOneWidget);
  await tester.tap(find.text('Copy Markdown'));
  await tester.pump(const Duration(milliseconds: 300));
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  expect(clipboard?.text, contains(body));
  final preview = find.text('Preview image');
  // Clipboard completion can enqueue a toast after the first pump; wait for
  // the actual overlay to leave before using the bottom toolbar target.
  for (var i = 0; i < 100; i++) {
    if (find.byType(SnackBar).evaluate().isEmpty &&
        preview.hitTestable().evaluate().isNotEmpty) {
      break;
    }
    final close = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byTooltip('Close'),
    );
    if (close.hitTestable().evaluate().isNotEmpty) {
      await tester.tap(close.hitTestable().first);
    }
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(find.byType(SnackBar), findsNothing);
  expect(preview.hitTestable(), findsOneWidget);
  await tester.tap(preview);
  for (
    var i = 0;
    i < 200 && find.byType(MessageImageReview).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(MessageImageReview), findsOneWidget);
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byType(MessageImageReview),
      matching: find.byType(Image),
    ),
  );
  final bytes = (image.image as MemoryImage).bytes;
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  expect(bytes.length, greaterThan(1000));
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, greaterThanOrEqualTo(480));
  expect(frame.image.height, greaterThan(100));
  frame.image.dispose();
  codec.dispose();
  // Toolbars are excluded from the rasterized clone and the native review
  // displays only the finished image with explicit export/cancel controls.
  expect(
    find.descendant(
      of: find.byType(MessageImageReview),
      matching: find.byTooltip('Show source'),
    ),
    findsNothing,
  );
  await capture('linux-message-selection-preview');
  await tester.tap(find.byTooltip('Close preview'));
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(MessageImageReview), findsNothing);
  expect(find.byType(RaftSelectionToolbar), findsOneWidget);
  expect(find.text('1 selected'), findsOneWidget);
  await tester.tap(
    find.descendant(
      of: find.byType(RaftSelectionToolbar),
      matching: find.byTooltip('Exit selection'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(RaftSelectionToolbar), findsNothing);
  expect(find.byType(RaftComposer), findsWidgets);
}
