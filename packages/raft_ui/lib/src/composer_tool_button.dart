import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'raft/button.dart';
import 'icons.dart';
import 'localization.dart';

/// A square icon button that leaves the editor focused on pointer press.
class RaftComposerToolButton extends StatelessWidget {
  const RaftComposerToolButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.on = false,
    this.framed = false,
    this.prominent = false,
    this.face = RaftMetrics.buttonSm,
  });
  final RaftGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool on, framed, prominent;
  final double face;

  @override
  Widget build(BuildContext context) {
    final label = raftText(context, tooltip);
    return RaftButton(
      glyph: glyph,
      uiVariant: on ? RaftButtonVariant.outline : RaftButtonVariant.ghost,
      uiSize: face <= 24
          ? RaftButtonSize.iconXs
          : face <= 32
          ? RaftButtonSize.iconMd
          : RaftButtonSize.iconLg,
      onPressed: onPressed,
      focusOnPointer: false,
      toggled: on,
      semanticLabel: label,
      tooltip: label,
    );
  }
}
