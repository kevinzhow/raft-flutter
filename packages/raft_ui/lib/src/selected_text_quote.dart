import 'package:flutter/material.dart';

import 'design_primitives.dart' show RaftInteractive;
import 'icons.dart';
import 'localization.dart';
import 'theme.dart';

/// Web `selectedTextQuote.ts` (Selection-quote v0).

/// Wraps selected plain text as a Markdown blockquote: every line gets `> `,
/// a blank line a bare `>`, so the quote stays one block. CRLF and CR become
/// LF and trailing whitespace is dropped.
String raftFormatSelectedTextQuote(String text) => text
    .replaceAll(RegExp(r'\r\n?'), '\n')
    .replaceFirst(RegExp(r'\s+$'), '')
    .split('\n')
    .map((line) => line.trim().isNotEmpty ? '> $line' : '>')
    .join('\n');

/// Whether the selection holds anything worth quoting.
bool raftHasQuotableSelection(String text) => text.trim().isNotEmpty;

/// Appends [quote] to the composer's [existing] text: a blank line before it
/// (when there is text) and after it, so the writer continues below the quote.
String raftAppendQuoteToComposer(String existing, String quote) {
  final base = existing.replaceFirst(RegExp(r'\s*$'), '');
  return base.isEmpty ? '$quote\n\n' : '$base\n\n$quote\n\n';
}

/// Where a message body sends its "Quote" action: the composer of the surface
/// the message lives in (the channel's, or the thread panel's). Without one in
/// scope a selection offers no Quote.
class RaftSelectionShortcutScope extends InheritedWidget {
  const RaftSelectionShortcutScope({
    super.key,
    required this.onQuote,
    required super.child,
  });

  /// Receives the selected plain text.
  final ValueChanged<String> onQuote;

  static RaftSelectionShortcutScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RaftSelectionShortcutScope>();

  @override
  bool updateShouldNotify(RaftSelectionShortcutScope old) =>
      old.onQuote != onQuote;
}

/// Web `MessageSelectionShortcut`: the floating Quote / Copy pair beside a
/// selection inside one message body. A desktop pointer selection only; a
/// touch selection keeps the platform toolbar.
class RaftSelectionShortcut {
  RaftSelectionShortcut({required this.onQuote});
  final ValueChanged<String> onQuote;

  /// The selection the shortcut is for, set while it is shown.
  String text = '';
}

/// The pair itself (`rounded-container bg-layer-popover p-0.5 shadow-float
/// ring-1`, items `h-7 gap-1.5 px-2`, a separator between them), above the
/// selection when it fits, below it otherwise.
class RaftSelectionShortcutBar extends StatelessWidget {
  const RaftSelectionShortcutBar({
    super.key,
    required this.anchors,
    required this.onQuote,
    required this.onCopy,
  });
  final TextSelectionToolbarAnchors anchors;
  final VoidCallback onQuote, onCopy;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final below = anchors.secondaryAnchor ?? anchors.primaryAnchor;
    Widget item(String label, RaftGlyph glyph, VoidCallback onTap) =>
        RaftInteractive(
          onPressed: onTap,
          semanticLabel: label,
          builder: (_, state) => DecoratedBox(
            decoration: BoxDecoration(
              color: state.hovered || state.focusVisible
                  ? t.colors['primary-soft']
                  : null,
              borderRadius: BorderRadius.circular(t.brutal ? 0 : 6),
            ),
            child: SizedBox(
              height: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftIcon(glyph, size: 16, color: t.muted),
                    const SizedBox(width: 6),
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
        );
    return TapRegion(
      groupId: SelectableRegion,
      child: Semantics(
        label: raftText(context, 'Selected text actions'),
        container: true,
        child: CustomSingleChildLayout(
          delegate: _ShortcutLayout(
            above: anchors.primaryAnchor - const Offset(0, _gap),
            below: below + const Offset(0, _gap),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(
                color: t.strong,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.popover,
                  borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
                  border: Border.all(
                    color: t.colors['line-hairline'] ?? t.muted,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1f000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      item(
                        raftText(context, 'Quote'),
                        RaftGlyph.textQuote,
                        onQuote,
                      ),
                      SizedBox(
                        width: 1,
                        height: 20,
                        child: ColoredBox(
                          color: t.colors['line-hairline'] ?? t.muted,
                        ),
                      ),
                      item(raftText(context, 'Copy'), RaftGlyph.copy, onCopy),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutLayout extends SingleChildLayoutDelegate {
  const _ShortcutLayout({required this.above, required this.below});
  final Offset above, below;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  /// Web `placeMessageSelectionShortcut`: centred on the selection, above it
  /// when that fits, else below, kept 8px inside the window.
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final x = (above.dx - childSize.width / 2).clamp(
      8.0,
      (size.width - childSize.width - 8).clamp(8.0, double.infinity),
    );
    final aboveY = above.dy - childSize.height;
    final y = aboveY >= 8 ? aboveY : below.dy;
    return Offset(
      x,
      y.clamp(
        8.0,
        (size.height - childSize.height - 8).clamp(8.0, double.infinity),
      ),
    );
  }

  @override
  bool shouldRelayout(_ShortcutLayout old) =>
      old.above != above || old.below != below;
}

/// A selection settles this long before the pair appears (Web debounces 100 ms).
const raftSelectionShortcutDelay = Duration(milliseconds: 100);
