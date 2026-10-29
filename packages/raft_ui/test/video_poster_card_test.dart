// The phone video card (RaftVideoPosterCard) in the three themes: the box has
// the video's shape and is capped in height, the play button and the length
// are there, a tap anywhere opens, the semantics say Play video.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:raft_ui/video_poster_card_previews.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    for (final (name, preview, size) in <(String, Widget Function(), Size)>[
      ('landscape', videoPosterCardLandscapePreview, const Size(390, 500)),
      ('portrait', videoPosterCardPortraitPreview, const Size(390, 900)),
      ('tall', videoPosterCardTallPreview, const Size(390, 700)),
      ('placeholder', videoPosterCardPlaceholderPreview, const Size(390, 400)),
      ('uploading', videoPosterCardUploadingPreview, const Size(390, 400)),
    ]) {
      testWidgets('poster card $name ${dark ? 'dark' : 'light'}', (t) async {
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
        await t.pump();
        expect(t.takeException(), isNull);
        final box = t.getSize(find.byKey(const Key('inline-video')));
        switch (name) {
          case 'landscape' || 'placeholder' || 'uploading':
            expect(box.width / box.height, closeTo(16 / 9, .02));
          case 'portrait':
            expect(box.width / box.height, closeTo(9 / 16, .01));
          case 'tall':
            expect(box.height, closeTo(size.height * .6, 1), reason: 'capped');
        }
        if (name != 'uploading') {
          expect(
            find.bySemanticsLabel(RegExp('^Play Video .*\\.mp4')),
            findsOneWidget,
          );
        }
        semantics.dispose();
      });
    }
  }

  testWidgets(
    'a tap anywhere on the card opens; the length reads like the strip',
    (t) async {
      t.view.physicalSize = const Size(390, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var opened = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RaftVideoPosterCard(
                filename: 'a.mp4',
                aspectRatio: 1,
                duration: const Duration(hours: 1, minutes: 2, seconds: 3),
                onOpen: () => opened++,
              ),
            ),
          ),
        ),
      );
      expect(find.text('1:02:03'), findsOneWidget);
      final rect = t.getRect(find.byKey(const Key('inline-video')));
      for (final spot in [rect.center, rect.topLeft + const Offset(4, 4)]) {
        await t.tapAt(spot);
        await t.pump();
      }
      expect(opened, 2);
    },
  );
}
