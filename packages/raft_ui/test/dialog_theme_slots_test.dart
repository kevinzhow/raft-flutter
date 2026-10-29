import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets('Raft Dialog uses source header body and close bounds', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => t.pumpWidget(const SizedBox()));
    var closed = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftDialogShell(
            title: 'Delete Server',
            surfaceKey: const ValueKey('surface'),
            body: const SizedBox(key: ValueKey('body'), height: 40),
            footer: const [Text('Action')],
            onClose: () => closed++,
          ),
        ),
      ),
    );
    await t.pump();
    final surface = t.getRect(find.byKey(const ValueKey('surface')));
    final title = t.getRect(find.text('Delete Server'));
    final body = t.getRect(find.byKey(const ValueKey('body')));
    expect(title.left - surface.left, 20);
    expect(title.top - surface.top, 20);
    expect(t.widget<Text>(find.text('Delete Server')).style!.fontSize, 17);
    expect(body.left - surface.left, 20);
    expect(body.top - title.bottom, 6);
    final close = t.getRect(
      find.descendant(
        of: find.byType(RaftDialogClose),
        matching: find.byType(RaftButton),
      ),
    );
    expect(close.size, const Size.square(32));
    for (final offset in [
      const Offset(2, 2),
      const Offset(30, 2),
      const Offset(2, 30),
      const Offset(30, 30),
    ]) {
      await t.tapAt(close.topLeft + offset);
      await t.pump();
    }
    expect(
      closed,
      4,
      reason: 'source negative margin retains all visible close corners',
    );
    expect(t.takeException(), isNull);
  });
}
