import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => InlineMediaTestHooks.playerFactory = null);

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    for (final width in [390.0, 800.0, 1280.0]) {
      testWidgets(
        '$platform $width timeline video is a shaped poster and opens preview without an inline player',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final (w, _) = (await tester.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          });
          var players = 0, opens = 0;
          InlineMediaTestHooks.playerFactory = () {
            players++;
            throw StateError('Timeline must not create a playback decoder');
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme().copyWith(platform: platform),
              home: Scaffold(
                body: Center(
                  child: InlineVideoAttachment(
                    controller: w,
                    metadata: const {
                      'id': 'timeline-video',
                      'channelId': 'c1',
                      'filename': 'portrait.mp4',
                      'mimeType': 'video/mp4',
                      'sizeBytes': 1024,
                      'width': 720,
                      'height': 1280,
                    },
                    channelId: 'c1',
                    authorized: () => true,
                    pending: false,
                    onOpenPreview: () => opens++,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(seconds: 5));
          expect(
            players,
            0,
            reason: 'Passing the old autoload/grace delays must not create a player',
          );
          expect(w.attachmentMedia.playerSessions.length, 0);
          expect(find.byType(RaftInlineVideo), findsNothing);
          expect(find.byType(RaftVideoPosterCard), findsOneWidget);
          expect(
            tester
                .widget<RaftVideoPosterCard>(find.byType(RaftVideoPosterCard))
                .aspectRatio,
            720 / 1280,
          );
          await tester.tap(find.byKey(const Key('inline-video-poster-card')));
          await tester.pump();
          expect(
            opens,
            1,
            reason: 'The entire timeline card opens the existing fullscreen preview',
          );
          expect(players, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
