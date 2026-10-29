import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_player.dart';

void main() {
  test(
    'the Linux software surface keeps the video aspect inside its bound',
    () {
      const full = Size(1920, 1080);
      // The 720x1280 phone clip that stayed black: media_kit_video's own
      // integer division sized its texture 720x1080.
      expect(
        NativeAttachmentPlayer.fitted(720, 1280, full),
        const Size(608, 1080),
      );
      expect(
        NativeAttachmentPlayer.fitted(1280, 720, full),
        const Size(1280, 720),
      );
      // 4K shrinks to the bound; nothing is ever enlarged.
      expect(
        NativeAttachmentPlayer.fitted(3840, 2160, full),
        const Size(1920, 1080),
      );
      expect(
        NativeAttachmentPlayer.fitted(320, 180, full),
        const Size(320, 180),
      );
      // An inline card needs less.
      expect(
        NativeAttachmentPlayer.fitted(720, 1280, const Size(960, 540)),
        const Size(304, 540),
      );
      expect(NativeAttachmentPlayer.fitted(null, 720, full), isNull);
      expect(NativeAttachmentPlayer.fitted(0, 0, full), isNull);
    },
  );

  test(
    'a re-signed source that never played reopens at its requested start',
    () {
      // Regression (CodexMac's review): an expired URL on the first open lost
      // the resume position and playback restarted from zero.
      const start = Duration(seconds: 7);
      expect(
        NativeAttachmentPlayer.resignPosition(Duration.zero, start),
        start,
      );
      expect(
        NativeAttachmentPlayer.resignPosition(
          const Duration(seconds: 12),
          start,
        ),
        const Duration(seconds: 12),
      );
    },
  );
}
