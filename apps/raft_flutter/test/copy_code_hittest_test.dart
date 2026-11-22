import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart' show pageFixture, pageFrames;
import 'support/app_services_fixture.dart';

List<RenderObject> _hitPath(WidgetTester tester, Offset at) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, at, tester.view.viewId);
  return [
    for (final entry in result.path)
      if (entry.target is RenderObject) entry.target as RenderObject,
  ];
}

bool _isDescendantOrSelf(RenderObject candidate, RenderObject ancestor) {
  for (RenderObject? cur = candidate; cur != null; cur = cur.parent) {
    if (identical(cur, ancestor)) return true;
  }
  return false;
}

Map<String, Offset> _probePoints(Rect rect) {
  final dx = rect.width * 0.25;
  final dy = rect.height * 0.25;
  const edge = 2.0;
  return {
    'center': rect.center,
    'topLeftQ': rect.center + Offset(-dx, -dy),
    'topRightQ': rect.center + Offset(dx, -dy),
    'bottomLeftQ': rect.center + Offset(-dx, dy),
    'bottomRightQ': rect.center + Offset(dx, dy),
    'topEdge': Offset(rect.center.dx, rect.top + edge),
    'bottomEdge': Offset(rect.center.dx, rect.bottom - edge),
    'leftEdge': Offset(rect.left + edge, rect.center.dy),
    'rightEdge': Offset(rect.right - edge, rect.center.dy),
  };
}

String _describeTop(List<RenderObject> path) => path.isEmpty
    ? '<empty>'
    : '${path.first.runtimeType}(${path.first.debugCreator})';

void main() {
  String? lastClipboard;

  setUp(() {
    lastClipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            lastClipboard = (call.arguments as Map)['text'] as String?;
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': lastClipboard ?? ''};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const sampleCode =
      'const longLine = "的 pro something very long to overflow the code block horizontally";';

  List<Map<String, dynamic>> makeChannelMessages() => [
    for (var i = 1; i <= 15; i++)
      {
        ...row('m$i', 'c1', i),
        'createdAt': '2026-10-08T00:${i.toString().padLeft(2, '0')}:00Z',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': i == 15
            ? 'Intro paragraph\n\n```ts\n$sampleCode\n```\n\n先不配，等后续再看。'
            : 'Channel message $i with enough text to scroll.',
      },
  ];

  List<Map<String, dynamic>> makeThreadMessages({bool mermaid = false}) => [
    for (var i = 1; i <= 20; i++)
      {
        ...row('r$i', 't1', i),
        'createdAt': '2026-10-08T00:${i.toString().padLeft(2, '0')}:00Z',
        'senderId': i.isEven ? 'u1' : 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'content': i == 20
            ? (mermaid
                  ? 'Diagram below\n\n```mermaid\ngraph TD\n  A[Start] --> B[End]\n```\n\nDone.'
                  : 'Thread intro\n\n```ts\n$sampleCode\n```\n\n先不配，等后续再看。')
            : 'Thread reply $i to ensure scrolling and outline ticks.',
      },
  ];

  Future<WorkspaceController> mountWorkspace(
    WidgetTester tester, {
    required Size size,
    required List<Map<String, dynamic>> channelMessages,
    List<Map<String, dynamic>> threadMessages = const [],
    bool openThread = false,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    final (w, api) = await pageFixture(tester);
    w.messageDomain.ledger.ingest(
      channelMessages,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final m in channelMessages) m['id'] as String,
    };
    if (threadMessages.isNotEmpty) {
      w.messageDomain.threadSummaries = {
        channelMessages.last['id'] as String: {
          'replyCount': threadMessages.length,
        },
      };
    }
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    if (threadMessages.isNotEmpty) {
      final parentId = channelMessages.last['id'] as String;
      api.routes['GET /channels/c1/threads/$parentId'] = (_) => {
        'threadChannelId': 't1',
      };
      api.routes['GET /messages/channel/t1'] = (_) => {
        'messages': threadMessages,
      };
      api.routes['GET /messages/channel/t1/human-outline'] = (_) => {
        'items': [
          for (var i = 0; i < threadMessages.length; i++)
            {
              'id': threadMessages[i]['id'],
              'senderId': threadMessages[i]['senderId'] ?? 'bob',
              'senderType': 'user',
              'senderName': 'Bob',
              'content': 'Human message $i',
              'createdAt': threadMessages[i]['createdAt'],
              'seq': threadMessages[i]['seq'],
            },
        ],
        'hasMore': false,
      };
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.linux),
        builder: (context, child) =>
            Directionality(textDirection: textDirection, child: child!),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: const RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (openThread) {
      final parentId = channelMessages.last['id'] as String;
      await tester.tap(find.byKey(ValueKey('thread-replies-badge-$parentId')));
      await tester.runAsync(() async {
        for (var i = 0; i < 40 && w.messageDomain.state.threadLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await pageFrames(tester, () {});
    }
    return w;
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  void expectAllPointsHit(WidgetTester tester, Finder button, String label) {
    final box = tester.renderObject<RenderBox>(button);
    final rect = tester.getRect(button);
    for (final entry in _probePoints(rect).entries) {
      final path = _hitPath(tester, entry.value);
      expect(
        path.isNotEmpty && _isDescendantOrSelf(path.first, box),
        isTrue,
        reason:
            '$label [${entry.key}] at ${entry.value} (rect=$rect) was '
            'occluded by ${_describeTop(path)}',
      );
    }
  }

  Future<void> activateScrollbar(WidgetTester tester, Finder list) async {
    final center = tester.getCenter(list);
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 12)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, -12)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
  }

  for (final size in const [Size(1280, 900), Size(900, 800)]) {
    testWidgets(
      'thread with outline ticks ($size): Copy Code stays unoccluded and clickable after scroll',
      (tester) async {
        await mountWorkspace(
          tester,
          size: size,
          channelMessages: makeChannelMessages(),
          threadMessages: makeThreadMessages(),
          openThread: true,
        );

        final threadList = find.byKey(const ValueKey('chat-list-thread'));
        expect(threadList, findsOneWidget);
        expect(
          find.byKey(const ValueKey('thread-outline-tick-r20')),
          findsOneWidget,
        );

        await activateScrollbar(tester, threadList);

        final copyButton = find.descendant(
          of: threadList,
          matching: find.byTooltip('Copy Code'),
        );
        expect(copyButton, findsOneWidget);

        expectAllPointsHit(tester, copyButton, 'Thread Copy Code ($size)');

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);

        final rowRect = tester.getRect(
          find.ancestor(of: copyButton, matching: find.byType(RaftMessageRow)),
        );
        final codeRect = tester.getRect(
          find.ancestor(of: copyButton, matching: find.byType(RaftCodeBlock)),
        );
        final btnRect = tester.getRect(copyButton);

        await mouse.moveTo(rowRect.topLeft + const Offset(60, 20));
        await tester.pump(const Duration(milliseconds: 50));
        await mouse.moveTo(codeRect.centerLeft + const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 50));
        await mouse.moveTo(btnRect.center);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('raft-tooltip-surface')),
          findsOneWidget,
          reason: 'Copy Code tooltip must open when hovering button center',
        );

        lastClipboard = null;
        await mouse.down(btnRect.center);
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 50));
        expect(lastClipboard, sampleCode);
        expect(
          find.descendant(of: threadList, matching: find.byTooltip('Copied')),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 3));
        await activateScrollbar(tester, threadList);
        final updatedRect = tester.getRect(copyButton);
        final rightQuad =
            updatedRect.center +
            Offset(updatedRect.width * 0.25, updatedRect.height * 0.25);
        await mouse.moveTo(rightQuad);
        await tester.pump(const Duration(milliseconds: 50));
        lastClipboard = null;
        await mouse.down(rightQuad);
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 50));
        expect(lastClipboard, sampleCode);

        await finish(tester);
      },
    );
  }

  testWidgets(
    'thread with outline ticks: hovering Copy Code right edge does not self-occlude via scrollbar',
    (tester) async {
      await mountWorkspace(
        tester,
        size: const Size(1280, 900),
        channelMessages: makeChannelMessages(),
        threadMessages: makeThreadMessages(),
        openThread: true,
      );
      await tester.pump(const Duration(seconds: 2));

      final threadList = find.byKey(const ValueKey('chat-list-thread'));
      final copyButton = find.descendant(
        of: threadList,
        matching: find.byTooltip('Copy Code'),
      );
      final btnBox = tester.renderObject<RenderBox>(copyButton);
      final btnRect = tester.getRect(copyButton);
      final rightEdge = Offset(btnRect.right - 2, btnRect.center.dy);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(rightEdge);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();

      final path = _hitPath(tester, rightEdge);
      expect(
        path.isNotEmpty && _isDescendantOrSelf(path.first, btnBox),
        isTrue,
        reason:
            'Hovering Copy Code right edge must not self-occlude; top=${_describeTop(path)}',
      );
      expect(
        find.byKey(const ValueKey('raft-tooltip-surface')),
        findsOneWidget,
        reason: 'Tooltip must stay open while hovering Copy Code right edge',
      );

      lastClipboard = null;
      await mouse.down(rightEdge);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(lastClipboard, sampleCode);

      await finish(tester);
    },
  );

  testWidgets(
    'thread with outline ticks: Mermaid toolbar right-aligned actions stay unoccluded after scroll',
    (tester) async {
      await mountWorkspace(
        tester,
        size: const Size(1280, 900),
        channelMessages: makeChannelMessages(),
        threadMessages: makeThreadMessages(mermaid: true),
        openThread: true,
      );
      final threadList = find.byKey(const ValueKey('chat-list-thread'));
      await activateScrollbar(tester, threadList);

      for (final tip in const [
        'Copy Code',
        'Download Mermaid Diagram',
        'Expand Diagram',
      ]) {
        final btn = find.descendant(
          of: threadList,
          matching: find.byTooltip(tip),
        );
        expect(btn, findsOneWidget);
        expectAllPointsHit(tester, btn, 'Mermaid $tip');
      }

      await finish(tester);
    },
  );

  testWidgets(
    'main channel with active SelectionArea + tooltip + scroll: Copy Code copies cleanly',
    (tester) async {
      await mountWorkspace(
        tester,
        size: const Size(1280, 900),
        channelMessages: makeChannelMessages(),
      );
      final channelList = find.byKey(const ValueKey('chat-list-channel'));
      await activateScrollbar(tester, channelList);

      final copyButton = find.descendant(
        of: channelList,
        matching: find.byTooltip('Copy Code'),
      );
      expect(copyButton, findsOneWidget);
      expectAllPointsHit(tester, copyButton, 'Channel Copy Code');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      final codeRect = tester.getRect(
        find.ancestor(of: copyButton, matching: find.byType(RaftCodeBlock)),
      );
      await mouse.moveTo(codeRect.topLeft + const Offset(10, -10));
      await mouse.down(codeRect.topLeft + const Offset(10, -10));
      await mouse.moveTo(codeRect.topLeft + const Offset(90, -10));
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 300));

      final btnRect = tester.getRect(copyButton);
      await mouse.moveTo(btnRect.center);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('raft-tooltip-surface')),
        findsOneWidget,
      );

      lastClipboard = null;
      await mouse.down(btnRect.center);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(lastClipboard, sampleCode);

      await finish(tester);
    },
  );

  testWidgets(
    'RTL thread with outline ticks: Copy Code stays unoccluded after scroll',
    (tester) async {
      await mountWorkspace(
        tester,
        size: const Size(1280, 900),
        channelMessages: makeChannelMessages(),
        threadMessages: makeThreadMessages(),
        openThread: true,
        textDirection: TextDirection.rtl,
      );
      final threadList = find.byKey(const ValueKey('chat-list-thread'));
      await activateScrollbar(tester, threadList);

      final copyButton = find.descendant(
        of: threadList,
        matching: find.byTooltip('Copy Code'),
      );
      expect(copyButton, findsOneWidget);
      expectAllPointsHit(tester, copyButton, 'RTL Thread Copy Code');

      await finish(tester);
    },
  );
}
