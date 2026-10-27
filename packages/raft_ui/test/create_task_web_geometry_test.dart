import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });

  Future<void> openTask(
    WidgetTester t, {
    required bool dark,
    required int count,
  }) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final titles = List.generate(
      count,
      (i) => TextEditingController(text: 'Task $i'),
    );
    addTearDown(() {
      for (final c in titles) {
        c.dispose();
      }
    });
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(dark: dark).copyWith(platform: TargetPlatform.linux),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('task-capture'),
          child: RaftTextScaling(child: child!),
        ),
        home: Scaffold(
          body: RaftCreateTaskDialogView(
            titles: titles,
            filledCount: count,
            onClose: () {},
            onSubmit: () {},
            onAddRow: () {},
            onRemoveRow: (_) {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  for (final dark in [false, true]) {
    for (final count in [1, 2]) {
      testWidgets('Web task card dimensions dark=$dark rows=$count', (t) async {
        await openTask(t, dark: dark, count: count);
        final card = t.getRect(
          find.byKey(const ValueKey('create-task-dialog')),
        );
        expect(card.width, 448);
        expect(
          card.height,
          count == 1 ? 226 : 278,
          reason: 'Web card element at the same 1280×800 viewport',
        );
      });
    }
    testWidgets('Web task action heights and spacing dark=$dark', (t) async {
      await openTask(t, dark: dark, count: 2);
      final cancel = t.getRect(
        find.byKey(const ValueKey('create-task-cancel')),
      );
      final submit = t.getRect(
        find.byKey(const ValueKey('create-task-submit')),
      );
      expect(cancel.height, 44);
      expect(submit.height, 44);
      expect(submit.left - cancel.right, 8);
    });
    testWidgets('Web task title rows use 8px gap dark=$dark', (t) async {
      await openTask(t, dark: dark, count: 2);
      Finder input(int index) => find.ancestor(
        of: find.byKey(ValueKey('create-task-title-$index')),
        matching: find.byType(RaftDialogTextInput),
      );
      final first = t.getRect(input(0));
      final second = t.getRect(input(1));
      expect(second.top - first.bottom, 8);
    });
    testWidgets(
      'Web task ghost actions paint no border or red fill dark=$dark',
      (t) async {
        await openTask(t, dark: dark, count: 2);
        final card = t.getRect(
          find.byKey(const ValueKey('create-task-dialog')),
        );
        final cancel = t.getRect(
          find.byKey(const ValueKey('create-task-cancel')),
        );
        final remove = t.getRect(
          find.byKey(const ValueKey('create-task-remove-0')),
        );
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('task-capture')),
        );
        final pixels = await t.runAsync(() async {
          final image = await boundary.toImage();
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          List<int> at(Offset p) {
            final offset = (p.dy.floor() * image.width + p.dx.floor()) * 4;
            return [for (var i = 0; i < 4; i++) data.getUint8(offset + i)];
          }

          final values = [
            at(Offset(card.left + 20, card.bottom - 8)),
            at(Offset(cancel.center.dx, cancel.top + 1)),
            at(Offset(remove.center.dx, remove.top + 1)),
          ];
          image.dispose();
          return values;
        });
        expect(pixels![1], pixels[0], reason: 'Cancel is a ghost button');
        expect(pixels[2], pixels[0], reason: 'Remove is a ghost button');
      },
    );
  }
}
