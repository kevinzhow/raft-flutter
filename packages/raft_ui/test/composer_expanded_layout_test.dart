import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

// The expanded editor's spacing spec: one inner padding (RaftSpace.x3) shared
// by the toolbar, the text, the preview and the action row, and one vertical
// beat (RaftSpace.x2) between rows. Checked on the desktop dialog and the phone
// sheet, in every theme.

const pad = RaftSpace.x3, gap = RaftSpace.x2;

Widget _app(bool dark) => MaterialApp(
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: Column(
      children: [
        const Spacer(),
        RaftComposer(
          initialDraft: 'one\ntwo\nthree\n**four**',
          onAttach: () {},
          onImagePick: () {},
          onSend: (_) async => true,
        ),
      ],
    ),
  ),
);

Rect _tool(WidgetTester t, String tooltip) => t.getRect(
  find.byWidgetPredicate(
    (w) => w is RaftComposerToolButton && w.tooltip == tooltip,
  ),
);

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    final theme = dark ? 'dark' : 'light';

    testWidgets('dialog: every row shares the card padding ($theme)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(dark));
      await tester.tap(find.byKey(const ValueKey('composer-expand')));
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const ValueKey('composer-expanded-card')),
      );
      final bold = _tool(tester, 'Bold');
      final eye = tester.getRect(
        find.byKey(const ValueKey('composer-preview-toggle')),
      );
      final text = tester.getRect(find.byType(EditableText));
      final preview = tester.getRect(
        find.byKey(const ValueKey('composer-preview')),
      );
      final attach = tester.getRect(
        find
            .byWidgetPredicate(
              (w) => w is RaftComposerAction && w.tooltip == 'Attach Media',
            )
            .last,
      );
      final send = tester.getRect(
        find.byKey(const ValueKey('composer-submit')).last,
      );
      final rule = tester.getRect(
        find.byKey(const ValueKey('composer-toolbar-rule')),
      );

      // Left edge: toolbar, text and action row line up on one padding.
      expect(bold.left, card.left + pad);
      expect(text.left, card.left + pad);
      expect(attach.left, card.left + pad);
      // Right edge: the toolbar's last button and Send match, and so does the
      // preview's text column.
      expect(eye.right, card.right - pad);
      expect(send.right, card.right - pad);
      expect(preview.right, card.right);
      final previewText = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('composer-preview')),
              matching: find.byType(RichText),
            )
            .first,
      );
      expect(previewText.left, preview.left + pad);
      // Equal insets on the toolbar's two sides.
      expect(bold.left - card.left, card.right - eye.right);
      // Around the divider between text and preview: pad, rule, then the
      // preview's own pad (its text column is checked above).
      expect(preview.left - text.right, pad + 1);
      // Vertical beat: card top, toolbar, rule, text, actions, card bottom.
      expect(bold.top, card.top + gap);
      expect(rule.top, bold.bottom + gap);
      expect(text.top - rule.bottom, inInclusiveRange(gap, gap + gap));
      expect(attach.bottom + gap, closeTo(card.bottom, 1));
      expect(card.bottom - send.bottom, closeTo(gap, 1));
    });

    testWidgets('sheet: every row shares the card padding ($theme)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(dark));
      await tester.tap(find.byKey(const ValueKey('composer-expand')));
      await tester.pumpAndSettle();
      final card = tester.getRect(
        find.byKey(const ValueKey('composer-expanded-card')),
      );
      final bold = _tool(tester, 'Bold');
      final text = tester.getRect(find.byType(EditableText));
      final attach = tester.getRect(
        find
            .byWidgetPredicate(
              (w) => w is RaftComposerAction && w.tooltip == 'Attach Media',
            )
            .last,
      );
      final send = tester.getRect(
        find.byKey(const ValueKey('composer-submit')).last,
      );
      final rule = tester.getRect(
        find.byKey(const ValueKey('composer-toolbar-rule')),
      );
      expect(bold.left, card.left + pad);
      expect(text.left, card.left + pad);
      expect(attach.left, card.left + pad);
      expect(send.right, card.right - pad);
      expect(text.right, card.right - pad);
      // Text on top, toolbar below its rule, actions under the toolbar.
      expect(text.top - card.top, inInclusiveRange(gap, gap + gap));
      expect(bold.top, rule.bottom + gap);
      expect(attach.top, closeTo(bold.bottom + gap, 2));
      expect(card.bottom - send.bottom, closeTo(gap, 1));
    });
  }
}
