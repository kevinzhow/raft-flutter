import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.linux,
  ValueChanged<String>? open,
}) => MaterialApp(
  theme: raftTheme().copyWith(platform: platform),
  home: RaftLinkScope(
    open: (context, href) async => open?.call(href),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

RaftSettingsAbout _about({
  VoidCallback? onAndroid,
  VoidCallback? onIos,
  String? qrUrl = 'https://raft.build/download',
}) => RaftSettingsAbout(
  version: '1.24.0',
  mobileApp: RaftAboutMobileApp(
    onAndroid: onAndroid ?? () {},
    onIos: onIos ?? () {},
    qrUrl: qrUrl,
  ),
);

void main() {
  testWidgets('computer: QR first with its sentence, then the three links', (
    t,
  ) async {
    // The test font is wide: give the three links room for one line.
    t.view.physicalSize = const Size(1800, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final calls = <String>[];
    await t.pumpWidget(
      _host(
        _about(onAndroid: () => calls.add('apk'), onIos: () => calls.add('ios')),
        open: calls.add,
      ),
    );
    final qr = find.byKey(const ValueKey('mobile-download-qr'));
    final sentence = find.text("Scan with your phone's camera.");
    expect(qr, findsOneWidget);
    expect(sentence, findsOneWidget);
    expect(find.text('Or, Scan with your phone'), findsNothing);
    // The sentence sits beside the code, to its right.
    expect(
      t.getTopLeft(sentence).dx,
      greaterThanOrEqualTo(t.getTopRight(qr).dx),
    );
    // One line of links under it, in this order.
    final links = [
      for (final label in [
        'Download on the App Store',
        'Get it on Google Play',
        'Download Android APK',
      ])
        t.getTopLeft(find.text(label)),
    ];
    expect(links[0].dx, lessThan(links[1].dx));
    expect(links[1].dx, lessThan(links[2].dx));
    expect(links[0].dy, links[2].dy);
    expect(links[0].dy, greaterThan(t.getBottomLeft(qr).dy));
    // No store button on a computer.
    expect(find.byType(RaftRecipeButton), findsNothing);

    await t.tap(find.text('Get it on Google Play'));
    await t.tap(find.text('Download on the App Store'));
    await t.tap(find.text('Download Android APK'));
    expect(calls, [
      'https://play.google.com/store/apps/details?id=build.raft.app',
      'ios',
      'apk',
    ]);
  });

  for (final (platform, store, others) in [
    (
      TargetPlatform.android,
      'Get it on Google Play',
      ['Download on the App Store', 'Download Android APK'],
    ),
    (
      TargetPlatform.iOS,
      'Download on the App Store',
      ['Get it on Google Play', 'Download Android APK'],
    ),
  ]) {
    testWidgets('$platform phone: its store as a button, the others as links, no QR', (
      t,
    ) async {
      await t.pumpWidget(_host(_about(), platform: platform));
      expect(find.byKey(const ValueKey('mobile-download-qr')), findsNothing);
      expect(find.text("Scan with your phone's camera."), findsNothing);
      final button = find.byType(RaftRecipeButton);
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text(store)),
        findsOneWidget,
      );
      for (final label in others) {
        expect(find.text(label), findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.text(label)),
          findsNothing,
        );
      }
      // The store is the button, not also a link.
      expect(find.text(store), findsOneWidget);
    });
  }

  testWidgets('Version card links to the source code and names the license', (
    t,
  ) async {
    final opened = <String>[];
    await t.pumpWidget(
      _host(
        const RaftSettingsAbout(version: '1.24.0'),
        open: opened.add,
      ),
    );
    expect(find.text('Raft License'), findsOneWidget);
    await t.tap(find.text('Source code'));
    expect(opened, ['https://github.com/botiverse/raft-source']);
    // Source code sits inside the Version card, under the version.
    expect(
      t.getTopLeft(find.text('Source code')).dy,
      greaterThan(t.getTopLeft(find.text('1.24.0')).dy),
    );
  });
}
