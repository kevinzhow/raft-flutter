import 'package:flutter/material.dart';

import 'css_pixel_snap.dart';
import 'form_controls.dart';
import 'icons.dart';
import 'raft/css_box.dart';

/// MessageSearchPage's search field: a [RaftInputGroup] with the search icon at its start and an inline-end clear
/// button and (on desktop) `Esc` hint. The consumer retains query composition, focus and routing.
class RaftSearchInput extends StatelessWidget {
  const RaftSearchInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.clearLabel,
    required this.onClear,
    this.onChanged,
    this.onSubmitted,
    this.showEscape = false,
    this.matchCssBorderScale = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint, clearLabel;
  final VoidCallback onClear;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool showEscape, matchCssBorderScale;

  @override
  Widget build(BuildContext context) => RaftCssPixelSnap(
    devicePixelRatio:
        matchCssBorderScale && RaftBorderSnap.emulatedDeviceScaleFactor
        ? 1
        : null,
    child: RaftInputGroup(
      snapBorderToDevicePixels: !matchCssBorderScale,
      useEmbeddedControlRecipe: true,
      leading: const RaftInputGroupAddon.icon(RaftGlyph.search),
      controller: controller,
      focusNode: focusNode,
      hintText: hint,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      clearLabel: clearLabel,
      onClear: onClear,
      kbd: showEscape ? 'Esc' : null,
    ),
  );
}
