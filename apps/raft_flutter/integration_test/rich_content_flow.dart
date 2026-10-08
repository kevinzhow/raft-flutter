import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> verifyRichContent(
  WidgetTester tester,
  WorkspaceController w,
  Future<void> Function(String) capture,
) async {
  const source = 'flowchart LR\n  A[中文输入] --> B[日本語確認]';
  final marker = DateTime.now().microsecondsSinceEpoch;
  final content =
      'Native rich message $marker\n\n**Markdown** and `code`\n\n```mermaid\n$source\n```';
  await w.send(content);
  final message = w.messages.singleWhere((m) => m.content == content);
  await w.jumpToMessage(w.channel!.id, message.id);
  for (
    var i = 0;
    i < 50 && find.byKey(ValueKey('message-${message.id}')).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final tile = find.byKey(ValueKey('message-${message.id}'));
  for (var i = 0; i < 100; i++) {
    if (find
        .descendant(of: tile, matching: find.byType(RaftMermaidBlock))
        .evaluate()
        .isNotEmpty) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (find
      .descendant(of: tile, matching: find.byType(RaftMermaidBlock))
      .evaluate()
      .isEmpty) {
    final chats = find
        .byType(Chat)
        .evaluate()
        .map((e) => e.widget as Chat)
        .toList();
    final slivers = find.byType(SliverAnimatedList).evaluate().toList();
    final lists = find.byType(ChatAnimatedList).evaluate().length;
    final positions = find
        .byType(CustomScrollView)
        .evaluate()
        .expand((e) {
          final controller = (e.widget as CustomScrollView).controller;
          return controller?.positions ?? const <ScrollPosition>[];
        })
        .map(
          (p) => {
            'pixels': p.pixels,
            'min': p.minScrollExtent,
            'max': p.maxScrollExtent,
            'viewport': p.viewportDimension,
          },
        )
        .toList();
    final geometry = slivers.map((e) {
      final render = e.findRenderObject();
      return render is RenderSliver
          ? {
              'paint': render.geometry?.paintExtent,
              'scroll': render.geometry?.scrollExtent,
              'layout': render.geometry?.layoutExtent,
            }
          : <String, Object?>{};
    }).toList();
    debugPrint(
      'Rich render diagnostic: workspaceRows=${w.messages.length} '
      'workspaceTarget=${w.messages.any((m) => m.id == message.id)} '
      'loading=${w.channelLoading} window=${w.channelGeneration} '
      'highlightMatches=${w.highlightedMessageId == message.id} '
      'errorPresent=${w.error != null} lists=$lists '
      'adapterRows=${chats.map((c) => c.chatController.messages.length).toList()} '
      'adapterTargets=${chats.map((c) => c.chatController.messages.any((m) => m.id == message.id)).toList()} '
      'sliverRows=${slivers.map((e) => (e.widget as SliverAnimatedList).initialItemCount).toList()} '
      'positions=$positions geometry=$geometry',
    );
    await capture('linux-rich-loading-failure');
  }
  expect(
    find.descendant(of: tile, matching: find.byType(RaftMermaidBlock)),
    findsOneWidget,
  );
  Finder action(String tooltip) =>
      find.descendant(of: tile, matching: find.byTooltip(tooltip));
  await tester.ensureVisible(action('Show source'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(action('Show source'));
  await tester.pump(const Duration(milliseconds: 300));
  expect(
    find.descendant(of: tile, matching: find.text(source)),
    findsOneWidget,
  );
  await tester.tap(action('Copy code'));
  await tester.pump(const Duration(milliseconds: 300));
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  expect(clipboard?.text, source);
  await tester.tap(action('Show diagram'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(action('Expand diagram'));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(Dialog), findsOneWidget);
  expect(
    find.text('Unable to render this diagram. The source is shown below.'),
    findsNothing,
  );
  await capture('linux-native-mermaid');
  await tester.tap(
    find.descendant(of: find.byType(Dialog), matching: find.byTooltip('Close')),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
