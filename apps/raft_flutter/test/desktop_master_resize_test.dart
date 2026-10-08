import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_master_detail.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'result resize overlays boundary and keeps separate wide/compact memory',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 720);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final text = TextEditingController();
      addTearDown(text.dispose);
      var picked = true;
      late StateSetter update;
      final changes = <(double, bool)>[];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return DesktopMasterDetail(
                  master: TextField(controller: text),
                  detail: picked
                      ? const SizedBox.expand(key: Key('detail-box'))
                      : null,
                  onWidthChanged: (width, compact) =>
                      changes.add((width, compact)),
                );
              },
            ),
          ),
        ),
      );
      final master = find.byKey(const Key('desktop-master-panel'));
      final handle = find.byKey(const Key('desktop-master-resize-handle'));
      final original = t.state<EditableTextState>(find.byType(EditableText));
      expect(t.getSize(master).width, 560);
      expect(t.getRect(find.byKey(const Key('detail-box'))).left, 560);
      expect(t.getCenter(handle).dx, 560);
      await t.enterText(find.byType(TextField), 'Retained query');
      await t.drag(handle, const Offset(80, 0));
      await t.pump();
      expect(t.getSize(master).width, 640);
      t.view.physicalSize = const Size(900, 720);
      await t.pump();
      expect(t.getSize(master).width, 320);
      await t.drag(handle, const Offset(32, 0));
      await t.pump();
      expect(t.getSize(master).width, 352);
      t.view.physicalSize = const Size(1280, 720);
      await t.pump();
      expect(t.getSize(master).width, 640);
      update(() => picked = false);
      await t.pump();
      expect(handle, findsNothing);
      expect(t.getSize(master).width, 1280);
      update(() => picked = true);
      await t.pump();
      expect(t.getSize(master).width, 640);
      expect(
        t.state<EditableTextState>(find.byType(EditableText)),
        same(original),
      );
      expect(text.text, 'Retained query');
      expect(changes, containsAll([(640.0, false), (352.0, true)]));
      for (final (width, compact) in changes) {
        expect(
          width,
          inInclusiveRange(compact ? 320 : 400, compact ? 480 : 720),
        );
      }
      expect(t.takeException(), isNull);
    },
  );
}
