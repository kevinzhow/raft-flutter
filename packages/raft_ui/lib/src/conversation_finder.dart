import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'text_selection_toolbar.dart';
import 'theme.dart';

/// Web SidebarConversationFinder chrome (the DS Search field `.rf-search` at
/// the sidebar's 36px row height): the "Find a conversation…" box above the
/// sidebar list. [RaftConversationFinderField] is the box, a
/// [RaftConversationFinderPanel] of [RaftConversationFinderRow]s the list that
/// floats under it. The host owns the query, the ranking and what a row opens.
abstract final class RaftConversationFinderMetrics {
  /// `px-2 pt-2.5 pb-2` around the field.
  static const fieldInset = EdgeInsets.fromLTRB(8, 10, 8, 8);

  /// `inset-x-2 top-full mt-1`: where the list sits under the box.
  static const panelOffset = Offset(8, 4);

  /// The channel glyph of a row (a bare # or a lock).
  static const glyphSize = 16.0;

  /// The list's horizontal inset on both sides (`inset-x-2`).
  static const panelInset = 16.0;

  /// `max-h-[min(60vh,22rem)]`.
  static double panelMaxHeight(double viewportHeight) =>
      math.min(viewportHeight * .6, 352);
}

/// The box: a 36px ink-bordered control on the card layer with the search
/// glyph, a bare text input and the focus ring.
class RaftConversationFinderField extends StatelessWidget {
  const RaftConversationFinderField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onKeyEvent,
    required this.onTapOutside,
    this.inputKey,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final VoidCallback onTapOutside;
  final Key? inputKey;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftTypography.body(
      t,
      size: 14,
      line: 20,
      color: t.colors['foreground'],
    );
    return Padding(
      padding: RaftConversationFinderMetrics.fieldInset,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) => Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: t.colors['layer-card'],
            borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
            border: Border.all(color: t.colors['line-strong']!, width: 1.5),
            boxShadow: focusNode.hasFocus
                ? [BoxShadow(color: t.colors['primary-soft']!, spreadRadius: 3)]
                : null,
          ),
          child: Row(
            spacing: 8,
            children: [
              ExcludeSemantics(
                child: RaftIcon(
                  RaftGlyph.search,
                  size: 16,
                  color: t.colors['foreground-hint'],
                ),
              ),
              Expanded(
                child: Semantics(
                  label: hint,
                  textField: true,
                  child: Focus(
                    onKeyEvent: onKeyEvent,
                    child: TextField(
                      key: inputKey,
                      controller: controller,
                      focusNode: focusNode,
                      style: style,
                      cursorColor: style.color,
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle: style.copyWith(
                          color: t.colors['foreground-hint'],
                        ),
                      ),
                      onTapOutside: (_) => onTapOutside(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating list: `rounded-container bg-layer-popover p-1.5 shadow-float
/// ring-1 ring-line-seam`, scrolling past its maximum height. [empty] is the
/// "No matches" line shown instead of rows.
class RaftConversationFinderPanel extends StatelessWidget {
  const RaftConversationFinderPanel({
    super.key,
    required this.children,
    this.emptyLabel,
  });
  final List<Widget> children;

  /// Set when there is no row.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: RaftConversationFinderMetrics.panelMaxHeight(
            MediaQuery.sizeOf(context).height,
          ),
        ),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: t.popover,
          borderRadius: BorderRadius.circular(t.brutal ? 0 : 12),
          border: Border.all(
            color: t.colors['line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: emptyLabel != null
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  emptyLabel!,
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    color: t.colors['foreground-hint'],
                  ),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: children,
              ),
      ),
    );
  }
}

/// One result: `min-h-9 rounded-control px-2.5 py-1.5`, the leading glyph or
/// avatar, the label (priority) and the quieter sublabel; the keyboard or
/// hover highlight is the soft primary fill.
class RaftConversationFinderRow extends StatelessWidget {
  const RaftConversationFinderRow({
    super.key,
    required this.leading,
    required this.label,
    required this.active,
    required this.onPressed,
    required this.onHover,
    this.sublabel,
  });
  final Widget leading;
  final String label;
  final String? sublabel;
  final bool active;
  final VoidCallback onPressed, onHover;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Semantics(
        button: true,
        selected: active,
        label: sublabel == null ? label : '$label, $sublabel',
        excludeSemantics: true,
        onTap: onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? t.colors['primary-soft'] : null,
              borderRadius: BorderRadius.circular(t.brutal ? 0 : 8),
            ),
            child: Row(
              spacing: 10,
              children: [
                leading,
                Expanded(
                  child: Row(
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RaftTypography.body(
                            t,
                            size: 14,
                            line: 20,
                            weight: FontWeight.w500,
                            color: t.colors['foreground'],
                          ),
                        ),
                      ),
                      if (sublabel != null)
                        Expanded(
                          child: Text(
                            sublabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RaftTypography.body(
                              t,
                              size: 12,
                              line: 16,
                              color: t.colors['foreground-hint'],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
