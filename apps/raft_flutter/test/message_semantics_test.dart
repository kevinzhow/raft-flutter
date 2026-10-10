import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/saved_sidebar_entry.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, MessageAdapter;

// Screen-reader contract of timeline rows: one compact node per message.

final _long =
    '''Long message opening line that stays visible.

${'Middle paragraph that fills the collapsed body. ' * 12}

${'More filler text to push the end out of view. ' * 12}

Hidden tail sentence with [a tail link](https://example.invalid/tail).''';

Map<String, dynamic> _row(String id, int minute, String content) => {
  'id': id,
  'channelId': 'c1',
  'seq': minute + 1,
  'senderId': 'alice',
  'senderType': 'user',
  'senderName': 'Alice',
  'createdAt': DateTime.utc(
    2026,
    10,
    1,
    9,
  ).add(Duration(minutes: minute)).toIso8601String(),
  'content': content,
  'reactions': [
    {
      'emoji': '👍',
      'count': 2,
      'userIds': ['alice', 'bob'],
    },
  ],
};

Future<(WorkspaceController, MessageAdapter)> _mount(
  WidgetTester t,
  List<Map<String, dynamic>> rows,
) async {
  final (w, transport) = (await t.runAsync(() => fixture('member')))!;
  addTearDown(w.dispose);
  w.ledger.switchServer('s1');
  w.ledger.ingest(rows, expectedGeneration: w.ledger.generation);
  w.visibleIds['c1'] = {for (final r in rows) r['id'] as String};
  transport.routes['GET /agents'] = (_) => [];
  transport.routes['GET /servers/s1/members'] = (_) => [
    {'userId': 'cody', 'name': 'cody', 'role': 'member'},
  ];
  transport.routes['GET /tasks'] = (_) => [];
  t.view.physicalSize = const Size(1200, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: RaftDensityScope(
          density: RaftDensity.desktop,
          child: RaftChatView(controller: w),
        ),
      ),
    ),
  );
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await t.pumpAndSettle();
  return (w, transport);
}

SemanticsOwner _owner(WidgetTester t) =>
    t.binding.renderViews.first.owner!.semanticsOwner!;

/// `Alice, clock` header for the row showing [text].
String _header(WidgetTester t, String text) {
  final row = t.widget<RaftMessageRow>(
    find
        .ancestor(
          of: find.textContaining(text, findRichText: true),
          matching: find.byType(RaftMessageRow),
        )
        .first,
  );
  expect(row.timestamp, isNotEmpty);
  return '${row.author}, ${row.timestamp}';
}

/// The message row's own node.
SemanticsNode _rowNode(WidgetTester t, String text) => t.getSemantics(
  find
      .ancestor(
        of: find.textContaining(text, findRichText: true),
        matching: find.byType(RaftMessageRow),
      )
      .first,
);

List<SemanticsNode> _descendants(SemanticsNode node) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode n) {
    n.visitChildren((c) {
      out.add(c);
      visit(c);
      return true;
    });
  }

  visit(node);
  return out;
}

List<SemanticsNode> _allNodes(WidgetTester t) {
  final root = _owner(t).rootSemanticsNode!;
  return [root, ..._descendants(root)];
}

List<String> _customActions(SemanticsNode node) => [
  for (final id in node.getSemanticsData().customSemanticsActionIds ?? [])
    CustomSemanticsAction.getAction(id)!.label!,
];

void _perform(WidgetTester t, SemanticsNode node, String customAction) =>
    _owner(t).performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(
        CustomSemanticsAction(label: customAction),
      ),
    );

String? _clipboard;
void _captureClipboard(WidgetTester t) {
  _clipboard = null;
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        _clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('a row is one node announcing author, time and text', (t) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [_row('m1', 0, 'Short **plain** message')]);
    final row = _rowNode(t, 'Short');
    final data = row.getSemanticsData();
    expect(_header(t, 'Short'), startsWith('Alice, '));
    expect(data.label, '${_header(t, 'Short')}\nShort plain message');
    expect(data.hasAction(SemanticsAction.longPress), isTrue);
    // Header, avatar, time and prose are not nodes; only the reaction is.
    expect(_descendants(row).map((n) => n.label), ['👍: 2']);
    expect(_allNodes(t).where((n) => n.label == 'Alice'), isEmpty);
    semantics.dispose();
  });

  testWidgets('row actions: reply, react, save, copy and the message menu', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    final (w, _) = await _mount(t, [_row('m1', 0, 'Act on me')]);
    _captureClipboard(t);
    var row = _rowNode(t, 'Act on me');
    expect(_customActions(row), [
      'Reply in thread',
      'Add reaction',
      'Save message',
      'Copy Markdown',
      'Message actions',
    ]);

    _perform(t, row, 'Copy Markdown');
    await t.pump();
    expect(_clipboard, 'Act on me');

    _perform(t, row, 'Save message');
    await t.pump();
    // Optimistic, like the toolbar: the action now offers the inverse.
    expect(SavedCountStore.of(w).isSaved('m1'), isTrue);
    expect(
      _customActions(_rowNode(t, 'Act on me')),
      contains('Remove from Saved'),
    );
    await t.pumpAndSettle();
    row = _rowNode(t, 'Act on me');

    _perform(t, row, 'Add reaction');
    await t.pumpAndSettle();
    expect(find.byType(RaftQuickReactionPicker), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();

    // Long press is the platform-neutral path (Linux AT-SPI does not name
    // custom actions): it opens the message menu holding every action.
    _owner(t)
        .performAction(_rowNode(t, 'Act on me').id, SemanticsAction.longPress);
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('message-menu-copy-link')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('links and mentions stay reachable as link nodes', (t) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [
      _row('m1', 0, 'Ping @cody about [the doc](https://example.invalid/doc)'),
    ]);
    final row = _rowNode(t, 'Ping');
    expect(row.label, endsWith('\nPing @cody about the doc'));
    final links = _descendants(row)
        .where((n) => n.getSemanticsData().flagsCollection.isLink)
        .toList();
    expect(links.map((n) => n.label), ['@cody', 'the doc']);
    for (final link in links) {
      expect(link.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    }
    expect(
      links.last.getSemanticsData().linkUrl,
      Uri.parse('https://example.invalid/doc'),
    );
    semantics.dispose();
  });

  testWidgets('the hover toolbar joins the tree only while it is shown', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [_row('m1', 0, 'Hover me')]);
    bool toolbarButton(SemanticsNode n) =>
        n.label == 'Save message' &&
        n.getSemanticsData().flagsCollection.isButton;
    expect(_allNodes(t).where(toolbarButton), isEmpty);
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftMessageRow)));
    await t.pump(const Duration(milliseconds: 200));
    expect(_allNodes(t).where(toolbarButton), hasLength(1));
    await mouse.moveTo(const Offset(1199, 1799));
    await t.pump(const Duration(milliseconds: 200));
    expect(_allNodes(t).where(toolbarButton), isEmpty);
    semantics.dispose();
  });

  testWidgets('collapsed content stays out of the tree until expanded', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [_row('m1', 0, _long)]);
    var row = _rowNode(t, 'Long message opening');
    expect(
      row.label,
      contains('\nLong message opening line that stays visible.'),
    );
    expect(row.label, endsWith('…'));
    expect(row.label, isNot(contains('Hidden tail sentence')));
    var below = _descendants(row);
    expect(below.where((n) => n.label == 'a tail link'), isEmpty);
    final toggle = below.singleWhere((n) => n.label == 'Show more');

    _owner(t).performAction(toggle.id, SemanticsAction.tap);
    await t.pumpAndSettle();
    row = _rowNode(t, 'Long message opening');
    expect(row.label, endsWith('Hidden tail sentence with a tail link.'));
    below = _descendants(row);
    expect(below.where((n) => n.label == 'a tail link'), hasLength(1));
    expect(below.where((n) => n.label == 'Collapse'), hasLength(1));
    semantics.dispose();
  });

  testWidgets('a code block is one short node whose activation copies', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    _captureClipboard(t);
    await _mount(t, [
      _row('m1', 0, 'Run this\n\n```dart\nvoid main() {\n  print(1);\n}\n```'),
    ]);
    final row = _rowNode(t, 'Run this');
    expect(row.label, endsWith('\nRun this\nCode block, 3 lines, dart'));
    final code = _descendants(row)
        .singleWhere((n) => n.label == 'Code block, 3 lines, dart');
    expect(code.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(_allNodes(t).where((n) => n.label.contains('print(1)')), isEmpty);
    _owner(t).performAction(code.id, SemanticsAction.tap);
    await t.pump();
    expect(_clipboard, 'void main() {\n  print(1);\n}');
    await t.pump();
    expect(_rowNode(t, 'Run this').label, isNot(contains('Copied')));
    expect(
      _descendants(_rowNode(t, 'Run this'))
          .singleWhere((n) => n.label == 'Code block, 3 lines, dart')
          .value,
      'Copied',
    );
    await t.pump(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('day dividers are headers announced in reading case', (t) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [_row('m1', 0, 'First of the day')]);
    final headers = _allNodes(t)
        .where((n) => n.getSemanticsData().flagsCollection.isHeader)
        .toList();
    expect(headers, hasLength(1));
    expect(headers.single.label, isNot(headers.single.label.toUpperCase()));
    expect(headers.single.label, contains('October 1'));
    // The divider is not merged into the message's label.
    expect(_rowNode(t, 'First of the day').label, startsWith('Alice, '));
    semantics.dispose();
  });

  testWidgets('a grouped follow-up still announces its author and time', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await _mount(t, [
      _row('m1', 0, 'Opening message'),
      _row('m2', 1, 'Grouped follow-up'),
    ]);
    expect(
      _rowNode(t, 'Grouped follow-up').label,
      '${_header(t, 'Grouped follow-up')}\nGrouped follow-up',
    );
    semantics.dispose();
  });

  test('screen-reader text helpers', () {
    expect(raftMessageSemanticsExcerpt('one two three four', .5), 'one two…');
    expect(raftMessageSemanticsExcerpt('kept', null), 'kept');
    expect(
      raftMessageSemanticsLinks(
        'See [docs](https://a.invalid) and <https://b.invalid>, '
        '[@x](<raft-ref://mention/user/x>).',
      ).map((l) => l.label),
      ['docs', 'https://b.invalid', '@x'],
    );
  });
}
