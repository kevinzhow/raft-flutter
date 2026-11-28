// A mouse selection inside a rich Markdown message copies its text with
// Cmd+C and with the Quote / Copy pair beside it, in the channel column, the
// thread column beside it, and a phone's thread page.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/tap_target_registry.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/app_window.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_surface_test.dart' show flush;
import 'tap_target_matrix_test.dart'
    show Ctx, channelMessages, mount, threadReplies;

const _rich = '''
- **9 语种长短音频 + 生产参数全绿**：
  - Miraa 批处理 `B=8`（含 `word_timestamps=True`）：EN `1.20x`、JA `1.25x`；
  - 泰语公开 GT CER（`fleurs`）短音频 `10.3019% → 10.3019%`（`0.00 pp`，`1.13x`），长音频 `B=8` `35.06% → 34.94%`（`-0.12 pp` 更好，`1.35x`）；
  - 其余 5 语种（`ko/de/es/fr/ar`）`B=8` 全部 `0.00 pp` 差。
- 三层 `scripts/perf_regression.py --baseline` 直接过关。

完整验证报告：[the report](https://example.org/report)''';

TapHost _host(String id) =>
    TapTargetRegistry.hosts.firstWhere((h) => h.id == id);

List<RenderParagraph> _paragraphs(WidgetTester t, Finder scope) {
  final out = <RenderParagraph>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o);
    o.visitChildren(visit);
  }

  for (final e in scope.evaluate()) {
    visit(e.renderObject!);
  }
  return out;
}

/// Global rect of [snippet] in the first paragraph under [scope] showing it.
Rect _rectOf(WidgetTester t, Finder scope, String snippet) {
  for (final p in _paragraphs(t, scope)) {
    final text = p.text.toPlainText();
    final at = text.indexOf(snippet);
    if (at < 0) continue;
    final boxes = p.getBoxesForSelection(
      TextSelection(baseOffset: at, extentOffset: at + snippet.length),
    );
    final origin = p.localToGlobal(Offset.zero);
    return boxes
        .map((b) => b.toRect().shift(origin))
        .reduce((a, b) => a.expandToInclude(b));
  }
  throw StateError('no paragraph shows "$snippet"');
}

/// Records what reaches the clipboard.
List<String> _clipboard(WidgetTester t) {
  final copied = <String>[];
  final messenger = t.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}

/// The macOS runner's Edit > Copy (Cmd+C): it asks Dart to copy only while
/// Dart last reported a copyable selection; otherwise AppKit's own copy runs
/// and Flutter's selection never reaches the clipboard.
class _NativeMenu {
  _NativeMenu(this.t) {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      if (call.method == 'setWindowCommandsState') {
        canCopy = (call.arguments as Map)['copy'] == true;
      }
      return null;
    });
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
  }
  static const _channel = MethodChannel('app.raft/window');
  final WidgetTester t;
  bool canCopy = false;

  Future<void> cmdC() async {
    await t.pump();
    if (!canCopy) return;
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('copyRequested'),
      ),
      (_) {},
    );
    await t.pump();
  }
}

/// The desktop's one mouse, hovering over the window.
Future<TestGesture> _mouse(WidgetTester t) async {
  final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

/// Drags inside a nested list item, over its inline code spans, and leaves
/// the mouse where it let go.
Future<void> _select(WidgetTester t, TestGesture mouse, Finder scope) async {
  final from = _rectOf(t, scope, '长音频').centerLeft + const Offset(1, 0),
      to = _rectOf(t, scope, '34.94%').centerRight;
  await mouse.moveTo(from);
  await t.pump(const Duration(milliseconds: 200));
  await mouse.down(from);
  await t.pump();
  await mouse.moveTo(to, timeStamp: const Duration(milliseconds: 100));
  await t.pump();
  await mouse.moveTo(to + const Offset(1, 0));
  await t.pump();
  await mouse.up();
  await t.pump();
  // The Quote / Copy pair appears once the selection settles.
  await t.pump(const Duration(milliseconds: 150));
}

Future<void> _click(WidgetTester t, TestGesture mouse, Finder target) async {
  final at = t.getCenter(target);
  await mouse.moveTo(at);
  await t.pump(const Duration(milliseconds: 100));
  await mouse.down(at);
  await t.pump();
  await mouse.up();
  await t.pump();
}

Future<void> _end(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 5));
}

Finder _composer(Finder view) => find.descendant(
  of: view,
  matching: find.descendant(
    of: find.byType(RaftComposer),
    matching: find.byType(EditableText),
  ),
);

const _selected = '长音频 B=8 35.06% → 34.94%';

/// The agent's Markdown reply in the thread, or its message in the channel.
Future<Ctx> _mountRich(WidgetTester t, String host, {required bool thread}) {
  final agent = {'senderType': 'agent', 'senderName': 'Codex'};
  final message = thread
      ? (threadReplies['messages']! as List).cast<Map<String, dynamic>>().first
      : channelMessages.firstWhere((m) => m['id'] == 'tref');
  message
    ..['content'] = _rich
    ..addAll(agent);
  return mount(
    t,
    _host(host),
    builder: (context, child) => AppWindowCommands(
      navigatorKey: GlobalKey<NavigatorState>(),
      child: child!,
    ),
  );
}

void main() {
  for (final (host, thread) in [
    ('chat-thread-1280', true),
    ('chat-1280', false),
  ]) {
    final where = thread ? 'the thread column' : 'the channel column';
    testWidgets('$host: Cmd+C, Copy and Quote take a mouse selection in '
        '$where', (t) async {
      // A running app: SelectableRegion drops its selection on blur only then.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final menu = _NativeMenu(t);
      final c = await _mountRich(t, host, thread: thread);
      final view = find.byWidgetPredicate(
        (x) => x is RaftChatView && x.thread == thread,
      );
      final scope = thread ? c.threadView : c.row('tref');
      final copied = _clipboard(t);

      final mouse = await _mouse(t);
      await _select(t, mouse, scope);
      await menu.cmdC();
      expect(copied, [_selected], reason: 'Cmd+C copies the selection');

      await _select(t, mouse, scope);
      await _click(t, mouse, find.byKey(const Key('selection-shortcut-copy')));
      expect(copied, [_selected, _selected], reason: 'Copy copies it');
      expect(find.byKey(const Key('selection-shortcut-copy')), findsNothing);

      await _select(t, mouse, scope);
      await _click(t, mouse, find.byKey(const Key('selection-shortcut-quote')));
      expect(
        t.widget<EditableText>(_composer(view)).controller.text,
        '> $_selected\n\n',
        reason: "Quote puts the selection in this surface's composer",
      );
      await _end(t);
    }, variant: const TargetPlatformVariant({TargetPlatform.macOS}));
  }

  testWidgets('chat-390: the thread page copies a long-press selection', (
    t,
  ) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final c = await _mountRich(t, 'chat-390', thread: true);
    final badge = find.byKey(
      const ValueKey('thread-replies-badge-badge'),
      skipOffstage: false,
    );
    await t.ensureVisible(badge);
    await t.pumpAndSettle();
    await t.tap(badge);
    await flush(t);
    await t.pumpAndSettle();
    final copied = _clipboard(t);

    await t.longPressAt(_rectOf(t, c.threadView, '长音频').center);
    await t.pumpAndSettle();
    await t.tap(find.text('Copy'));
    await t.pump();
    expect(copied, hasLength(1));
    expect(_selected, contains(copied.single));
    await _end(t);
  });
}
