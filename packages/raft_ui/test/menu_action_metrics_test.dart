import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final id in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    testWidgets('$id quick reactions have the source section separation', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(id)),
          home: Scaffold(
            body: Center(
              child: RaftMessageContextMenu(
                onReact: (_) {},
                sections: [
                  [
                    RaftMessageContextMenuItem(
                      label: 'Copy',
                      icon: const SizedBox(),
                      onPressed: () {},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      final quick = t.getRect(
        find.byKey(const ValueKey('message-menu-reaction-quick-row')),
      );
      final first = t.getRect(find.widgetWithText(RaftMenuButtonItem, 'Copy'));
      expect(first.top - quick.bottom, id == raftThemePackId ? 13 : 2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  for (final (id, regular, compact, popup) in raftThemeMatrix([
    (raftThemePackId, 36.0, 32.0, 240.0),
    (elegantThemePackId, 28.0, 28.0, 192.0),
    (brutalThemePackId, 28.0, 28.0, 192.0),
  ], look: (v) => raftLookOf(v.$1))) {
    testWidgets('$id action menu uses source sizes and remains operable', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var calls = 0;
      Future<void> mount(double viewportHeight, {double scale = 1}) async {
        t.view.physicalSize = Size(390, viewportHeight);
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(id))
                .copyWith(platform: TargetPlatform.linux),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: RaftMessageContextMenu(
                  sections: [
                    [
                      RaftMessageContextMenuItem(
                        label: 'Copy link',
                        icon: const SizedBox(),
                        onPressed: () => calls++,
                      ),
                      const RaftMessageContextMenuItem(
                        label: 'Disabled',
                        icon: SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      final row = find.widgetWithText(RaftMenuButtonItem, 'Copy link');
      final menu = find.byKey(const ValueKey('raft-message-context-menu'));
      for (final height in [844.0, 600.0, 601.0]) {
        await mount(height);
        expect(t.getSize(row).height, height <= 600 ? compact : regular);
        expect(t.getSize(menu).width, popup);
        expect(t.takeException(), isNull);
      }
      await t.tap(row);
      await t.pump();
      expect(calls, 1);
      Focus.of(t.element(find.text('Copy link'))).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(calls, 2);
      await t.tap(find.text('Disabled'));
      await t.pump();
      expect(calls, 2);
      await mount(844, scale: 3.1);
      expect(t.getSize(row).height, greaterThan(regular));
      expect(
        t.getRect(row).contains(t.getRect(find.text('Copy link')).center),
        isTrue,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
