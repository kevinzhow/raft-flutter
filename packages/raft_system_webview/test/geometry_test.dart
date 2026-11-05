import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_system_webview/raft_system_webview.dart';

void main() {
  SystemWebViewLayout resolve({
    Matrix4? transform,
    double scale = 1,
    List<Rect> clips = const [],
  }) => SystemWebViewLayout.resolve(
    local: const Rect.fromLTWH(0, 0, 500, 400),
    transform: transform ?? Matrix4.translationValues(12, 24, 0),
    viewport: const Rect.fromLTWH(0, 0, 800, 600),
    clips: clips,
    scale: scale,
  );
  test('native content and input share the translated clipped rectangle', () {
    final value = resolve(clips: [const Rect.fromLTWH(0, 40, 300, 500)]);
    expect(value.frame, const Rect.fromLTWH(12, 24, 500, 400));
    expect(value.clip, const Rect.fromLTWH(12, 40, 288, 384));
  });
  test('GTK conversion applies the Flutter-to-host logical scale once', () {
    final value = resolve(scale: 1.5);
    expect(value.frame, const Rect.fromLTWH(18, 36, 750, 600));
    expect(value.clip, value.frame);
  });
  test('fully clipped content has no native painting or pointer region', () {
    expect(
      resolve(clips: [const Rect.fromLTWH(600, 500, 20, 20)]).visible,
      false,
    );
  });
  test('rotation, scale, mirror, and perspective fail closed', () {
    for (final transform in [
      Matrix4.rotationZ(.01),
      Matrix4.diagonal3Values(2, 2, 1),
      Matrix4.diagonal3Values(-1, 1, 1),
      Matrix4.identity()..setEntry(3, 0, .01),
    ]) {
      expect(resolve(transform: transform).visible, false);
    }
  });
  test('nonfinite and unbounded native coordinates are refused', () {
    expect(resolve(scale: double.nan).visible, false);
    expect(
      resolve(transform: Matrix4.translationValues(double.infinity, 0, 0))
          .visible,
      false,
    );
    expect(resolve(scale: 1000000).visible, false);
  });
  test('occlusion sees original view coordinates before GTK scaling', () {
    Rect? observed;
    final result = SystemWebViewLayout.resolve(
      local: const Rect.fromLTWH(0, 0, 100, 80),
      transform: Matrix4.translationValues(30, 40, 0),
      viewport: const Rect.fromLTWH(0, 0, 800, 600),
      clips: const [],
      scale: 2,
      isOccluded: (rect) {
        observed = rect;
        return rect.overlaps(const Rect.fromLTWH(50, 60, 10, 10));
      },
    );
    expect(observed, const Rect.fromLTWH(30, 40, 100, 80));
    expect(result.visible, false);
  });
  test(
    'a pane fully inside actual rounded safe bounds keeps its rectangle',
    () {
      final clip = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 400, 300),
        const Radius.circular(20),
      );
      expect(
        SystemWebViewLayout.roundedClipForFrame(
          frameInClip: const Rect.fromLTWH(10, 40, 380, 240),
          clip: clip,
          clipToView: Matrix4.translationValues(50, 60, 0),
        ),
        const Rect.fromLTWH(50, 60, 400, 300),
      );
    },
  );
  test('a pane intersecting a rounded corner stays hidden', () {
    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 400, 300),
      const Radius.circular(20),
    );
    expect(
      SystemWebViewLayout.roundedClipForFrame(
        frameInClip: const Rect.fromLTWH(0, 40, 400, 260),
        clip: clip,
        clipToView: Matrix4.identity(),
      ),
      isNull,
    );
  });
  test('rotated rounded ancestors and nonfinite frames are never admitted', () {
    final clip = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 400, 300),
      const Radius.circular(20),
    );
    expect(
      SystemWebViewLayout.roundedClipForFrame(
        frameInClip: const Rect.fromLTWH(10, 40, 380, 240),
        clip: clip,
        clipToView: Matrix4.rotationZ(.1),
      ),
      isNull,
    );
    expect(
      SystemWebViewLayout.roundedClipForFrame(
        frameInClip: const Rect.fromLTRB(double.nan, 40, 390, 280),
        clip: clip,
        clipToView: Matrix4.identity(),
      ),
      isNull,
    );
  });
}
