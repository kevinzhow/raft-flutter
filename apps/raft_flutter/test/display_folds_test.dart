import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raft_flutter/platform/display_folds.dart';

Map<String, Object?> payload({
  String hinge = 'partiallyOpen',
  bool active = true,
  String kind = 'division',
  double width = 951,
  double height = 669,
  Rect rect = const Rect.fromLTWH(455, 0, 40, 669),
}) => {
  'hinge': hinge,
  'viewWidth': width,
  'viewHeight': height,
  'regions': [
    {
      'kind': kind,
      'active': active,
      'x': rect.left,
      'y': rect.top,
      'w': rect.width,
      'h': rect.height,
    },
  ],
};
FoldSnapshot snapshot({String hinge = 'partiallyOpen', bool active = true}) =>
    FoldSnapshot.parse(payload(hinge: hinge, active: active))!;

void main() {
  test('bad payloads are rejected without throwing', () {
    for (final bad in [
      null,
      1,
      {},
      payload()..['regions'] = [null],
      payload()..['viewWidth'] = double.nan,
    ]) {
      expect(FoldSnapshot.parse(bad), isNull);
    }
  });
  test('active partial division becomes a half-open fold', () {
    final feature = raftFoldFeatures(snapshot()).single;
    expect(feature.type, DisplayFeatureType.fold);
    expect(feature.state, DisplayFeatureState.postureHalfOpened);
  });
  test('inactive regions are dropped and become visible when active', () {
    expect(raftFoldFeatures(snapshot(active: false)), isEmpty);
    expect(raftFoldFeatures(snapshot()), hasLength(1));
  });
  for (final hinge in ['closed', 'none', 'fullyOpen', 'unknown']) {
    test(
      '$hinge drops divisions',
      () => expect(raftFoldFeatures(snapshot(hinge: hinge)), isEmpty),
    );
  }
  test('fully open retains active occlusion only', () {
    final data = payload(hinge: 'fullyOpen');
    (data['regions'] as List).add(
      (payload(kind: 'occlusion')['regions'] as List).single,
    );
    final feature = raftFoldFeatures(FoldSnapshot.parse(data)!).single;
    expect(feature.type, DisplayFeatureType.cutout);
    expect(feature.state, DisplayFeatureState.unknown);
  });
  for (final hinge in ['partiallyOpen', 'unknown', 'closed', 'none']) {
    test('$hinge occlusion mapping', () {
      expect(
        raftFoldFeatures(
          FoldSnapshot.parse(payload(hinge: hinge, kind: 'occlusion'))!,
        ),
        hasLength(['closed', 'none'].contains(hinge) ? 0 : 1),
      );
    });
  }
  test('empty and offscreen regions are dropped; frames are clipped', () {
    for (final rect in [
      const Rect.fromLTWH(1, 0, 0, 669),
      const Rect.fromLTWH(1, 0, 40, 0),
      const Rect.fromLTWH(1000, 0, 40, 669),
    ]) {
      expect(
        raftFoldFeatures(FoldSnapshot.parse(payload(rect: rect))!),
        isEmpty,
      );
    }
    expect(
      raftFoldFeatures(
        FoldSnapshot.parse(
          payload(rect: const Rect.fromLTWH(-5, -5, 40, 700)),
        )!,
      ).single.bounds,
      const Rect.fromLTRB(0, 0, 35, 669),
    );
  });

  testWidgets('native channel rejects malformed payloads and logs once', (
    tester,
  ) async {
    const channel = MethodChannel('app.raft/display-folds');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final logs = <String?>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    addTearDown(() => debugPrint = originalPrint);
    late List<DisplayFeature> features;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(951, 669)),
        child: RaftNativeDisplayFeatures(
          child: Builder(
            builder: (context) {
              features = MediaQuery.displayFeaturesOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    Future<void> send(Object? event) async {
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeSuccessEnvelope(event),
        (_) {},
      );
      await tester.pump();
      await tester.pump();
    }

    await send(payload());
    expect(features, hasLength(1));
    await send({'bad': true});
    expect(features, isEmpty);
    await send(null);
    expect(features, isEmpty);
    expect(
      logs.where(
        (line) => line?.startsWith('Display folds unavailable:') ?? false,
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugPrint = originalPrint;
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('injection', () {
    void iosTestWidgets(String description, WidgetTesterCallback callback) =>
        testWidgets(
          description,
          callback,
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
    late StreamController<FoldSnapshot> stream;
    late MediaQueryData observed;
    Future<void> mount(
      WidgetTester tester, {
      Size size = const Size(951, 669),
      bool engine = false,
    }) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
        child: RaftNativeDisplayFeatures(
          snapshots: stream.stream,
          engineReportsIosFolds: engine,
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    setUp(() {
      stream = StreamController<FoldSnapshot>.broadcast();
    });
    tearDown(() async {
      await stream.close();
    });
    iosTestWidgets(
      'features reach descendants, retain identity and preserve keyboard',
      (tester) async {
        await mount(tester);
        stream.add(snapshot());
        await tester.pump();
        await tester.pump();
        final features = observed.displayFeatures;
        expect(features, hasLength(1));
        expect(observed.viewInsets.bottom, 300);
        stream.add(snapshot());
        await tester.pump();
        await tester.pump();
        expect(identical(features, observed.displayFeatures), isTrue);
        stream.add(snapshot(hinge: 'fullyOpen'));
        await tester.pump();
        await tester.pump();
        expect(observed.displayFeatures, isEmpty);
        stream.add(snapshot());
        await tester.pump();
        await tester.pump();
        stream.addError(StateError('unavailable'));
        await tester.pump();
        await tester.pump();
        expect(observed.displayFeatures, isEmpty);
      },
    );
    iosTestWidgets('snapshot first then metrics rejects stale size', (
      tester,
    ) async {
      await mount(tester, size: const Size(669, 951));
      stream.add(snapshot());
      await tester.pump();
      await tester.pump();
      expect(observed.displayFeatures, isEmpty);
      await mount(tester);
      expect(observed.displayFeatures, hasLength(1));
    });
    iosTestWidgets('metrics first then snapshot rejects stale size', (
      tester,
    ) async {
      await mount(tester);
      stream.add(snapshot());
      await tester.pump();
      await tester.pump();
      await mount(tester, size: const Size(669, 951));
      expect(observed.displayFeatures, isEmpty);
      stream.add(
        FoldSnapshot.parse(
          payload(
            width: 669,
            height: 951,
            rect: const Rect.fromLTWH(0, 455, 669, 40),
          ),
        )!,
      );
      await tester.pump();
      await tester.pump();
      expect(observed.displayFeatures, hasLength(1));
    });
    for (final horizontal in [false, true]) {
      iosTestWidgets(
        'sub-point mismatch snaps spanning edge horizontal=$horizontal',
        (tester) async {
          await mount(
            tester,
            size: horizontal ? const Size(669.5, 951) : const Size(951, 669.5),
          );
          stream.add(
            horizontal
                ? FoldSnapshot.parse(
                    payload(
                      width: 669,
                      height: 951,
                      rect: const Rect.fromLTWH(0, 455, 669, 40),
                    ),
                  )!
                : snapshot(),
          );
          await tester.pump();
          await tester.pump();
          final bounds = observed.displayFeatures.single.bounds;
          expect(horizontal ? bounds.right : bounds.bottom, 669.5);
        },
      );
    }
    iosTestWidgets(
      'engine ownership disables subscription even with empty engine list',
      (tester) async {
        await mount(tester, engine: true);
        expect(stream.hasListener, isFalse);
        expect(observed.displayFeatures, isEmpty);
      },
    );
    testWidgets('non-iOS does not subscribe or replace engine features', (
      tester,
    ) async {
      await mount(tester);
      expect(stream.hasListener, isFalse);
    });
  });
}
