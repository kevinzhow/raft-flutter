import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_master_detail.dart';
import 'package:raft_ui/raft_ui.dart';

/// The master/detail shell is a column of the workspace (rail, sidebar, docked
/// thread or profile), so its own box is narrower than the window. Every case
/// here mounts it in a narrow pane inside a wide window: reading the window
/// would choose the wide master band and squeeze the master below its minimum.
void main() {
  Future<void> mount(
    WidgetTester t, {
    required double pane,
    double? detailPanelWidth,
    double? directoryWidth,
  }) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1280, 900);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: pane,
                child: DesktopMasterDetail(
                  master: const SizedBox.expand(key: Key('master-box')),
                  detail: const SizedBox.expand(key: Key('detail-box')),
                  detailPanelWidth: detailPanelWidth,
                  directoryWidth: directoryWidth,
                ),
              ),
              const Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    );
  }

  final master = find.byKey(const Key('master-box'));
  final detail = find.byKey(const Key('detail-box'));
  final handle = find.byKey(const Key('desktop-master-resize-handle'));

  testWidgets('a pane too narrow for both columns lets the detail cover the '
      'master instead of squeezing it', (t) async {
    await mount(t, pane: 400);
    // 320 (the compact master band) + 320 (the detail) does not fit in 400.
    expect(t.getRect(detail).left, 0);
    expect(t.getSize(detail).width, 400);
    expect(handle, findsNothing);
  });

  testWidgets('a medium pane splits inside its own width, not the window\'s', (
    t,
  ) async {
    await mount(t, pane: 700);
    expect(t.getSize(master).width, 320);
    expect(t.getRect(detail).left, 320);
    expect(t.getSize(detail).width, 380);
    expect(t.getCenter(handle).dx, 320);
  });

  testWidgets('a pane wide enough for the wide band still gets it', (t) async {
    await mount(t, pane: 1100);
    expect(t.getSize(master).width, 560);
    expect(t.getSize(detail).width, 540);
  });

  testWidgets('the list beside a profile column keeps its floor or folds', (
    t,
  ) async {
    await mount(t, pane: 420, detailPanelWidth: 380);
    // 160 (the list floor) + 300 (the profile minimum) does not fit in 420.
    expect(t.getRect(detail).left, 0);
    expect(t.getSize(detail).width, 420);
    await mount(t, pane: 600, detailPanelWidth: 380);
    expect(t.getSize(master).width, 220);
    expect(t.getSize(detail).width, 380);
  });

  testWidgets('the classic directory keeps the sidebar floor or folds', (
    t,
  ) async {
    await mount(t, pane: 460, directoryWidth: 260);
    // 180 (the sidebar floor) + 320 (the detail) does not fit in 460.
    expect(t.getRect(detail).left, 0);
    expect(t.getSize(detail).width, 460);
    await mount(t, pane: 700, directoryWidth: 260);
    expect(t.getSize(master).width, 260);
    expect(t.getSize(detail).width, 440);
  });
}
