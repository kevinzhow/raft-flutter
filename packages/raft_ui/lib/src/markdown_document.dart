import 'package:flutter/widgets.dart';

import 'announcement_markdown.dart';
import 'card.dart';
import 'design_primitives.dart' show RaftLayoutMetrics, RaftTypography;
import 'interaction.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

/// Native Markdown reader using the content worker's document artboard.
class RaftMarkdownDocument extends StatelessWidget {
  const RaftMarkdownDocument(this.text, {super.key, this.scrollKey});

  final String text;
  final Key? scrollKey;

  static const _paperMinWidth = 1024.0;
  static const _documentMaxWidth = 768.0;
  static const _canvasInset = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 32,
  );
  static const _paperInset = EdgeInsets.symmetric(horizontal: 32, vertical: 40);
  static const _pageInset = EdgeInsets.symmetric(horizontal: 40, vertical: 48);

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final paper = width >= _paperMinWidth;
        final desktop =
            width >= RaftLayoutMetrics.desktopBreakpoint &&
            RaftInteraction.of(context).pointer;
        final style = desktop ? RaftDesktopTypeScale.body : RaftTypeScale.body;
        final document = DefaultTextStyle.merge(
          style: RaftTypography.body(
            tokens,
            size: style.fontSize,
            line: style.lineHeight,
            color: tokens.colors['foreground'],
          ),
          child: RaftAnnouncementMarkdown.document(text),
        );
        return ColoredBox(
          color: tokens.colors[paper ? 'layer-sidebar' : 'layer-canvas']!,
          child: SingleChildScrollView(
            key: scrollKey,
            padding: paper ? _paperInset : _canvasInset,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _documentMaxWidth),
                child: SizedBox(
                  width: double.infinity,
                  child: paper
                      ? RaftCard.item(
                          interactive: false,
                          padding: _pageInset,
                          child: document,
                        )
                      : document,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
