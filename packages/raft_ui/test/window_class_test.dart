import 'dart:ui';


import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  RaftNavigationPlacement of(double w, double h) =>
      RaftWindowClass.phoneNavigationFor(Size(w, h));

  test('tall phones keep the bottom bar', () {
    expect(of(390, 844), RaftNavigationPlacement.bottom);
    expect(of(430, 932), RaftNavigationPlacement.bottom);
    expect(of(360, 640), RaftNavigationPlacement.bottom);
    expect(of(412, 915), RaftNavigationPlacement.bottom);
  });

  test('wide folds, landscape phones and 600-767 windows use the rail', () {
    for (final (w, h) in [
      (440.0, 707.0),
      (528.0, 848.0),
      (707.0, 440.0),
      (600.0, 960.0),
      (669.0, 951.0),
      (704.0, 933.0),
      (760.0, 840.0),
      (767.0, 1000.0),
      (568.0, 320.0),
    ]) {
      expect(of(w, h), RaftNavigationPlacement.rail, reason: '$w x $h');
    }
  });

  test('thresholds are inclusive/exclusive where documented', () {
    expect(of(599, 1200), RaftNavigationPlacement.bottom);
    expect(of(600, 1200), RaftNavigationPlacement.rail);
    // height / width exactly 1.75 is still a tall phone.
    expect(of(400, 700), RaftNavigationPlacement.bottom);
    expect(of(400, 699), RaftNavigationPlacement.rail);
    // Too narrow for a rail whatever the shape.
    expect(of(359, 400), RaftNavigationPlacement.bottom);
    expect(of(360, 400), RaftNavigationPlacement.rail);
  });

  test('only a separating vertical fold in the rail strip moves it', () {
    DisplayFeature feature(
      Rect bounds, {
      DisplayFeatureType type = DisplayFeatureType.hinge,
      DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
    }) => DisplayFeature(bounds: bounds, type: type, state: state);
    RaftNavigationPlacement place(
      Iterable<DisplayFeature> features, [
      TextDirection direction = TextDirection.ltr,
    ]) => RaftWindowClass.phoneNavigationFor(
      const Size(760, 840),
      displayFeatures: features,
      textDirection: direction,
    );
    // Mid-window hinge: the rail stays on the leading side.
    expect(
      place([feature(const Rect.fromLTRB(375, 0, 385, 840))]),
      RaftNavigationPlacement.rail,
    );
    // In the strip: leading edge only.
    final left = feature(const Rect.fromLTRB(20, 0, 30, 840));
    expect(place([left]), RaftNavigationPlacement.bottom);
    expect(place([left], TextDirection.rtl), RaftNavigationPlacement.rail);
    // Flat folds, cutouts and horizontal hinges never separate a rail.
    expect(
      place([
        feature(
          const Rect.fromLTRB(20, 0, 30, 840),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
        feature(
          const Rect.fromLTRB(0, 0, 40, 40),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
        feature(const Rect.fromLTRB(0, 400, 760, 410)),
      ]),
      RaftNavigationPlacement.rail,
    );
  });

  test('the fold rule follows the rail side, not the left edge', () {
    final hinge = DisplayFeature(
      bounds: const Rect.fromLTRB(410, 0, 420, 707),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureHalfOpened,
    );
    RaftNavigationPlacement place(RaftRailSide side, TextDirection direction) =>
        RaftWindowClass.phoneNavigationFor(
          const Size(440, 707),
          displayFeatures: [hinge],
          textDirection: direction,
          railSide: side,
        );
    // The hinge sits in the right-hand strip.
    expect(
      place(RaftRailSide.start, TextDirection.ltr),
      RaftNavigationPlacement.rail,
    );
    expect(
      place(RaftRailSide.end, TextDirection.ltr),
      RaftNavigationPlacement.bottom,
    );
    // RTL mirrors: start is the right edge.
    expect(
      place(RaftRailSide.start, TextDirection.rtl),
      RaftNavigationPlacement.bottom,
    );
    expect(
      place(RaftRailSide.end, TextDirection.rtl),
      RaftNavigationPlacement.rail,
    );
  });

  test('onRight: end is right in LTR, left in RTL', () {
    expect(
      RaftRailSideScope.onRight(RaftRailSide.start, TextDirection.ltr),
      isFalse,
    );
    expect(
      RaftRailSideScope.onRight(RaftRailSide.end, TextDirection.ltr),
      isTrue,
    );
    expect(
      RaftRailSideScope.onRight(RaftRailSide.start, TextDirection.rtl),
      isTrue,
    );
    expect(
      RaftRailSideScope.onRight(RaftRailSide.end, TextDirection.rtl),
      isFalse,
    );
  });

  group('desktop navigation column side', () {
    const size = Size(880, 1000);
    bool onRight({
      bool follows = true,
      RaftRailSide side = RaftRailSide.end,
      TextDirection direction = TextDirection.ltr,
      List<DisplayFeature> features = const [],
    }) => RaftWindowClass.desktopNavigationOnRight(
      size,
      followsSide: follows,
      railSide: side,
      textDirection: direction,
      columnWidth: 312,
      displayFeatures: () => features,
    );
    DisplayFeature hinge(double left) => DisplayFeature(
      bounds: Rect.fromLTWH(left, 0, 10, 1000),
      type: DisplayFeatureType.hinge,
      state: DisplayFeatureState.postureHalfOpened,
    );

    test('only touch devices follow the side', () {
      expect(onRight(), isTrue);
      expect(onRight(follows: false), isFalse);
      expect(onRight(side: RaftRailSide.start), isFalse);
    });

    test('RTL mirrors start and end', () {
      expect(onRight(direction: TextDirection.rtl), isFalse);
      expect(
        onRight(side: RaftRailSide.start, direction: TextDirection.rtl),
        isTrue,
      );
    });

    test('a separating fold inside the column keeps it on the left', () {
      expect(onRight(features: [hinge(440)]), isTrue);
      expect(onRight(features: [hinge(600)]), isFalse);
      expect(
        onRight(
          features: [
            DisplayFeature(
              bounds: const Rect.fromLTWH(600, 0, 10, 1000),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureFlat,
            ),
          ],
        ),
        isTrue,
        reason: 'a flat fold does not separate',
      );
    });
  });
}
