import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Widget host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: Center(child: child)),
);

final aliases = <String, Widget Function(VoidCallback?)>{
  'Button': (f) => RaftButton(label: 'Action', onPressed: f),
  'Control': (f) => RaftControl(onPressed: f, child: const Text('Action')),
  'Recipe': (f) => RaftRecipeButton(label: 'Action', onPressed: f),
  'Text': (f) => RaftTextButton(label: 'Action', onPressed: f),
  'Icon': (f) =>
      RaftIconButton(glyph: RaftGlyph.plus, tooltip: 'Action', onPressed: f),
  'Close': (f) => RaftCloseButton(onPressed: f),
  'Glyph': (f) => RaftGlyphButton(
    glyph: RaftGlyph.plus,
    semanticLabel: 'Action',
    onPressed: f,
  ),
  'Panel': (f) => RaftPanelIconButton(tooltip: 'Action', onPressed: f),
  'Composer': (f) => RaftComposerToolButton(
    glyph: RaftGlyph.plus,
    tooltip: 'Action',
    onPressed: f,
  ),
  'Lightbox': (f) => RaftLightboxIconAction(
    glyph: RaftGlyph.plus,
    label: 'Action',
    onPressed: f,
  ),
};

void main() {
  testWidgets('an equivalent Button rebuild schedules no colour animation', (
    t,
  ) async {
    late StateSetter rebuild;
    await t.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return RaftButton(label: 'Stable', onPressed: () {});
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    rebuild(() {});
    await t.pump();
    expect(t.binding.hasScheduledFrame, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  for (final look in [
    (elegantThemePackId, false),
    (elegantThemePackId, true),
    (brutalThemePackId, false),
  ]) {
    testWidgets('frozen Material styles never mount another input $look', (
      t,
    ) async {
      var count = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: packForThemeId(look.$1), dark: look.$2),
          home: Scaffold(
            body: Column(
              children: [
                RaftButton.text(
                  onPressed: () => count++,
                  child: const Text('Text action'),
                ),
                RaftButton.outlined(
                  onPressed: () => count++,
                  child: const Text('Outline action'),
                ),
                RaftButton.iconAction(
                  onPressed: () => count++,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(RaftInteractive), findsNWidgets(3));
      for (final button in find.byType(RaftButton).evaluate().toList()) {
        await t.tap(find.byWidget(button.widget));
      }
      expect(count, 3, reason: 'Each canonical input activates exactly once.');
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('small icon aliases use the current Button icon size', (t) async {
    await t.pumpWidget(
      host(
        RaftIconButton(
          glyph: RaftGlyph.plus,
          visualSize: RaftMetrics.buttonXs,
          onPressed: () {},
        ),
      ),
    );
    expect(t.getSize(find.byType(RaftIconButton)), const Size.square(32));
  });

  testWidgets('composer button uses Button geometry and keeps editor focus', (
    t,
  ) async {
    final editor = FocusNode();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      editor.dispose();
    });
    await t.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(focusNode: editor),
            RaftComposerToolButton(
              glyph: RaftGlyph.plus,
              tooltip: 'Attach',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    editor.requestFocus();
    await t.pump();
    expect(
      t.getSize(find.byType(RaftComposerToolButton)),
      const Size.square(32),
    );
    await t.tap(find.byType(RaftComposerToolButton));
    expect(editor.hasFocus, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('disabled text alias uses the disabled recipe ink', (t) async {
    await t.pumpWidget(host(const RaftTextButton(label: 'Action')));
    final label = find.text('Action');
    final paragraph = t.renderObject<RenderParagraph>(label);
    final context = t.element(label);
    final expected = RaftTokens.of(context).colors['foreground-disabled'];
    expect((paragraph.text as TextSpan).style!.color, expected);
    await t.pumpWidget(const SizedBox());
  });

  for (final device in [
    (TargetPlatform.macOS, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    for (final entry in aliases.entries) {
      testWidgets(
        '${entry.key} activation and disabled input ${device.$1}/${device.$2}',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = device.$2;
          addTearDown(t.view.reset);
          final semantics = t.ensureSemantics();
          try {
            var count = 0, disabled = false;
            late StateSetter update;
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(platform: device.$1),
                home: Scaffold(
                  body: Center(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return KeyedSubtree(
                          key: const Key('action'),
                          child: entry.value(disabled ? null : () => count++),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            final action = find.byKey(const Key('action'));
            final buttonSemantics = find.descendant(
              of: action,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.button == true,
              ),
            );
            await t.sendKeyEvent(LogicalKeyboardKey.tab);
            await t.pumpAndSettle();
            expect(
              t.getSemantics(buttonSemantics.first).flagsCollection.isButton,
              isTrue,
            );
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            expect(count, 2);
            final pointer = await t.startGesture(t.getCenter(action));
            await pointer.moveBy(const Offset(200, 200));
            await pointer.cancel();
            await t.pumpAndSettle();
            expect(count, 2, reason: 'A cancelled press never activates.');
            await t.tap(action);
            await t.pumpAndSettle();
            expect(count, 3);
            update(() => disabled = true);
            await t.pumpAndSettle();
            expect(
              t.getSemantics(buttonSemantics.first).flagsCollection.isEnabled,
              Tristate.isFalse,
            );
            await t.tap(action);
            await t.sendKeyEvent(LogicalKeyboardKey.enter);
            await t.sendKeyEvent(LogicalKeyboardKey.space);
            expect(
              count,
              3,
              reason:
                  'Disabled aliases reject pointer and keyboard activation.',
            );
            await t.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'loading preserves composed content bounds and accessible name $dark',
      (t) async {
        final semantics = t.ensureSemantics();
        try {
          var busy = false, count = 0;
          late StateSetter update;
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(dark: dark),
              home: Scaffold(
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return RaftButton(
                        key: const Key('save'),
                        busy: busy,
                        semanticLabel: 'Save changes',
                        leading: const RaftIcon(RaftGlyph.plus, size: 16),
                        onPressed: () => count++,
                        child: const Text('Save changes'),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          final action = find.byKey(const Key('save'));
          final before = t.getRect(action);
          update(() => busy = true);
          await t.pump();
          await t.pump(const Duration(milliseconds: 200));
          expect(t.getRect(action), before);
          expect(t.getSemantics(action).label, 'Save changes');
          expect(t.getSemantics(action).value, 'Loading');
          await t.tap(action);
          await t.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(count, 0);
          update(() => busy = false);
          await t.pumpAndSettle();
          await t.tap(action);
          expect(count, 1);
          await t.pumpWidget(const SizedBox());
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'composed row keeps nested action, context menu and cancellation separate',
    (t) async {
      var outer = 0, inner = 0, menu = 0;
      await t.pumpWidget(
        host(
          RaftListRowAction(
            onPressed: () => outer++,
            onLongPress: () => menu++,
            onSecondaryTapDown: (_) => menu++,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: RaftButton(label: 'Inner', onPressed: () => inner++),
            ),
          ),
        ),
      );
      await t.tap(find.text('Inner'));
      expect(inner, 1);
      expect(outer, 0);
      final position =
          t.getTopLeft(find.byType(RaftListRowAction)) + const Offset(4, 4);
      final pointer = await t.startGesture(position);
      await t.pump(kLongPressTimeout);
      await pointer.up();
      expect(menu, 1);
      expect(outer, 0);
      await t.tapAt(
        position,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      expect(menu, 2);
      expect(outer, 0);
      await t.pumpWidget(const SizedBox());
    },
  );
}
