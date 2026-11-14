import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 / raft-ui 0.95.3 desktop density ("with a mouse from 768px; touch
/// is unchanged"): buttons, fields and switches are one 34px control height
/// (switch 38x22) and the field text is 14px; a phone width or a touch screen
/// keeps 32px, 13px and the 32x20 switch. The families read the window and the
/// input from the context; no call site passes either.
Future<void> _mount(
  WidgetTester t,
  Widget child, {
  required Size size,
  required TargetPlatform platform,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
  await t.pump(const Duration(seconds: 1));
}

void main() {
  const wide = Size(1000, 800);
  const narrow = Size(600, 800);
  final controls = <String, Widget Function()>{
    'button': () => RaftButton(label: 'Save', onPressed: () {}),
    'switch': () => RaftSwitch(value: true, onChanged: (_) {}),
    'input': () => const SizedBox(width: 240, child: RaftTextInput()),
  };

  Size sizeOf(WidgetTester t, String name) => t.getSize(
    find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() ==
          switch (name) {
            'button' => 'RaftButton',
            'switch' => 'RaftSwitch',
            _ => 'RaftTextInput',
          },
    ),
  );

  for (final name in controls.keys) {
    testWidgets('$name: 34px class on desktop, unchanged on touch', (t) async {
      await _mount(
        t,
        controls[name]!(),
        size: narrow,
        platform: TargetPlatform.linux,
      );
      final base = sizeOf(t, name);
      await _mount(
        t,
        controls[name]!(),
        size: wide,
        platform: TargetPlatform.android,
      );
      expect(sizeOf(t, name), base, reason: 'touch keeps the base size');
      await _mount(
        t,
        controls[name]!(),
        size: wide,
        platform: TargetPlatform.linux,
      );
      final desktop = sizeOf(t, name);
      expect(desktop, isNot(base), reason: '$name takes the desktop metrics');
      switch (name) {
        case 'button':
          expect(desktop.height, 34);
          expect(base.height, 32);
        case 'switch':
          expect(desktop, const Size(38, 22));
        default:
          expect(desktop.height, 34);
      }
    });
  }
}
