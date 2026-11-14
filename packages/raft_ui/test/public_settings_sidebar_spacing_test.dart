import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final spec in [
    ('raft-light', raftThemePackId, false),
    ('raft-dark', raftThemePackId, true),
    ('elegant-light', elegantThemePackId, false),
    ('elegant-dark', elegantThemePackId, true),
    ('brutal', brutalThemePackId, false),
  ]) {
    testWidgets('public settings sidebar inset ${spec.$1}', (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: spec.$3, pack: packForThemeId(spec.$2)),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 240,
                  height: 900,
                  child: RaftPublicSettingsSidebar(
                    title: 'Settings',
                    child: RaftSettingsSidebarList(
                      activeId: 'appearance',
                      groups: [
                        RaftSettingsNavGroup('Personal', [
                          RaftSettingsNavEntry(
                            id: 'appearance',
                            label: 'Appearance',
                            glyph: RaftGlyph.type,
                            onTap: () {},
                          ),
                        ]),
                        RaftSettingsNavGroup('Resources', [
                          RaftSettingsNavEntry(
                            id: 'about',
                            label: 'About',
                            glyph: RaftGlyph.badgeInfo,
                            onTap: () {},
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final output = Platform.environment['PUBLIC_SIDEBAR_OUT'];
      if (output != null) {
        await t.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          Directory(output).createSync(recursive: true);
          await File('$output/${spec.$1}.png')
              .writeAsBytes(data!.buffer.asUint8List());
        });
      }
      if (spec.$2 == raftThemePackId) {
        // The existing 56px header + public frame p-2, followed by the
        // 0.95.3 SidebarGroupLabel pt-4 / 18px line / pb-0 and list py-2.
        expect(
          t
              .getTopLeft(
                find.byKey(const ValueKey('workspace-settings-nav-appearance')),
              )
              .dy,
          56 + 8 + 16 + 18 + 8,
        );
      }
      expect(t.takeException(), isNull);
    });
  }
}
