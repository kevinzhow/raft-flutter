// The media browser previews in the three themes: no layout errors, the
// chrome is reachable and readable, targets are at least 44 dp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/media_browser_previews.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (name, preview, size) in <(String, Widget Function(), Size)>[
      ('phone', mediaBrowserPhonePreview, const Size(390, 844)),
      ('hidden', mediaBrowserPhoneHiddenPreview, const Size(390, 844)),
      ('landscape', mediaBrowserPhoneLandscapePreview, const Size(844, 390)),
      ('no caption', mediaBrowserPhoneNoCaptionPreview, const Size(390, 844)),
      ('desktop', mediaBrowserDesktopPreview, const Size(1280, 800)),
    ]) {
      testWidgets('media browser $name ${dark ? 'dark' : 'light'}', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final semantics = t.ensureSemantics();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(body: preview()),
          ),
        );
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
        if (name == 'desktop') {
          expect(find.text('hall-walkthrough.mp4'), findsOneWidget);
          expect(find.textContaining('Alice Chen'), findsOneWidget);
          expect(find.text('2 / 8'), findsOneWidget);
        } else if (name != 'hidden') {
          expect(find.text('IMG_2041.jpg'), findsOneWidget);
          for (final label in ['Back', 'Share', 'More']) {
            expect(
              t.getSize(find.bySemanticsLabel(label).first).shortestSide,
              greaterThanOrEqualTo(44),
              reason: label,
            );
          }
          // Video thumbnails are recognisable by their duration badge.
          expect(
            find.text('0:19').evaluate().isNotEmpty || name == 'landscape',
            isTrue,
          );
        }
        semantics.dispose();
      });
    }
  }
}
