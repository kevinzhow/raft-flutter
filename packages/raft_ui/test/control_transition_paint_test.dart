import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

var frameSequence = 0;
const evidencePath = String.fromEnvironment('RAFT_TRANSITION_REPORT');

Future<Color> pixel(WidgetTester tester, Offset position) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('paint')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final index = (position.dy.floor() * image.width + position.dx.floor()) * 4;
    final result = Color.fromARGB(
      data.getUint8(index + 3),
      data.getUint8(index),
      data.getUint8(index + 1),
      data.getUint8(index + 2),
    );
    if (evidencePath.isNotEmpty) {
      final dir = Directory(
        evidencePath == 'cache'
            ? '${Directory.systemTemp.path}/raft-transition-proof'
            : evidencePath,
      );
      await dir.create(recursive: true);
      final id = '${frameSequence++}'.padLeft(4, '0');
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('${dir.path}/frame-$id.png')
          .writeAsBytes(png.buffer.asUint8List());
      await File('${dir.path}/frames.jsonl').writeAsString(
        '${jsonEncode({
          'frame': id,
          'sample': [position.dx, position.dy],
          'rgba': result.toARGB32(),
          'width': image.width,
          'height': image.height,
        })}\n',
        mode: FileMode.append,
      );
    }
    image.dispose();
    return result;
  }))!;
}

Future<void> expectTransition(
  WidgetTester tester,
  Offset sample,
  Color from,
  Color to,
) async {
  final failures = <String>[];
  for (var frame = 0; frame <= 15; frame++) {
    final actual = await pixel(tester, sample);
    for (final channel in ['r', 'g', 'b']) {
      double component(Color c) => switch (channel) {
        'r' => c.r,
        'g' => c.g,
        _ => c.b,
      };
      final low = component(from) < component(to)
          ? component(from)
          : component(to);
      final high = component(from) > component(to)
          ? component(from)
          : component(to);
      if (component(actual) < low - 1 / 255 ||
          component(actual) > high + 1 / 255) {
        failures.add(
          'frame=$frame channel=$channel from=$from to=$to actual=$actual',
        );
      }
    }
    await tester.pump(const Duration(milliseconds: 8));
  }
  expect(
    failures,
    isEmpty,
    reason: 'Every transition frame must stay within its endpoint colors.',
  );
}

Widget paintHost(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: const ValueKey('paint'),
        child: ColoredBox(
          color: theme.extension<RaftTokens>()!.colors['layer-canvas-muted']!,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  ),
);

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark hover exit has no dark interior frame', (
      tester,
    ) async {
      final theme = raftTheme(family, dark: dark);
      final tokens = theme.extension<RaftTokens>()!;
      const rowKey = ValueKey('channel');
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const ValueKey('paint'),
                child: ColoredBox(
                  color: tokens.colors['layer-canvas-muted']!,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 300,
                      child: RaftNavItem(
                        key: rowKey,
                        label: 'Channel',
                        glyph: RaftGlyph.hash,
                        conversationKind: RaftConversationNavKind.channel,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const sample = Offset(280, 28);
      final idle = await pixel(tester, sample);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(600, 500));
      await mouse.moveTo(tester.getCenter(find.byKey(rowKey)));
      await tester.pumpAndSettle();
      final hover = await pixel(tester, sample);
      await mouse.moveTo(const Offset(600, 500));
      await tester.pump();
      await expectTransition(tester, sample, hover, idle);
      await mouse.removePointer();
    });

    testWidgets('$family/$dark switching mobile tabs has no black frame', (
      tester,
    ) async {
      final theme = raftTheme(family, dark: dark);
      var selected = 'home';
      late StateSetter update;
      await tester.pumpWidget(
        paintHost(
          theme,
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 320,
                child: RaftMobileNav(
                  items: const [
                    RaftMobileNavItem(
                      id: 'home',
                      label: 'Home',
                      glyph: RaftGlyph.home,
                      key: ValueKey('home'),
                    ),
                    RaftMobileNavItem(
                      id: 'tasks',
                      label: 'Tasks',
                      glyph: RaftGlyph.squareCheck,
                      key: ValueKey('tasks'),
                    ),
                  ],
                  selectedId: selected,
                  onSelected: (id) => setState(() => selected = id),
                  bottomInset: 0,
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const ValueKey('home')));
      final sample = family == RaftFamily.brutal
          ? rect.topLeft + const Offset(8, 8)
          : rect.center - const Offset(13, 13);
      final active = await pixel(tester, sample);
      update(() => selected = 'tasks');
      await tester.pumpAndSettle();
      final idle = await pixel(tester, sample);
      update(() => selected = 'home');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tasks')));
      await tester.pump();
      await expectTransition(tester, sample, active, idle);
      expect(selected, 'tasks');
      // Rapid reversal must use the current paint, without exposing the shadow.
      await tester.tap(find.byKey(const ValueKey('home')));
      await tester.pump();
      await expectTransition(tester, sample, active, idle);
      expect(selected, 'home');
    });

    testWidgets(
      '$family/$dark menu open close leaves selected sidebar paint stable',
      (tester) async {
        final theme = raftTheme(family, dark: dark);
        final controller = RaftMenuController();
        var clicks = 0;
        await tester.pumpWidget(
          paintHost(
            theme,
            SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RaftNavItem(
                    key: const ValueKey('selected'),
                    label: 'Selected channel',
                    glyph: RaftGlyph.hash,
                    conversationKind: RaftConversationNavKind.channel,
                    selected: true,
                    onTap: () => clicks++,
                  ),
                  const SizedBox(height: 12),
                  RaftDropdownMenu(
                    label: 'Actions',
                    controller: controller,
                    entries: [
                      RaftMenuEntry(label: 'Copy', onPressed: () => clicks++),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        const sample = Offset(280, 28);
        final active = await pixel(tester, sample);
        await tester.tap(find.text('Actions'));
        await tester.pump();
        await expectTransition(tester, sample, active, active);
        expect(controller.isOpen, true);
        await tester.tap(find.text('Copy'));
        await tester.pump();
        await expectTransition(tester, sample, active, active);
        expect(controller.isOpen, false);
        expect(clicks, 1);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
