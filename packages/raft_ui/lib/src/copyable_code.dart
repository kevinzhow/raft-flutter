// raft-ui CopyableCode (`copyableCode` recipe): CopyableCodeRoot +
// CopyableCode + CopyableCodeAction, as composed by the Web Computer surfaces
// (MachineDetailPanel, ComputerCommandGuide): `<CopyableCode className="min-w-0
// flex-1 px-3 py-2 font-mono text-xs break-all">` beside a copy button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'dialog_card.dart';
import 'icons.dart';
import 'panel_layout.dart' show raftRecipeTheme;
import 'recipe_surface.dart' show raftCssText, RaftSlotPaint;
import 'recipes/button_variants.g.dart';
import 'recipes/copyable_code.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';

class RaftCopyableCode extends StatefulWidget {
  const RaftCopyableCode(
    this.command, {
    super.key,
    this.copyLabel = 'Copy command',
    this.codeKey,
    this.onCopied,
  });

  final String command;

  /// Tooltip / accessible name of the copy action.
  final String copyLabel;

  /// Key of the code box (Web `data-testid` on CopyableCode).
  final Key? codeKey;
  final VoidCallback? onCopied;

  @override
  State<RaftCopyableCode> createState() => _RaftCopyableCodeState();
}

class _RaftCopyableCodeState extends State<RaftCopyableCode> {
  bool copied = false;

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: widget.command));
    if (!mounted) return;
    setState(() => copied = true);
    widget.onCopied?.call();
    // CopyableCodeRoot useCopyToClipboard({timeout: 1400}).
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final s = RaftCopyableCodeRecipe.resolve(
      theme: raftRecipeTheme(t),
      size: RaftCopyableCodeRecipeSize.md,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    // Callsite `text-xs` (12/16) wins over the recipe's `leading-5` on the
    // brutal code box; elegant keeps `leading-5` on the inner span.
    final line = t.brutal ? 16.0 : 20.0;
    final text = raftCssText.merge(
      RaftTypography.mono(
        t,
        size: 12,
        line: line,
      ).merge(s.code.textStyle(rt).copyWith(fontSize: 12, height: line / 12)),
    );
    // Callsite `px-3 py-2` wins over the recipe padding (tailwind-merge);
    // elegant keeps its `py-0` code box and pads the dashed inner span.
    final elegant = !t.brutal;
    // Inner span: `border-x border-dashed border-ink-10 bg-layer-panel px-1
    // py-2 leading-5` (only the x borders exist; the generic decoration
    // would invent CSS-medium top/bottom borders).
    final inner = s.codeInner;
    final dash =
        inner.borderColorOf('left')?.resolve(rt) ?? t.colors['line-muted']!;
    Widget code = Container(
      key: widget.codeKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: s.code.withCssUsedBorderWidths().decoration(rt),
      child: elegant
          ? CustomPaint(
              foregroundPainter: _DashedSides(dash),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                color: inner.backgroundColor?.resolve(rt),
                child: Text(_breakAll(widget.command), style: text),
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: Text(_breakAll(widget.command), style: text),
            ),
    );
    final action = RaftRecipeButton(
      variant: elegant
          ? RaftButtonRecipeVariant.ghost
          : RaftButtonRecipeVariant.outline,
      size: elegant ? RaftButtonRecipeSize.iconXs : RaftButtonRecipeSize.iconSm,
      glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
      glyphSize: 12,
      tooltip: widget.copyLabel,
      foreground: elegant ? t.colors['foreground-muted'] : null,
      onPressed: copy,
    );
    return Row(
      children: [
        Expanded(child: code),
        SizedBox(width: s.root.columnGap ?? 8),
        action,
      ],
    );
  }
}

/// CSS `break-all`: a line may break between any two characters. The copy
/// action still copies [RaftCopyableCode.command] verbatim.
String _breakAll(String value) => value.characters.join('\u200B');

/// 1px dashed left/right borders (CSS `border-dashed`: 3px dashes for 1px).
class _DashedSides extends CustomPainter {
  const _DashedSides(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final x in [.5, size.width - .5]) {
      for (var y = 0.0; y < size.height; y += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 3).clamp(0, size.height)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSides old) => old.color != color;
}
