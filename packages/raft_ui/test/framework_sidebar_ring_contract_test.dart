import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'flutter_test_config.dart';

void main() {
  RaftTestBinding.showShadows();
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('$pack/$dark sidebar rings paint beyond layout', (t) async {
        t.view.physicalSize = const Size(1280, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final boundaryKey = GlobalKey();
        late Color backdrop;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) {
                    backdrop = RaftTokens.of(context).colors['layer-sidebar']!;
                    return RepaintBoundary(
                      key: boundaryKey,
                      child: Container(
                        color: backdrop,
                        width: 260,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final selected in [true, false])
                              SizedBox(
                                width: 200,
                                child: RaftNavItem(
                                  key: ValueKey(selected),
                                  label: 'design',
                                  glyph: RaftGlyph.hash,
                                  conversationKind:
                                      RaftConversationNavKind.channel,
                                  selected: selected,
                                  onTap: () {},
                                ),
                              ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: RaftSidebarUnreadCount(count: 7),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: RaftSidebarMentionMarker(
                                label: 'Mentioned',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final selectedRow = find.byKey(const ValueKey(true));
        final tokens = RaftTokens.of(t.element(selectedRow));
        final glyph = t.widget<RaftIcon>(
          find
              .descendant(of: selectedRow, matching: find.byType(RaftIcon))
              .first,
        );
        expect(
          glyph.color,
          tokens.colors[pack == raftThemePackId
              ? 'sticker-ink'
              : 'foreground-sidebar-item-icon'],
        );
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final origin = t.getTopLeft(find.byKey(boundaryKey));
        final targets = [
          for (final selected in [true, false])
            find.descendant(
              of: find.byKey(ValueKey(selected)),
              matching: find.byType(RaftControl),
            ),
          find.byType(RaftSidebarUnreadCount),
          find.byKey(const ValueKey('sidebar-mention-marker')),
        ];
        final rects = targets.map(t.getRect).toList();
        final pixels = await t.runAsync(() async {
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final result = <List<int>>[];
          for (final rect in rects) {
            final x = (rect.left - origin.dx).round() - 1;
            final y = (rect.center.dy - origin.dy).floor();
            result.add(
              data.sublist(
                (y * image.width + x) * 4,
                (y * image.width + x) * 4 + 4,
              ),
            );
          }
          image.dispose();
          return result;
        });
        final bg = [
          (backdrop.r * 255).round(),
          (backdrop.g * 255).round(),
          (backdrop.b * 255).round(),
          255,
        ];
        // Source dark MainLayout: (95,95,93) at one pixel outside the selected
        // row/count/mention; the next pixel is partial coverage. Light has a
        // transparent ring, and both frozen packs have no outer ring.
        for (var i = 0; i < pixels!.length; i++) {
          final expected = pack == raftThemePackId && dark && i != 1
              ? [95, 95, 93, 255]
              : bg;
          for (var channel = 0; channel < 4; channel++) {
            expect(
              pixels[i][channel],
              closeTo(expected[channel], 1),
              reason: 'target$i channel$channel',
            );
          }
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
    }
  }
}
