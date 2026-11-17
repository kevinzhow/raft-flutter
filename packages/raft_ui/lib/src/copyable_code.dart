// raft-ui CopyableCode (`copyableCode` recipe): CopyableCodeRoot +
// CopyableCode + CopyableCodeAction, as composed by the Web Computer surfaces
// (MachineDetailPanel, ComputerCommandGuide): `<CopyableCode className="min-w-0
// flex-1 px-3 py-2 font-mono text-xs break-all">` beside a copy button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart' hide RaftPanelHeaderRecipe;
import 'icons.dart';
import 'recipe_surface.dart' show RaftRecipeBox, RaftSlotPaint;
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'recipes/copyable_code.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;

class RaftCopyableCode extends StatefulWidget {
  const RaftCopyableCode(
    this.command, {
    super.key,
    this.copyLabel = 'Copy Command',
    this.codeKey,
    this.onCopied,
    this.large = false,
  });

  final String command;

  /// Tooltip / accessible name of the copy action.
  final String copyLabel;

  /// Key of the code box (Web `data-testid` on CopyableCode).
  final Key? codeKey;
  final VoidCallback? onCopied;

  /// The callsite `text-title tracking-widest` on the code (a short code a
  /// person reads and types): title size, bold, spaced out.
  final bool large;

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

  /// raft-ui 0.7 `CopyableCode`: the recipe's code box (13/20 Space Mono, 9 x 12
  /// padding, 40px high, `layer-code` with a hairline and radius 8) and a ghost
  /// `icon-md` action holding the 16px copy mark (the recipe's `iconSwap`) that becomes a check.
  Widget _raft(
    RaftTokens t,
    RaftTokenResolver rt,
    RaftCopyableCodeRecipeStyle s,
    TextStyle? codeStyle,
  ) {
    return Row(
      children: [
        Expanded(
          child: RaftRecipeBox(
            key: widget.codeKey,
            style: s.code.withCssUsedBorderWidths(),
            tokens: rt,
            width: double.infinity,
            child: Text(_breakAll(widget.command), style: codeStyle),
          ),
        ),
        SizedBox(width: s.root.columnGap ?? 8),
        RaftButton(
          label: '',
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconMd,
          glyph: copied ? RaftGlyph.check : RaftGlyph.copy,
          glyphSize: 16,
          tooltip: widget.copyLabel,
          onPressed: copy,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = RaftRecipeTokens(t);
    final codeStyle = widget.large
        ? RaftTypography.mono(
            t,
            size: RaftTypeScale.title.fontSize,
            line: RaftTypeScale.title.lineHeight,
          ).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: RaftTypeScale.title.fontSize * .1,
          )
        : null;
    final s = RaftCopyableCodeRecipe.resolve(
      size: RaftCopyableCodeRecipeSize.md,
      states: RaftRecipeStates({if (t.dark) RaftRecipeStates.dark}),
      tokens: rt,
    );
    return _raft(t, rt, s, codeStyle);
  }
}

/// CSS `break-all`: a line may break between any two characters. The copy
/// action still copies [RaftCopyableCode.command] verbatim.
String _breakAll(String value) => value.characters.join('\u200B');
