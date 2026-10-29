// Web SortableTabsList: dragging the Chat / Tasks / Files tabs saves the whole
// order as `sidebarOrder.channelPanelTabOrder`, and the strip follows it.
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/conversation_tab_reorder.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show fixture;

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  test('a dropped tab takes the place of the one it lands on', () {
    const chat = RaftConversationTabId.chat,
        tasks = RaftConversationTabId.tasks,
        files = RaftConversationTabId.files;
    expect(movedConversationTab([chat, tasks, files], chat, files), [
      tasks,
      files,
      chat,
    ]);
    expect(movedConversationTab([chat, tasks, files], files, chat), [
      files,
      chat,
      tasks,
    ]);
    expect(movedConversationTab([chat, tasks, files], tasks, tasks), [
      chat,
      tasks,
      files,
    ]);
  });

  Future<(dynamic, dynamic)> mount(WidgetTester t, {bool touch = false}) async {
    t.view.physicalSize = const Size(900, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    w.client.http.transformer = SyncTransformer();
    transport.routes['GET /agents'] = (_) => [];
    transport.routes['GET /servers/s1/members'] = (_) => [];
    transport.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [],
      'nextCursor': null,
    };
    transport.routes['GET /channels/c1/files'] = (_) => {
      'files': [],
      'nextCursor': null,
    };
    transport.routes['PATCH /servers/s1/sidebar-order'] = (_) => {'ok': true};
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: RaftInteractionScope(
          interaction: touch
              ? RaftInteraction.touchMode
              : RaftInteraction.pointerMode,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: w,
              builder: (_, _) => ConversationPanel(controller: w),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (w, transport);
  }

  List<String> labels(WidgetTester t) {
    final tabs = find.descendant(
      of: find.byKey(const Key('conversation-tabs')),
      matching: find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key as ValueKey).value}'.startsWith('panel-tab-'),
      ),
    );
    return [
      for (final e in tabs.evaluate())
        '${(e.widget.key as ValueKey).value}'.substring('panel-tab-'.length),
    ];
  }

  testWidgets('dragging Chat onto Files saves the new order', (t) async {
    final (w, transport) = await mount(t);
    expect(labels(t), ['chat', 'tasks', 'files']);
    final drag = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('panel-tab-chat'))),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(20, 0));
    await t.pump();
    await drag.moveTo(
      t.getCenter(find.byKey(const ValueKey('panel-tab-files'))),
    );
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    final writes = [
      for (final c in transport.calls)
        if (c.method == 'PATCH' && c.path == '/servers/s1/sidebar-order')
          c.data,
    ];
    expect(writes, [
      {
        'channelPanelTabOrder': ['tasks', 'files', 'chat'],
      },
    ]);
    // The row moved before the request returned.
    expect(w.sidebarOrder['channelPanelTabOrder'], ['tasks', 'files', 'chat']);
    expect(labels(t), ['tasks', 'files', 'chat']);
  });

  testWidgets('a plain tap still selects the tab and writes nothing', (
    t,
  ) async {
    final (w, transport) = await mount(t);
    await t.tap(find.byKey(const ValueKey('panel-tab-files')));
    await t.pumpAndSettle();
    expect(w.location.chatTab, 'files');
    expect(transport.calls.where((c) => c.method == 'PATCH'), isEmpty);
  });

  testWidgets('a finger needs a long press: a quick drag does not reorder', (
    t,
  ) async {
    final (_, transport) = await mount(t, touch: true);
    final drag = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('panel-tab-chat'))),
      kind: PointerDeviceKind.touch,
    );
    await drag.moveBy(const Offset(20, 0));
    await t.pump();
    await drag.moveTo(
      t.getCenter(find.byKey(const ValueKey('panel-tab-files'))),
    );
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(transport.calls.where((c) => c.method == 'PATCH'), isEmpty);
    expect(labels(t), ['chat', 'tasks', 'files']);
  });

  testWidgets('a finger that long-presses can drag a tab to a new place', (
    t,
  ) async {
    final (_, transport) = await mount(t, touch: true);
    final drag = await t.startGesture(
      t.getCenter(find.byKey(const ValueKey('panel-tab-tasks'))),
      kind: PointerDeviceKind.touch,
    );
    await t.pump(const Duration(milliseconds: 700));
    await drag.moveTo(
      t.getCenter(find.byKey(const ValueKey('panel-tab-chat'))),
    );
    await t.pump();
    await drag.up();
    await t.pumpAndSettle();
    expect(
      [
        for (final c in transport.calls)
          if (c.method == 'PATCH') c.data,
      ],
      [
        {
          'channelPanelTabOrder': ['tasks', 'chat', 'files'],
        },
      ],
    );
    expect(labels(t), ['tasks', 'chat', 'files']);
  });

  testWidgets('the order saved by another device is honoured', (t) async {
    final (w, _) = await mount(t);
    w.sidebarOrder = <String, dynamic>{
      ...w.sidebarOrder,
      'channelPanelTabOrder': ['files', 'chat', 'tasks'],
    };
    w.notifyListeners();
    await t.pumpAndSettle();
    expect(labels(t), ['files', 'chat', 'tasks']);
  });
}
