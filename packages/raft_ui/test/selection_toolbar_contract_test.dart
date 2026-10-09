import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

Finder button(String label) =>
    find.byWidgetPredicate((w) => w is RaftButton && w.tooltip == label);
void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark compact row, busy permissions and top/end menu',
      (t) async {
        t.view.physicalSize = const Size(1400, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final theme = raftTheme(family, dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        var width = 1200.0, busy = false, cancel = 0, copy = 0, preview = 0;
        late StateSetter update;
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(
                      width: width,
                      child: RaftDensityScope(
                        density: RaftDensity.touch,
                        child: RaftSelectionToolbar(
                          selected: 2,
                          total: 6,
                          busy: busy,
                          onExit: () => cancel++,
                          onSelectAll: () {},
                          onForward: () {},
                          onCopyLinks: () {},
                          onCopyMarkdown: () => copy++,
                          onPreview: () => preview++,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.widget<RaftButton>(button('Copy link')).label, 'Copy link');
        expect(t.getSize(button('More')).height, 28);
        final count = t.widget<Text>(find.text('2 selected'));
        expect(count.style!.fontSize, 12);
        expect(count.style!.height, 16 / 12);
        expect(count.style!.fontWeight, FontWeight.w700);
        final surface = t.widget<Material>(
          find
              .descendant(
                of: find.byType(RaftSelectionToolbar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(
          surface.color,
          tokens.colors[tokens.brutal ? 'color-soft-signal' : 'primary-soft'],
        );
        update(() => width = 320);
        await t.pumpAndSettle();
        if (family == RaftFamily.brutal) {
          expect(t.widget<RaftButton>(button('Copy link')).label, isEmpty);
        }
        expect(t.takeException(), isNull);
        final trigger = t.getRect(button('More'));
        await t.tap(button('More'));
        await t.pumpAndSettle();
        final panel = t.getRect(find.byType(RaftMenuPanel));
        expect(panel.right, closeTo(trigger.right, .01));
        expect(panel.bottom, closeTo(trigger.top - 8, .01));
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(
          t
              .widget<RaftMenuItem>(
                find.widgetWithText(RaftMenuItem, 'Generate image'),
              )
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(RaftMenuPanel), findsNothing);
        expect(
          t.widget<RaftButton>(button('More')).focusNode!.hasFocus,
          isTrue,
        );
        update(() => busy = true);
        await t.pumpAndSettle();
        expect(t.widget<RaftButton>(button('Select All')).onPressed, isNull);
        expect(t.widget<RaftButton>(button('Forward')).onPressed, isNull);
        expect(t.widget<RaftButton>(button('Copy link')).onPressed, isNotNull);
        await t.tap(button('More'));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byType(RaftSpinner), findsOneWidget);
        expect(
          t
              .widget<RaftMenuItem>(
                find.widgetWithText(RaftMenuItem, 'Rendering...'),
              )
              .onPressed,
          isNull,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await t.pump();
        expect(
          t
              .widget<RaftMenuItem>(
                find.widgetWithText(RaftMenuItem, 'Copy MD'),
              )
              .focusNode!
              .hasFocus,
          isTrue,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pumpAndSettle();
        expect(copy, 1);
        expect(preview, 0);
        await t.tap(button('Cancel'));
        expect(
          cancel,
          1,
          reason: 'Source Cancel remains enabled while capture is pending.',
        );
        update(() {
          width = 1200;
          busy = false;
        });
        await t.pumpAndSettle();
        expect(t.widget<RaftButton>(button('Copy link')).label, 'Copy link');
        expect(t.takeException(), isNull);
      },
    );
    testWidgets(
      '$family/$dark zero selected and disabled forward remain admitted correctly',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: RaftSelectionToolbar(
                selected: 0,
                total: 3,
                onExit: () {},
                onForward: () {},
                forwardDisabledReason: 'Unavailable target',
                onCopyLinks: () {},
              ),
            ),
          ),
        );
        expect(find.byTooltip('Select All'), findsNothing);
        expect(t.widget<RaftButton>(button('More')).onPressed, isNull);
        expect(t.widget<RaftButton>(button('Copy link')).onPressed, isNull);
        expect(
          t.widget<RaftButton>(button('Unavailable target')).onPressed,
          isNull,
        );
        expect(t.widget<RaftButton>(button('Cancel')).onPressed, isNotNull);
      },
    );
  }
  testWidgets(
    'copied link keeps Source aria-label and tooltip instead of transient visual text',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: RaftSelectionToolbar(
                selected: 1,
                total: 1,
                copied: true,
                onExit: () {},
                onCopyLinks: () {},
              ),
            ),
          ),
        );
        expect(t.widget<RaftButton>(button('Copy link')).label, 'Copied');
        final labeled = find.bySemanticsLabel('Copy link');
        expect(labeled, findsOneWidget);
        expect(t.getSemantics(labeled).label, 'Copy link');
        expect(
          t
              .getSemantics(labeled)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'production inherited face compacts Copy link into one authored row $family/$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final theme = raftTheme(family, dark: dark);
        final tokens = theme.extension<RaftTokens>()!;
        await t.runAsync(() async {
          for (final (name, file) in [
            (
              tokens.bodyFont,
              family == RaftFamily.brutal ? 'HankenGrotesk.ttf' : 'Geist.ttf',
            ),
            (tokens.monoFont, 'GeistMono.ttf'),
          ]) {
            ByteData data;
            try {
              data = await rootBundle.load(
                'packages/raft_ui/assets/fonts/$file',
              );
            } on FlutterError {
              data = await rootBundle.load('assets/fonts/$file');
            }
            await (FontLoader(name)..addFont(Future.value(data))).load();
          }
        });
        await t.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RaftSelectionToolbar(
                  selected: 2,
                  total: 2,
                  onExit: () {},
                  onForward: () {},
                  onCopyLinks: () {},
                  onPreview: () {},
                  onCopyMarkdown: () {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final top = t.getRect(button('Cancel')).top;
        for (final label in ['Forward', 'Copy link', 'More']) {
          expect(t.getRect(button(label)).top, closeTo(top, .01));
        }
        if (family == RaftFamily.brutal) {
          expect(t.widget<RaftButton>(button('Copy link')).label, isEmpty);
        }
        expect(
          t.getRect(find.byType(RaftSelectionToolbar)).height,
          family == RaftFamily.brutal ? 46 : 45,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
