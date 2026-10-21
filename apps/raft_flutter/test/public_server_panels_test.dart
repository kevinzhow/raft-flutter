// The public server page, v1.21.12: drag-resizable columns with remembered
// widths (Web PublicServerPage `useResizablePanel`, `lib/panelBounds.ts`,
// PanelResizeHandle).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/public_server_panels.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/public_server_fixture.dart';

final _sidebarHandle = find.byKey(
  const ValueKey('public-server-channel-sidebar-resize-handle'),
);
final _settingsHandle = find.byKey(
  const ValueKey('public-server-settings-sidebar-resize-handle'),
);
final _threadHandle = find.byKey(
  const ValueKey('public-server-thread-panel-resize-handle'),
);

double _width(WidgetTester t, String key) =>
    t.getSize(find.byKey(ValueKey(key))).width;

/// The thread column including its `border-l`.
double _threadWidth(WidgetTester t) =>
    t.getSize(find.byType(RaftPublicThreadColumn)).width;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('resize handles', () {
    testWidgets(
      'dragging the channel column stays within 180..320 and persists',
      (t) async {
        await mountPublicServer(t);
        expect(_width(t, 'public-server-channel-sidebar'), 240);
        await t.drag(_sidebarHandle, const Offset(50, 0));
        await t.pumpAndSettle();
        expect(_width(t, 'public-server-channel-sidebar'), 290);
        await t.drag(_sidebarHandle, const Offset(200, 0));
        await t.pumpAndSettle();
        expect(_width(t, 'public-server-channel-sidebar'), 320);
        await t.drag(_sidebarHandle, const Offset(-400, 0));
        await t.pumpAndSettle();
        expect(_width(t, 'public-server-channel-sidebar'), 180);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble(PublicPanelWidths.channelSidebarKey), 180);
        // The settings column keeps its own width.
        expect(prefs.getDouble(PublicPanelWidths.settingsSidebarKey), isNull);
      },
    );

    testWidgets('a stored width is restored, an out-of-range one ignored', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        PublicPanelWidths.channelSidebarKey: 300.0,
        PublicPanelWidths.settingsSidebarKey: 100.0,
      });
      await mountPublicServer(t);
      expect(_width(t, 'public-server-channel-sidebar'), 300);
      await openPublicSettings(t);
      expect(_width(t, 'public-server-settings-sidebar'), 240);
    });

    testWidgets('the settings column resizes on its own key', (t) async {
      await mountPublicServer(t);
      await openPublicSettings(t);
      await t.drag(_settingsHandle, const Offset(-30, 0));
      await t.pumpAndSettle();
      expect(_width(t, 'public-server-settings-sidebar'), 210);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(PublicPanelWidths.settingsSidebarKey), 210);
      expect(prefs.getDouble(PublicPanelWidths.channelSidebarKey), isNull);
    });

    testWidgets(
      'the thread column grows leftwards, 360 up to 60% of the window',
      (t) async {
        await mountPublicServer(t);
        await t.tap(find.byKey(const ValueKey('public-thread-open-m1')));
        await t.pumpAndSettle();
        expect(_threadWidth(t), 400);
        await t.drag(_threadHandle, const Offset(-100, 0));
        await t.pumpAndSettle();
        expect(_threadWidth(t), 500);
        await t.drag(_threadHandle, const Offset(-1000, 0));
        await t.pumpAndSettle();
        // 60% of 1280.
        expect(_threadWidth(t), 768);
        await t.drag(_threadHandle, const Offset(1000, 0));
        await t.pumpAndSettle();
        expect(_threadWidth(t), 360);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble(PublicPanelWidths.threadKey), 360);
      },
    );

    testWidgets('arrow keys step a focused handle by 16', (t) async {
      await mountPublicServer(t);
      // Tab focus on the handle (Web has none; the strip is a keyboard aid).
      Focus.of(
        t.element(
          find
              .descendant(
                of: _sidebarHandle,
                matching: find.byType(GestureDetector),
              )
              .first,
        ),
      ).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await t.pumpAndSettle();
      expect(_width(t, 'public-server-channel-sidebar'), 256);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.pumpAndSettle();
      expect(_width(t, 'public-server-channel-sidebar'), 240);
    });

    testWidgets('below sm the columns keep their CSS widths and no handle', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({
        PublicPanelWidths.channelSidebarKey: 300.0,
      });
      await mountPublicServer(t, size: const Size(600, 800));
      expect(_sidebarHandle, findsNothing);
      expect(_width(t, 'public-server-channel-sidebar'), 144);
    });
  });

  group('panel widths', () {
    test('the thread max is 60% of the viewport, never below 400', () {
      expect(PublicPanelBounds.threadMax(1280), 768);
      expect(PublicPanelBounds.threadMax(600), 400);
      final widths = PublicPanelWidths(viewport: 1000)
        ..setThread(2000)
        ..setChannelSidebar(10);
      expect(widths.thread, 600);
      expect(widths.channelSidebar, 180);
    });
  });
}
