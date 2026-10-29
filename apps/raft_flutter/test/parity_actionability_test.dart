import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'parity/parity_harness.dart';

Map<String, dynamic> _case(String id) => {
  'id': id,
  'viewport': {'width': 320, 'height': 240, 'density': 1},
  'variants': [
    {'id': 'default', 'props': <String, dynamic>{}},
  ],
  'capture': {
    'androidInteractions': [
      {'type': 'tap', 'key': 'action'},
    ],
  },
};

void main() {
  setUpAll(loadParityFonts);

  testWidgets('tap scrolls a built action into the viewport before clicking', (
    t,
  ) async {
    final out = Directory.systemTemp.createTempSync('parity-action-scroll-');
    addTearDown(() => out.deleteSync(recursive: true));
    var taps = 0;
    Widget page() => CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 600)),
        SliverToBoxAdapter(
          child: TextButton(
            key: const ValueKey('action'),
            onPressed: () => taps++,
            child: const Text('Open'),
          ),
        ),
      ],
    );
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 240);
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: page()));
    await t.pump();
    expect(find.byKey(const ValueKey('action')), findsNothing);
    expect(
      find.byKey(const ValueKey('action'), skipOffstage: false),
      findsOneWidget,
    );
    await captureParityCase(
      t,
      visualCase: _case('scroll-action'),
      mapping: ParityCase(widgets: const ['TextButton'], build: (_) => page()),
      fixtures: const {},
      outputDir: out,
      runInfo: const {},
    );
    expect(taps, 1);
    expect(File('${out.path}/scroll-action.png').existsSync(), isTrue);
  });

  testWidgets('a crop marker releases its entry after the capture unmounts', (
    t,
  ) async {
    final out = Directory.systemTemp.createTempSync('parity-marker-lifecycle-');
    addTearDown(() => out.deleteSync(recursive: true));
    final visual = _case('marker-lifecycle')
      ..['capture'] = {
        'androidKey': 'states-crop',
        'contract': 'component-bounds',
        'androidInteractions': [
          {'type': 'mark', 'key': 'action', 'pad': 6},
        ],
      };
    await captureParityCase(
      t,
      visualCase: visual,
      mapping: ParityCase(
        widgets: const ['TextButton'],
        build: (_) => Center(
          child: TextButton(
            key: const ValueKey('action'),
            onPressed: () {},
            child: const Text('Marked'),
          ),
        ),
      ),
      fixtures: const {},
      outputDir: out,
      runInfo: const {},
    );
    expect(File('${out.path}/marker-lifecycle.png').existsSync(), isTrue);
    expect(find.byKey(const ValueKey('states-crop')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('focus reaches the button inside a keyboard listener wrapper', (
    t,
  ) async {
    final out = Directory.systemTemp.createTempSync('parity-button-focus-');
    addTearDown(() => out.deleteSync(recursive: true));
    final listener = FocusNode();
    final button = FocusNode();
    addTearDown(listener.dispose);
    addTearDown(button.dispose);
    var activations = 0;
    final visual = _case('button-focus')
      ..['capture'] = {
        'androidInteractions': [
          {'type': 'focus', 'key': 'action'},
        ],
      };
    await captureParityCase(
      t,
      visualCase: visual,
      mapping: ParityCase(
        widgets: const ['RaftControl'],
        build: (_) => Center(
          child: KeyedSubtree(
            key: const ValueKey('action'),
            child: Focus(
              focusNode: listener,
              skipTraversal: true,
              child: RaftControl(
                focusNode: button,
                onPressed: () => activations++,
                child: const Text('Activate'),
              ),
            ),
          ),
        ),
        interact: (t, _) async {
          expect(listener.hasPrimaryFocus, isFalse);
          expect(button.hasPrimaryFocus, isTrue);
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          await t.pump();
          expect(activations, 1);
        },
      ),
      fixtures: const {},
      outputDir: out,
      runInfo: const {},
    );
    expect(File('${out.path}/button-focus.png').existsSync(), isTrue);
  });

  testWidgets('an offstage action never produces a successful capture', (
    t,
  ) async {
    final out = Directory.systemTemp.createTempSync('parity-action-hidden-');
    addTearDown(() => out.deleteSync(recursive: true));
    var taps = 0;
    Object? failure;
    try {
      await captureParityCase(
        t,
        visualCase: _case('hidden-action'),
        mapping: ParityCase(
          widgets: const ['TextButton'],
          build: (_) => Offstage(
            child: TextButton(
              key: const ValueKey('action'),
              onPressed: () => taps++,
              child: const Text('Hidden'),
            ),
          ),
        ),
        fixtures: const {},
        outputDir: out,
        runInfo: const {},
      );
    } on StateError catch (error) {
      failure = error;
    }
    expect(failure, isA<StateError>());
    expect(taps, 0);
    expect(File('${out.path}/hidden-action.png').existsSync(), isFalse);
  });
}
