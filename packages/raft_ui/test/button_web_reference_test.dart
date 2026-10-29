// Real Web 0.7.0 captures: social-login outline, dialog footer, bulk restart,
// and keyboard-focused composer Send. The legacy looks keep their own recipes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_paint.dart';
import 'control_transition_paint_test.dart' show paintHost, pixel;

Widget _app(bool dark, Widget child) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(body: Center(child: child)),
);
Finder _button(String label) =>
    find.byWidgetPredicate((w) => w is RaftButton && w.label == label);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets('Web social outline keeps its one-pixel edge ($dark)', (
      t,
    ) async {
      addTearDown(t.view.resetDevicePixelRatio);
      for (final (dpr, border) in [(1.0, 1.0), (2.0, 1.5), (3.0, 4 / 3)]) {
        t.view.devicePixelRatio = dpr;
        await t.pumpWidget(
          _app(
            dark,
            RaftAuthSocialButton(
              provider: 'github',
              label: 'Continue with GitHub',
              onPressed: () {},
            ),
          ),
        );
        final face = controlDecoration(t, find.byType(RaftAuthSocialButton));
        expect((face.border! as Border).top.width, border);
        expect(t.getSize(find.byType(RaftAuthSocialButton)).height, 44);
      }
    });
    testWidgets(
      'Web form footer has large ghost Cancel and accent submit ($dark)',
      (t) async {
        await t.pumpWidget(
          _app(
            dark,
            RaftFormDialog(
              title: 'Create Channel',
              fields: const [],
              onSubmit: (_) async {},
              submitLabel: 'Create Channel',
            ),
          ),
        );
        for (final label in ['Cancel', 'Create Channel']) {
          expect(t.getSize(_button(label)).height, 44);
        }
        final cancel = controlDecoration(t, _button('Cancel'));
        expect(cancel.color, Colors.transparent);
        expect((cancel.border! as Border).top.color, Colors.transparent);
      },
    );
    testWidgets('actual Create Channel footer follows Web ($dark)', (t) async {
      await t.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final name = TextEditingController(text: 'design');
      final description = TextEditingController();
      final search = TextEditingController();
      addTearDown(name.dispose);
      addTearDown(description.dispose);
      addTearDown(search.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      await t.pumpWidget(
        _app(
          dark,
          RaftCreateChannelDialogView(
            name: name,
            description: description,
            search: search,
            visibility: 'public',
            onVisibilityChanged: (_) {},
            agents: const [],
            humans: const [],
            hasCandidates: false,
            isSelected: (_) => false,
            onToggle: (_) {},
            onClose: () {},
            onSubmit: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(_button('Cancel')).height, 44);
      expect(t.getSize(_button('Create Channel')).height, 44);
      final cancel = controlDecoration(t, _button('Cancel'));
      expect(cancel.color, Colors.transparent);
      expect((cancel.border! as Border).top.color, Colors.transparent);
    });
    testWidgets('Web bulk actions preserve consequence colours ($dark)', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(900, 2200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        _app(
          dark,
          RaftComputerDetailView(
            data: const RaftComputerDetailData(
              id: 'c1',
              name: 'Studio',
              online: true,
              isComputer: true,
              slug: 'launch',
              runtimes: [],
              createdLabel: 'today',
              canManage: true,
              agents: [
                RaftComputerAgent(
                  id: 'a1',
                  name: 'Ada',
                  subtitle: '',
                  activity: 'offline',
                  activityText: '',
                ),
              ],
            ),
            actions: RaftComputerDetailActions(
              rename: (_) async {},
              describe: (_) async {},
              scanWorkspaces: () async => [],
              deleteWorkspace: (_) async {},
              restart: () async {},
              deleteComputer: () async {},
              bulk: (_, _) async => 0,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('computer-agents-select')));
      await t.pumpAndSettle();
      expect(controlDecoration(t, _button('Cancel')).color, Colors.transparent);
      await t.tap(find.text('Ada'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('computer-bulk-restart-reset')));
      await t.pumpAndSettle();
      Finder dialogButton(String label) => find.descendant(
        of: find.byKey(const ValueKey('computer-dialog')),
        matching: _button(label),
      );
      for (final label in ['Cancel', 'Restart']) {
        expect(t.getSize(dialogButton(label)).height, 44);
      }
      expect(
        controlDecoration(t, dialogButton('Cancel')).color,
        Colors.transparent,
      );
      expect(
        t.widget<RaftButton>(dialogButton('Restart')).resolvedVariant,
        RaftButtonVariant.warning,
      );
      for (final (label, variant) in [
        ('Reset Session & Restart', RaftButtonVariant.warning),
        ('Full Reset & Restart', RaftButtonVariant.danger),
      ]) {
        await t.tap(find.text(label).first);
        await t.pumpAndSettle();
        expect(
          t.widget<RaftButton>(dialogButton(label)).resolvedVariant,
          variant,
        );
      }
      await t.tap(dialogButton('Cancel'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('computer-dialog')), findsNothing);
    });
    testWidgets('Web button hover is composited once ($dark)', (t) async {
      final theme = raftTheme(dark: dark);
      await t.pumpWidget(
        paintHost(
          theme,
          RaftButton(
            uiVariant: RaftButtonVariant.outline,
            visualWidth: 96,
            onPressed: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      await mouse.moveTo(t.getCenter(find.byType(RaftButton)));
      await t.pumpAndSettle();
      final ui = RaftUiColors.of(dark);
      expect(
        await pixel(t, const Offset(24, 24)),
        Color(Color.alphaBlend(ui.fillPressed, ui.layerCard).toARGB32()),
      );
      await mouse.removePointer();
    });
    testWidgets('real keyboard focus paints composer Send ring ($dark)', (
      t,
    ) async {
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      });
      await t.pumpWidget(
        paintHost(
          raftTheme(dark: dark),
          RaftComposerAction(
            glyph: RaftGlyph.send,
            tooltip: 'Send',
            submit: true,
            onPressed: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final idle = await pixel(t, const Offset(9, 28));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pumpAndSettle();
      final detector = t.widget<FocusableActionDetector>(
        find
            .descendant(
              of: find.byType(RaftComposerAction),
              matching: find.byType(FocusableActionDetector),
            )
            .first,
      );
      expect(detector.focusNode!.hasFocus, isTrue);
      expect(await pixel(t, const Offset(9, 28)), isNot(idle));
      final ring = RaftUiColors.of(dark).focusRing.layers;
      expect(await pixel(t, const Offset(11, 28)), ring.first.color);
      expect(await pixel(t, const Offset(9, 28)), ring.last.color);
    });
  }
}
