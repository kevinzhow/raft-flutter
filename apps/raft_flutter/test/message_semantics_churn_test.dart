import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

/// Counts the semantics nodes each frame sends to the engine.
class _CountingBinding extends AutomatedTestWidgetsFlutterBinding {
  int updated = 0;
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      _CountingBuilder(this);
}

class _CountingBuilder implements ui.SemanticsUpdateBuilder {
  _CountingBuilder(this.binding);
  final _CountingBinding binding;
  final inner = ui.SemanticsUpdateBuilder();
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode) binding.updated++;
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
  final binding = _CountingBinding();
  testWidgets('benchmark rows: compact nodes, minimal per-frame updates', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    final (w, transport) = (await t.runAsync(() => fixture('member')))!;
    addTearDown(w.dispose);
    w.ledger.switchServer('s1');
    final rows = [for (var i = 0; i < 60; i++) benchmarkRow(i)];
    w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {for (final r in rows) r['id'] as String};
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
