import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

Future<void> _pump(
  WidgetTester t, {
  required bool dark,
  String name = 'Dev Workspace',
  bool attention = false,
  bool live = false,
  FocusNode? focus,
  VoidCallback? onPressed,
  double width = 390,
}) async {
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RaftMobileRootHeader(
            workspace: true,
            leading: RaftMobileServerSelector(
              key: const Key('mobile-server-selector'),
              label: name,
              attention: attention,
              attentionLabel: 'Other servers have unread messages',
              publicPageLive: live,
              focusNode: focus,
              onPressed: onPressed,
            ),
            actions: const [SizedBox(width: 44, height: 44)],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('$mode band: frame fill, seam, avatar on the 20px edge', (
      t,
    ) async {
      await _pump(t, dark: dark);
      final tokens = RaftTokens.of(t.element(find.byType(RaftWorkspaceButton)));
      final band = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      );
      final decoration = t.widget<Container>(band.first).decoration!
          as BoxDecoration;
      expect(decoration.color, tokens.colors['layer-section-header-mobile']);
      expect(decoration.color, tokens.colors['layer-frame']);
      expect(t.getRect(band.first).height, 56);
      expect(
        (decoration.border! as Border).bottom.color,
        tokens.colors['line-workspace-rail'],
      );
      final avatar = find.descendant(
        of: find.byType(RaftWorkspaceButton),
        matching: find.byType(RaftAvatar),
      );
      expect(avatar, findsOneWidget);
      final rect = t.getRect(avatar);
      expect(rect.left, 20, reason: 'button -ml-[11px] puts the avatar on 20');
      expect(rect.size, const Size.square(27), reason: 'compact-row avatar');
    });

    testWidgets('$mode name truncates at 200, chevron and globe follow', (
      t,
    ) async {
      await _pump(t, dark: dark, name: 'W' * 80, live: true);
      final name = find.descendant(
        of: find.byType(RaftWorkspaceButton),
        matching: find.textContaining('WWW'),
      );
      expect(t.getSize(name).width, lessThanOrEqualTo(200));
      expect(t.getSize(name).width, greaterThan(190));
      final text = t.widget<Text>(name);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      final globe = t.getRect(find.byType(RaftPublicPageGlobe));
      final chevron = t.getRect(
        find.descendant(
          of: find.byType(RaftWorkspaceButton),
          matching: find.byWidgetPredicate(
            (w) => w is RaftIcon && w.glyph == RaftGlyph.chevronDown,
          ),
        ),
      );
      expect(globe.size, const Size.square(14));
      expect(chevron.size, const Size.square(16));
      expect(chevron.left - globe.right, 4, reason: 'gap-2 and -ml-1');
      expect(t.getRect(name).left - 20 - 27, 8, reason: 'gap-2');
    });

    testWidgets('$mode attention pixel rides the avatar and is labelled', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await _pump(t, dark: dark, attention: true);
      expect(
        find.bySemanticsLabel(
          'Dev Workspace, Other servers have unread messages',
        ),
        findsOneWidget,
      );
      final dot = t.getRect(find.byType(RaftAttentionDot));
      final avatar = t.getRect(
        find.descendant(
          of: find.byType(RaftWorkspaceButton),
          matching: find.byType(RaftAvatar),
        ),
      );
      expect(dot.center.dx, greaterThan(avatar.center.dx));
      expect(dot.center.dy, greaterThan(avatar.center.dy));
      await _pump(t, dark: dark);
      expect(find.byType(RaftAttentionDot), findsNothing);
      expect(find.bySemanticsLabel('Dev Workspace'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('$mode focus, keyboard activation and semantics', (t) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var pressed = 0;
      final handle = t.ensureSemantics();
      await _pump(
        t,
        dark: dark,
        focus: focus,
        onPressed: () => pressed++,
      );
      focus.requestFocus();
      await t.pump();
      expect(focus.hasFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(pressed, 1);
      expect(
        t.getSemantics(find.bySemanticsLabel('Dev Workspace')),
        isSemantics(label: 'Dev Workspace', isButton: true, isFocusable: true),
      );
      await t.tap(find.byKey(const Key('mobile-server-selector')));
      expect(pressed, 2);
      handle.dispose();
    });
  }
}
