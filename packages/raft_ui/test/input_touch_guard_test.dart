import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/tap_slop.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/raft_ui/SpaceGrotesk')
      ..addFont(
        rootBundle.load('packages/raft_ui/assets/fonts/SpaceGrotesk.ttf'),
      );
    await loader.load();
  });

  for (final platform in [TargetPlatform.linux, TargetPlatform.android]) {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      testWidgets(
        '$platform $direction visible input edge wins; adjacent action stays usable',
        (t) async {
          final controller = TextEditingController(text: 'draft');
          final node = FocusNode();
          var action = 0;
          var tapped = 0;
          addTearDown(controller.dispose);
          addTearDown(node.dispose);
          addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme().copyWith(platform: platform),
              builder: (context, child) =>
                  Directionality(textDirection: direction, child: child!),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: RaftTapSlopHost(
                      child: Row(
                        children: [
                          Expanded(
                            child: RaftTextInput(
                              key: const ValueKey('input-box'),
                              fieldKey: const ValueKey('input'),
                              controller: controller,
                              focusNode: node,
                              onTap: () => tapped++,
                            ),
                          ),
                          const SizedBox(width: 4),
                          RaftButton(
                            key: const ValueKey('action'),
                            glyph: RaftGlyph.trash2,
                            uiVariant: RaftButtonVariant.ghost,
                            uiSize: RaftButtonSize.iconSm,
                            semanticLabel: 'Remove',
                            onPressed: () => action++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          final input = t.getRect(find.byKey(const ValueKey('input-box')));
          final button = t.getRect(find.byKey(const ValueKey('action')));
          final inputEdge = direction == TextDirection.ltr
              ? input.right - 2
              : input.left + 2;
          await t.tapAt(Offset(inputEdge, input.center.dy));
          await t.pumpAndSettle();
          expect(node.hasFocus, isTrue);
          expect(tapped, 1);
          expect(action, 0);
          await t.tapAt(input.center);
          await t.pumpAndSettle();
          expect(tapped, 2, reason: 'the editable invokes onTap only once');
          await t.enterText(
            find.byKey(const ValueKey('input')),
            'edited draft',
          );
          expect(controller.text, 'edited draft');
          if (platform == TargetPlatform.android) {
            final gapEdge = direction == TextDirection.ltr
                ? button.left - 2
                : button.right + 2;
            await t.tapAt(Offset(gapEdge, button.center.dy));
            await t.pumpAndSettle();
            expect(
              action,
              1,
              reason: 'the free gap remains part of the touch target',
            );
          }
          await t.tap(find.byKey(const ValueKey('action')));
          await t.pumpAndSettle();
          expect(action, platform == TargetPlatform.android ? 2 : 1);
          expect(controller.text, 'edited draft');
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('a trailing action still wins inside its visible bounds', (
    t,
  ) async {
    final node = FocusNode();
    var action = 0;
    var tapped = 0;
    addTearDown(node.dispose);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: RaftTapSlopHost(
                child: RaftTextInput(
                  focusNode: node,
                  onTap: () => tapped++,
                  trailing: RaftButton(
                    key: const ValueKey('trailing'),
                    glyph: RaftGlyph.x,
                    uiSize: RaftButtonSize.iconSm,
                    onPressed: () => action++,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('trailing')));
    await t.pumpAndSettle();
    expect(action, 1);
    expect(tapped, 0);
    expect(node.hasFocus, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('disabled input border cannot activate its neighbour', (t) async {
    final node = FocusNode();
    var action = 0;
    var tapped = 0;
    addTearDown(node.dispose);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: RaftTapSlopHost(
                child: Row(
                  children: [
                    Expanded(
                      child: RaftTextInput(
                        key: const ValueKey('disabled'),
                        enabled: false,
                        focusNode: node,
                        onTap: () => tapped++,
                      ),
                    ),
                    const SizedBox(width: 4),
                    RaftButton(
                      glyph: RaftGlyph.trash2,
                      uiSize: RaftButtonSize.iconSm,
                      onPressed: () => action++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final input = t.getRect(find.byKey(const ValueKey('disabled')));
    await t.tapAt(Offset(input.right - 2, input.center.dy));
    await t.pumpAndSettle();
    expect(node.hasFocus, isFalse);
    expect(tapped, 0);
    expect(action, 0);
    expect(t.takeException(), isNull);
  });

  testWidgets('interactive overlay wins over neighbouring expansion', (
    t,
  ) async {
    final node = FocusNode();
    var action = 0;
    var overlay = 0;
    addTearDown(node.dispose);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 44,
              child: RaftTapSlopHost(
                child: Stack(
                  children: [
                    RaftTextInput(focusNode: node),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => overlay++,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 6,
                      child: RaftTapSlopAnchor(
                        minSize: const Size.square(48),
                        child: RaftButton(
                          key: const ValueKey('overlay-action'),
                          glyph: RaftGlyph.trash2,
                          uiSize: RaftButtonSize.iconSm,
                          onPressed: () => action++,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final button = t.getRect(find.byKey(const ValueKey('overlay-action')));
    await t.tapAt(Offset(button.left - 2, button.center.dy));
    await t.pumpAndSettle();
    // The full-area overlay handles taps here, so this is not an empty gap.
    expect(action, 0);
    expect(overlay, 1);
    expect(node.hasFocus, isFalse);
    await t.tapAt(button.center);
    await t.pumpAndSettle();
    expect(action, 1);
    expect(overlay, 1);
    expect(node.hasFocus, isFalse);
    expect(t.takeException(), isNull);
  });

  testWidgets('dragging from the input edge still scrolls', (t) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: RaftTapSlopHost(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      const RaftTextInput(key: ValueKey('scroll-input')),
                      const SizedBox(height: 700),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final input = t.getRect(find.byKey(const ValueKey('scroll-input')));
    await t.dragFrom(
      Offset(input.right - 2, input.center.dy),
      const Offset(0, -90),
    );
    await t.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(t.takeException(), isNull);
  });
}
