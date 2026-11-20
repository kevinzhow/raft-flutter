import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Composer values of raft-ui 0.95.3 (composer.recipe, composer-suggestion
// list). Input mode comes from RaftInteractionScope, never from width.

const _touch = [Size(856, 944), Size(944, 856)];
const _mouse = [Size(390, 844), Size(1440, 900)];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  required bool touch,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RaftInteractionScope(
      interaction: touch
          ? RaftInteraction.touchMode
          : RaftInteraction.pointerMode,
      child: MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _composer({List<RaftComposerSuggestion> suggestions = const []}) =>
    RaftComposer(
      onSend: (_) async => true,
      onAttach: () {},
      onImagePick: () {},
      suggestions: suggestions,
    );

RaftComposerRecipe _recipe(WidgetTester tester) {
  final t = RaftTokens.of(tester.element(find.byType(RaftComposer)));
  return RaftComposerRecipe(t, desktop: t.desktop);
}

void main() {
  for (final (size, touch) in [
    for (final s in _touch) (s, true),
    for (final s in _mouse) (s, false),
  ]) {
    final label =
        '${size.width.toInt()}x${size.height.toInt()} '
        '${touch ? 'touch' : 'mouse'}';
    final wide = size.width >= 768;
    group('composer $label', () {
      testWidgets('Raft values', (tester) async {
        await _pump(tester, _composer(), size: size, touch: touch);
        final r = _recipe(tester);
        final fine = wide && !touch;
        expect(r.shellInset.bottom, 5);
        expect(r.toolbarGap, 6);
        expect(r.actionGap, 6);
        expect(r.metaGap, 8);
        expect(r.actionFace, fine ? 28 : 32);
        expect(r.firstActionOffset, fine ? -5 : -7);
        // Pointer-fine is the desktop token variant, never width alone.
        expect(r.tokens.desktop, fine);
      });

      testWidgets('first action bleeds out at both ends', (tester) async {
        await _pump(tester, _composer(), size: size, touch: touch);
        final r = _recipe(tester);
        final shell = tester.getRect(
          find.byKey(const ValueKey('composer-shell-slot')),
        );
        final stroke = r.shellStroke;
        final first = tester.getRect(find.byType(RaftComposerAction).first);
        final submit = tester.getRect(
          find.byKey(const ValueKey('composer-submit')),
        );
        final inset = r.shellInset.left + stroke;
        expect(
          first.left - shell.left,
          closeTo(inset + r.firstActionOffset, .01),
        );
        expect(
          shell.right - submit.right,
          closeTo(inset + r.firstActionOffset, .01),
        );
        expect(first.width, r.actionFace);
        final attach = tester.getRect(find.byType(RaftComposerAction).at(1));
        expect(attach.left - first.right, 6);
      });

      testWidgets('suggestion list values', (tester) async {
        await _pump(tester, _composer(), size: size, touch: touch);
        final r = _recipe(tester);
        final t = r.tokens;
        expect(r.suggestionMaximum, 240);
        expect(r.suggestionBottomGap, 8);
        expect(r.suggestionDecoration.borderRadius, BorderRadius.circular(10));
        expect(
          r.suggestionDecoration.boxShadow,
          contains(BoxShadow(color: t.colors['line-seam']!, spreadRadius: 1)),
        );
        expect(r.suggestionGroupInset, const EdgeInsets.fromLTRB(10, 8, 10, 4));
        final group = r.suggestionGroupLabel;
        expect(group.fontSize, 12);
        expect(group.fontWeight, FontWeight.w700);
        expect(group.color, t.colors['foreground-hint']);
        final title = r.suggestionTitle(highlighted: false);
        expect(title.fontSize, 14);
        expect(title.fontWeight, FontWeight.w500);
        expect(title.height! * 14, closeTo(t.desktop ? 22 : 20, .01));
        expect(title.color, t.ui.foreground);
        expect(r.suggestionMeta.fontSize, 12);
        expect(r.suggestionMeta.color, t.colors['foreground-hint']);
      });
    });
  }
}
