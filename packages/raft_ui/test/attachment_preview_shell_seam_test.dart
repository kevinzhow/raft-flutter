import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Web `FileViewerShell`: the body follows the toolbar in flow, so the
// toolbar's 1px `border-line-seam` is the only thing between them. The shell
// used to place the body at a fixed 56px while the Raft toolbar is 44px with
// a mouse from 768dp, which let a 12px strip of `layer-backdrop` show through
// under the header (Markdown / text / csv previews on desktop).
void main() {
  const body = ValueKey('seam-body');
  for (final dark in [false, true]) {
    for (final (platform, size, scale) in [
      (TargetPlatform.linux, const Size(1440, 900), 1.0),
      (TargetPlatform.linux, const Size(1024, 768), 1.0),
      (TargetPlatform.macOS, const Size(1440, 900), 1.0),
      (TargetPlatform.linux, const Size(1440, 900), 2.0),
      (TargetPlatform.android, const Size(856, 944), 1.0),
      (TargetPlatform.android, const Size(390, 844), 1.0),
    ]) {
      testWidgets('canvas body meets the header ${platform.name} '
          '${size.width.toInt()}x${size.height.toInt()} ${scale}x '
          'dark=$dark', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(
              pack: packForThemeId(raftThemePackId),
              dark: dark,
            ).copyWith(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RaftAttachmentPreviewShell(
              filename: 'notes.md',
              canvas: true,
              copyText: '# Notes',
              onDownload: () {},
              onClose: () {},
              child: const SizedBox.expand(key: body),
            ),
          ),
        );
        await tester.pump();
        final context = tester.element(find.byKey(body));
        final t = RaftTokens.of(context);
        final header = tester.getRect(find.byType(RaftLightboxHeader));
        final pane = find.ancestor(
          of: find.byKey(body),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == t.colors['layer-canvas-muted'],
          ),
        );
        expect(pane, findsOneWidget);
        final paneRect = tester.getRect(pane);
        // No gap (backdrop band) and no overlap: the canvas starts exactly
        // at the header's bottom edge and runs to the bottom.
        expect(paneRect.top, header.bottom);
        expect(paneRect.bottom, size.height);
        expect(paneRect.width, size.width);
        if (t.desktop && scale == 1) expect(header.height, 44);
        // The boundary is the toolbar's own 1px `border-line-seam`.
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byType(RaftLightboxHeader),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        final rule = (decoration.border! as Border).bottom;
        expect(rule.color, t.colors['line-seam']);
        expect(rule.width, 1);
        expect(decoration.color, t.canvas);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
