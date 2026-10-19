import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:raft_flutter/features/message_timeline.dart';

import 'flutter_test_config.dart' show RaftTestBinding;
import 'message_presentation_test.dart' show fixture;
import 'support/app_services_fixture.dart';

/// Counts the semantics nodes each frame sends to the engine.
class _Counts {
  int updated = 0;
  final edges = <int, List<int>>{};
  final orphans = <int>[];
  final labels = <int, String>{};
  final orphanOwners = <int, String>{};
}

class _CountingBuilder implements ui.SemanticsUpdateBuilder {
  _CountingBuilder(this.binding);
  final _Counts binding;
  final inner = ui.SemanticsUpdateBuilder();
  final updatedIds = <int>[];
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode) {
      binding.updated++;
      final id = invocation.namedArguments[#id] as int;
      updatedIds.add(id);
      binding.labels[id] = invocation.namedArguments[#label] as String;
      binding.edges[id] = List<int>.from(
        invocation.namedArguments[#childrenInTraversalOrder] as Iterable,
      );
    } else if (invocation.memberName == #build) {
      final reachable = <int>{};
      void visit(int id) {
        if (!reachable.add(id)) return;
        for (final child in binding.edges[id] ?? const <int>[]) {
          visit(child);
        }
      }

      visit(0);
      final disconnected = updatedIds
          .where((id) => !reachable.contains(id))
          .toSet();
      binding.orphans.addAll(disconnected);
      void inspect(RenderObject object) {
        final node = object.debugSemantics;
        if (node != null && disconnected.contains(node.id)) {
          binding.orphanOwners[node.id] =
              '${object.runtimeType} parent=${node.parent?.id} $node creator=${object.debugCreator}';
        }
        object.visitChildren(inspect);
      }

      if (disconnected.isNotEmpty) {
        for (final view in TestWidgetsFlutterBinding.instance.renderViews) {
          inspect(view);
        }
      }
    }
    final member = switch (invocation.memberName) {
      #updateNode => inner.updateNode,
      #updateCustomAction => inner.updateCustomAction,
      #build => inner.build,
      _ => throw UnsupportedError('${invocation.memberName}'),
    };
    return Function.apply(
      member,
      invocation.positionalArguments,
      invocation.namedArguments,
    );
  }
}

String longMessage(int i) =>
    '''## 第 $i 条固定性能消息

这是用于复现真实频道滚动卡顿的中文长消息。我们必须保留同一份输入和原始测量结果，不能用短消息或空列表替代用户正在阅读的内容。一次完整的回归应覆盖长段落、内联格式、链接、列表、代码以及附件，检查真实构建和布局成本。

这里继续说明产品的实现约束。界面显示的资料来自当前工作区，频道和线程分别保留自己的滚动位置，长内容在需要的时候折叠。**同样的文字**应该在不同主题下保持可读，*文字选择*和鼠标菜单应当持续可用，不能为了测量而关闭产品原本的功能。查看 [来源资料](https://example.invalid/reference/$i) 了解固定输入。

- 第一项：这是一段包含中文、English、日本語和多个标点的长列表内容，用于测量换行、内联解析、选择区域和约束变化时的实际布局。
- 第二项：固定消息的内容不随版本更改，页面结构和绘制成本才能进行比较；任何测量失败都必须保留，不能仅汇总成功的最后一次运行。
- 第三项：当前频道含有几百条不同类型的消息，我们连续滚动十秒，再在消息上下文内重复滚动，最后调整真实桌面窗口大小。

> 引用的一段讨论：外观对齐需要保留交互和滚动流畅度，真实平台的证据必须覆盖显示、绘制、输入和状态变化。

```dart
Future<String> processMessage(int value) async {
  final values = List.generate(8, (index) => index + value);
  final total = values.fold<int>(0, (a, b) => a + b);
  return "fixed message $i: \$total";
}
```

''';

/// Mirrors the P01 benchmark rows (tool/performance): long Markdown with a
/// link, list, quote and code, then a per-row variant and a reaction.
Map<String, dynamic> benchmarkRow(int i) => {
  'id': 'perf-$i',
  'channelId': 'c1',
  'seq': i + 1,
  'senderId': i.isEven ? 'alice' : 'bob',
  'senderType': 'user',
  'senderName': i.isEven ? 'Alice' : 'Bob',
  'messageType': 'chat',
  'createdAt': DateTime.utc(
    2026,
    10,
    1,
  ).add(Duration(minutes: i)).toIso8601String(),
  'content':
      longMessage(i) +
      switch (i % 4) {
        0 => 'Message $i: plain text with 中文、日本語 and a short reply.',
        1 =>
          '### Update $i\n\n**Bold** and *italic* text.\n\n- First point\n- Second point\n\n> Quoted response with [a link](https://example.invalid).',
        2 =>
          'Code $i\n\n```dart\nFuture<String> reply(int value) async {\n  return "message \$value";\n}\n```',
        _ => 'Image $i with a caption and reactions.',
      },
  'reactions': [
    {
      'emoji': '👍',
      'count': 2,
      'userIds': ['alice', 'bob'],
    },
  ],
};

/// Semantics nodes produced inside one timeline row, including the text
/// fragments a paragraph assembles below its own node.
int rowNodeCount(Element row) {
  final owned = <SemanticsNode>{};
  void visit(Element e) {
    final node = e.renderObject?.debugSemantics;
    // Excluded render objects keep a detached cached node; skip those.
    if (node != null && node.attached) owned.add(node);
    e.visitChildren(visit);
  }

  visit(row);
  final all = <SemanticsNode>{};
  void descend(SemanticsNode n) {
    if (!all.add(n)) return;
    n.visitChildren((c) {
      descend(c);
      return true;
    });
  }

  owned.forEach(descend);
  return all.length;
}

void main() {
  final binding = _Counts();
  RaftTestBinding.semanticsBuilderFactory = () => _CountingBuilder(binding);
  testWidgets(
    'tooltip portals remain reachable through list scrolling and dialog dismissal',
    (t) async {
      final semantics = t.ensureSemantics();
      final scroll = ScrollController();
      binding.edges.clear();
      binding.orphans.clear();
      Widget pair(int i) => Row(
        children: [
          RaftTooltip(
            message: 'First $i',
            child: TextButton(
              key: Key('first-$i'),
              onPressed: () {},
              child: const Text('First'),
            ),
          ),
          RaftTooltip(
            message: 'Second $i',
            child: TextButton(
              key: Key('second-$i'),
              onPressed: () {},
              child: const Text('Second'),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: SizedBox(
                          width: 300,
                          height: 150,
                          child: pair(99),
                        ),
                      ),
                    ),
                    child: const Text('Open dialog'),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: 30,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 200, child: pair(i)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: t.getCenter(find.byKey(const Key('first-0'))),
      );
      await t.pump(const Duration(milliseconds: 800));
      await mouse.moveTo(t.getCenter(find.byKey(const Key('second-0'))));
      await t.pump(const Duration(milliseconds: 800));
      scroll.jumpTo(1200);
      await t.pumpAndSettle();
      await mouse.moveTo(t.getCenter(find.text('Open dialog')));
      await t.tap(find.text('Open dialog'));
      await t.pumpAndSettle();
      await mouse.moveTo(t.getCenter(find.byKey(const Key('first-99'))));
      await t.pump(const Duration(milliseconds: 800));
      await mouse.moveTo(t.getCenter(find.byKey(const Key('second-99'))));
      await t.pump(const Duration(milliseconds: 800));
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      await mouse.removePointer();
      expect(
        binding.orphans,
        isEmpty,
        reason: 'Every serialized native semantics node must be reachable from root 0.',
      );
      await t.pumpWidget(const SizedBox());
      semantics.dispose();
      scroll.dispose();
    },
  );
  testWidgets(
    'workspace portals remain connected through hover, scroll and settings',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final handle = t.ensureSemantics();
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final rows = [for (var i = 0; i < 60; i++) benchmarkRow(i)];
      w.messageDomain.ledger.ingest(
        rows,
        expectedGeneration: w.messageDomain.ledger.generation,
      );
      w.messageDomain.visibleIds['c1'] = {
        for (final row in rows) row['id'] as String,
      };
      transport.routes['GET /agents'] = (_) => [];
      transport.routes['GET /servers/s1/members'] = (_) => [];
      transport.routes['GET /tasks'] = (_) => [];
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      binding.edges.clear();
      binding.orphans.clear();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
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
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await t.pumpAndSettle();
      final timeline = find
          .descendant(
            of: find.byType(RaftChatView),
            matching: find.byType(Scrollable),
          )
          .first;
      final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: t.getCenter(timeline));
      await t.pump(const Duration(milliseconds: 800));
      final position = t.state<ScrollableState>(timeline).position;
      final before = position.pixels;
      position.jumpTo(
        (position.pixels - 1800).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await t.pumpAndSettle();
      expect(position.pixels, isNot(before));
      await mouse.moveTo(const Offset(1000, 300));
      await t.pump(const Duration(milliseconds: 800));
      w.setSection('settings');
      await t.pumpAndSettle();
      w.setSection('chat');
      await t.pumpAndSettle();
      await mouse.removePointer();
      expect(
        binding.orphans,
        isEmpty,
        reason: 'Workspace incremental updates must remain rooted through hover and navigation.',
      );
      await t.pumpWidget(const SizedBox());
      handle.dispose();
    },
  );
  testWidgets(
    'nearby portal rows stay rooted through hover, focus and scrolling',
    (t) async {
      final handle = t.ensureSemantics();
      final controller = RaftTimelineScrollController(bottomAnchored: true);
      addTearDown(controller.dispose);
      t.view.physicalSize = const Size(1200, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final messages = [
        for (var i = 0; i < 1000; i++)
          chat.Message.text(id: '$i', authorId: 'fixture', text: '$i'),
      ];
      var idle = true;
      var activations = 0;
      binding.edges.clear();
      binding.orphans.clear();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: RaftMessageTimeline(
                    controller: controller,
                    messages: messages,
                    centerIndex: 999,
                    epoch: 0,
                    indexOfId: int.tryParse,
                    canPrepareNearbyRows: () => idle,
                    estimateRow: (_) => 200,
                    rowBuilder: (_, i) => SizedBox(
                      height: 200,
                      child: RaftMessageRow(
                        author: 'Fixture',
                        timestamp: '12:00',
                        semanticsLabel: 'row-$i',
                        semanticsText: 'Body $i',
                        content: Text('Body $i'),
                        toolbar: RaftMessageToolbar(
                          children: [
                            RaftMessageToolbarAction(
                              label: 'Reply in thread',
                              icon: const SizedBox(),
                              onPressed: () => activations++,
                            ),
                            RaftMessageToolbarAction(
                              label: 'More actions',
                              icon: const SizedBox(),
                              onPressed: () => activations++,
                            ),
                          ],
                        ),
                      ),
                    ),
                    slivers: (history, forward) => [history, forward],
                  ),
                ),
                const TextField(
                  decoration: InputDecoration(labelText: 'Message composer'),
                ),
              ],
            ),
          ),
        ),
      );
      final mouse = await t.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1190, 790));
      final initialRows = find
          .byType(RaftMessageRow, skipOffstage: false)
          .evaluate()
          .length;
      for (var i = 0; i < 45; i++) {
        await t.pump(const Duration(milliseconds: 32));
      }
      expect(
        find.byType(RaftMessageRow, skipOffstage: false).evaluate().length,
        greaterThan(initialRows),
      );
      await mouse.moveTo(const Offset(1000, 350));
      await t.pumpAndSettle();
      idle = false;
      controller.jumpTo(controller.position.pixels - 1800);
      await t.pumpAndSettle();
      await mouse.moveTo(const Offset(1000, 400));
      await t.pump(const Duration(milliseconds: 800));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      controller.jumpTo(controller.position.pixels - 1800);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      expect(find.byType(RaftMessageToolbar), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(activations, 1);
      expect(
        binding.orphans,
        isEmpty,
        reason:
            'Portal anchors must remain connected: ${[for (final id in binding.orphans) (id, binding.labels[id], binding.orphanOwners[id])]}.',
      );
      await mouse.removePointer();
      await t.pumpWidget(const SizedBox());
      handle.dispose();
    },
  );
  testWidgets('benchmark rows: compact nodes, minimal per-frame updates', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.messageDomain.ledger.switchServer('s1');
    final rows = [for (var i = 0; i < 60; i++) benchmarkRow(i)];
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows) r['id'] as String,
    };
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /tasks'] = (_) => [];
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await t.pumpAndSettle();
    final counts = [
      for (final e
          in find.byType(RaftMessageTile, skipOffstage: false).evaluate())
        rowNodeCount(e),
    ];
    final tree =
        t.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
    var total = 0;
    void walk(SemanticsNode n) {
      total++;
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(tree);
    // Steady scroll: 120 frames of 24px, like a trackpad fling.
    final list = find.byType(Scrollable).first;
    final gesture = await t.startGesture(t.getCenter(list));
    await t.pump();
    binding.updated = 0;
    const frames = 120;
    for (var i = 0; i < frames; i++) {
      await gesture.moveBy(const Offset(0, 24));
      await t.pump(const Duration(milliseconds: 16));
    }
    final perFrame = binding.updated / frames;
    await gesture.up();
    await t.pumpAndSettle();
    // A rebuild that changes no row content re-sends no row nodes.
    binding.updated = 0;
    (t.state(find.byType(RaftChatView)) as dynamic).setState(() {});
    await t.pump();
    await t.pump();
    final rebuildUpdates = binding.updated;
    // Reference (before compact rows) on this fixture: 6–10 nodes per row,
    // 42 tree nodes, 13.6 nodes re-sent per scroll frame, 9 on a rebuild.
    debugPrint(
      'message semantics: nodesPerRow=$counts treeNodes=$total '
      'updatedPerScrollFrame=${perFrame.toStringAsFixed(1)} '
      'updatedOnRebuild=$rebuildUpdates',
    );
    // Row node + Show more + reaction; header, avatar, prose and the
    // collapsed tail add none.
    expect(counts, everyElement(lessThanOrEqualTo(3)));
    // Edge rows are re-sent as one node each, not with their whole subtree.
    expect(perFrame, lessThan(10));
    expect(rebuildUpdates, 0);
    handle.dispose();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
