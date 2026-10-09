import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'recipe_surface.dart';
import 'recipes/input_group.g.dart';
import 'recipes/kbd.g.dart';
import 'theme.dart';

/// MessageSearchPage's InputGroup with an inline-end clear button and desktop
/// Esc hint. The consumer retains query composition, focus and routing.
class RaftSearchInput extends StatefulWidget {
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
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint, clearLabel;
  final VoidCallback onClear;
  final ValueChanged<String>? onChanged, onSubmitted;
  final bool showEscape;
  @override
  State<RaftSearchInput> createState() => _RaftSearchInputState();
}

class _RaftSearchInputState extends State<RaftSearchInput> {
  bool hovered = false;
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(changed);
    widget.controller.addListener(changed);
  }

  @override
  void didUpdateWidget(covariant RaftSearchInput old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(changed);
      widget.focusNode.addListener(changed);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(changed);
      widget.controller.addListener(changed);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(changed);
    widget.controller.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), rt = t.recipeTokens;
    final focused = widget.focusNode.hasFocus;
    final g = RaftInputGroupRecipe.resolve(
      theme: t.recipeTheme,
      align: RaftInputGroupRecipeAlign.inlineEnd,
      tokens: rt,
      states: t.recipeStates(
        hovered: hovered,
        extra: [
          if (focused) ...[
            'has:data-slot=input-group-control+focus',
            'has:data-slot=input-group-control+focus-visible',
            'group/input-group:has:data-slot=input-group-control+focus',
          ],
        ],
      ),
    );
    final style = g.control.text(rt, base: DefaultTextStyle.of(context).style);
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: RaftRecipeBox(
        style: g.root,
        tokens: rt,
        width: double.infinity,
        clip: !t.brutal,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: g.control.padding,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: style,
                  strutStyle: StrutStyle.fromTextStyle(
                    style,
                    forceStrutHeight: true,
                  ),
                  cursorColor: style.color,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: style.copyWith(
                      color:
                          g.control
                              .target('::placeholder')
                              ?.color
                              ?.resolve(rt) ??
                          t.semantic.foregroundPlaceholder,
                    ),
                  ),
                ),
              ),
            ),
            RaftRecipeBox(
              style: g.addon,
              tokens: rt,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: g.addon.columnGap ?? 8,
                children: [
                  if (widget.controller.text.isNotEmpty)
                    RaftIconButton(
                      glyph: RaftGlyph.x,
                      glyphSize: 12,
                      visualSize: 24,
                      minimumTargetSize: 24,
                      tooltip: widget.clearLabel,
                      variant: RaftControlVariant.ghost,
                      onPressed: widget.onClear,
                    ),
                  if (widget.showEscape)
                    RaftRecipeBox(
                      style: RaftKbdRecipe.resolve(
                        theme: t.recipeTheme,
                        tokens: rt,
                      ).root,
                      tokens: rt,
                      child: Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: t.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
