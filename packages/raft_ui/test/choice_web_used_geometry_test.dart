import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';
import 'package:raft_ui/src/recipes/select.g.dart';

// Web db5e399 / published raft-ui0.7.0: Segment item border-[1.5px]
// has a1px used border atDPR1 or Playwright-emulatedDPR3. The actual
// Public/Private track is192.58×38. Select chrome=field overrides default
// pl3.5 withpx3; this must not turn the default's14px into12px.
void main() {
  setUpAll(() async {
    ByteData data;
    try {
      data = await rootBundle.load(
        'packages/raft_ui/assets/fonts/SpaceGrotesk.ttf',
      );
    } on FlutterError {
      data = await rootBundle.load('assets/fonts/SpaceGrotesk.ttf');
    }
    final font = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(Future.value(data));
    await font.load();
  });

  Widget host(Widget child, {bool dark = false, double scale = 1}) =>
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: RaftTextScaling(child: child!),
        ),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      );

  void view(WidgetTester t, double dpr, bool emulated) {
    final original = RaftBorderSnap.emulatedDeviceScaleFactor;
    RaftBorderSnap.emulatedDeviceScaleFactor = emulated;
    t.view.physicalSize = Size(900 * dpr, 800 * dpr);
    t.view.devicePixelRatio = dpr;
    addTearDown(() {
      RaftBorderSnap.emulatedDeviceScaleFactor = original;
      t.view.reset();
    });
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
  }

  RaftSegmentedControl<String> segment({
    ValueChanged<String>? change,
    bool disabled = false,
  }) => RaftSegmentedControl<String>(
    value: 'public',
    legacyStyle: RaftSegmentedStyle.recipe,
    onChanged: change,
    disabled: disabled,
    items: const [
      RaftSegmentedOption(
        value: 'public',
        glyph: RaftGlyph.hash,
        label: 'Public',
        itemKey: ValueKey('public'),
      ),
      RaftSegmentedOption(
        value: 'private',
        glyph: RaftGlyph.lock,
        label: 'Private',
        itemKey: ValueKey('private'),
      ),
    ],
  );

  for (final dark in raftThemeMatrix([false, true])) {
    for (final (dpr, emulated, border) in [
      (1.0, false, 1.0),
      (3.0, true, 1.0),
      (3.0, false, 4 / 3),
    ]) {
      testWidgets(
        'canonical segment used border dark=$dark dpr=$dpr emulated=$emulated',
        (t) async {
          view(t, dpr, emulated);
          await t.pumpWidget(host(segment(change: (_) {}), dark: dark));
          await t.pumpAndSettle();
          final a = find.byKey(const ValueKey('public'));
          final b = find.byKey(const ValueKey('private'));
          final face =
              t
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: a,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration;
          expect((face.border! as Border).top.width, closeTo(border, 1e-9));
          expect(
            t.getTopLeft(find.text('Public')).dx - t.getTopLeft(a).dx,
            closeTo(34 + border, .01),
          );
          expect(t.getSize(a).height, 32);
          expect(t.getRect(b).left - t.getRect(a).right, 2);
          expect(t.getSize(find.byType(RaftSegmentedTrack)).height, 38);
          if (border == 1) {
            expect(t.getSize(a).width, closeTo(89.67, .03));
            expect(t.getSize(b).width, closeTo(94.91, .03));
            expect(
              t.getSize(find.byType(RaftSegmentedTrack)).width,
              closeTo(192.58, .03),
            );
          }
          expect(t.takeException(), isNull);
        },
      );
    }

    testWidgets('select generated field padding retains default dark=$dark', (
      t,
    ) async {
      view(t, 1, false);
      for (final (chrome, padding) in [
        (RaftSelectRecipeChrome.field, 12.0),
        (RaftSelectRecipeChrome.default_, 14.0),
      ]) {
        await t.pumpWidget(
          host(
            SizedBox(
              width: 408,
              child: RaftSelectField<String>(
                chrome: chrome,
                value: 'a',
                items: const [RaftSelectItem(value: 'a', label: 'Alpha')],
                onChanged: (_) {},
              ),
            ),
            dark: dark,
          ),
        );
        await t.pumpAndSettle();
        final trigger = find.byType(RaftSelectField<String>);
        final box = t.widget<RaftRecipeBox>(
          find
              .descendant(of: trigger, matching: find.byType(RaftRecipeBox))
              .first,
        );
        expect(box.style.padding.left, padding);
        expect(box.style.padding.right, 12);
        expect(t.getSize(trigger).height, 44);
        // Root content must begin after the CSS used border, not authored1.5.
        expect(
          t.getTopLeft(find.text('Alpha')).dx - t.getTopLeft(trigger).dx,
          padding + 1,
        );
      }
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'select field remains inert when disabled and grows with text dark=$dark',
      (t) async {
        view(t, 1, false);
        var changes = 0;
        Widget select(bool enabled) => SizedBox(
          width: 408,
          child: RaftSelectField<String>(
            chrome: RaftSelectRecipeChrome.field,
            value: 'a',
            items: const [RaftSelectItem(value: 'a', label: 'Alpha')],
            onChanged: enabled ? (_) => changes++ : null,
          ),
        );
        await t.pumpWidget(host(select(false), dark: dark));
        await t.tap(find.text('Alpha'));
        await t.pump();
        expect(find.text('Alpha'), findsOneWidget);
        expect(changes, 0);
        await t.pumpWidget(host(select(true), dark: dark, scale: 3.1));
        await t.pumpAndSettle();
        expect(
          t.getSize(find.byType(RaftSelectField<String>)).height,
          greaterThan(44),
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'canonical segment disabled and large text retain actions and growth',
    (t) async {
      view(t, 1, false);
      final changes = <String>[];
      await t.pumpWidget(host(segment(change: changes.add, disabled: true)));
      await t.pumpAndSettle();
      await t.tap(find.text('Private'));
      expect(changes, isEmpty);
      await t.pumpWidget(host(segment(change: changes.add), scale: 3.1));
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byType(RaftSegmentedTrack)).height,
        greaterThan(38),
      );
      await t.tap(find.text('Private'));
      expect(changes, ['private']);
      expect(t.takeException(), isNull);
    },
  );
}
