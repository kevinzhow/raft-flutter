import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/channel_management_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (name, preview, title) in [
      ('channel', channelSettingsPagePreview, '#general'),
      ('dm', dmSettingsPagePreview, 'Alice'),
    ]) {
      testWidgets('current settings preview $name ${dark ? 'dark' : 'light'}', (
        t,
      ) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        final capture = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RepaintBoundary(key: capture, child: preview()),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(RaftOverflowSheet), findsOneWidget);
        expect(find.byType(RaftChannelSettingsSheet), findsNothing);
        // Web's Drawer header below md: `h-panel-header` (62px fallback) with
        // px-4 and the icon-sm Back, `size-8` in raft-ui 0.7.0 (32px).
        expect(find.byType(RaftMobilePageHeader), findsNothing);
        final back = find.byKey(const ValueKey('channel-overflow-back'));
        expect(t.getSize(back), const Size.square(32));
        // No left edge line on the phone (owner decision 2026-10-12).
        expect(t.getCenter(back).dx, 16 + 16);
        // Centred in the border-box less its bottom edge (1px).
        expect(t.getTopLeft(back).dy, (62 - 1 - 32) / 2);
        expect(
          t.getSemantics(find.text(title)).flagsCollection.isHeader,
          isTrue,
        );
        expect(t.testTextInput.isVisible, isFalse);
        expect(
          find.byType(RaftChannelInfoForm),
          name == 'channel' ? findsOneWidget : findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final render =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
            '../../.local/settings-page-previews/$name-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        t.view.physicalSize = const Size(320, 568);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // Web's taller (62px) brutal drawer header leaves less viewport; the
        // lazily built switch is scrolled in before it is toggled.
        final toggle = find.byType(RaftSwitch);
        await t.scrollUntilVisible(
          toggle,
          100,
          scrollable: find
              .descendant(
                of: find.byType(RaftOverflowSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.pumpAndSettle();
        await t.tap(toggle);
        await t.pump();
        expect(t.widget<RaftSwitch>(toggle).value, isTrue);
        await t.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      });
    }
  }
}
