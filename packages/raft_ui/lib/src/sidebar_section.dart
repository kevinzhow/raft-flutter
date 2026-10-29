import 'sidebar_text.dart';

import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'chat_composition.dart'
    show RaftChatSidebarGroupKind, RaftChatSidebarGroupRecipe;
import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'theme.dart';

/// Mounted Sidebar.tsx335/342 geometry, distinct from generic RUI sections.
abstract final class RaftSidebarSectionMetrics {
  static const headerHeight = 24.0, actionSize = 24.0;
  static const marginTop = 12.0, marginBottom = 4.0, horizontalInset = 8.0;
  static const inlineGap = 4.0, disclosureGlyph = 12.0, actionGlyph = 14.0;
  // Tailwind theme.css492–493 defaults used by transition-transform.
  static const disclosureDuration = Duration(milliseconds: 150);
  static const disclosureCurve = Cubic(.4, 0, .2, 1);
}

@immutable
class RaftSidebarSectionRecipe {
  const RaftSidebarSectionRecipe(this.tokens, this.density);
  final RaftTokens tokens;
  final RaftDensity density;

  /// The title line and action face are distinct boxes in Sidebar.tsx.
  /// The host preserves their CSS centers without shrinking the action hit box.
  /// The last conversation keeps the section's trailing CSS margin.
  static EdgeInsets listEndInset(RaftTokens tokens) =>
      EdgeInsets.only(bottom: tokens.size('space.sidebarListEnd', fallback: 0));

  double get targetSize => tokens.size('size.sidebarSectionLine', fallback: 24);
  EdgeInsets get inset => EdgeInsets.fromLTRB(
    8,
    tokens.size('space.sidebarSectionTop', fallback: 12),
    8,
    tokens.size('space.sidebarSectionBottom', fallback: 4),
  );
  Color get foreground =>
      tokens.colors['foreground-sidebar-section'] ?? tokens.strong;
  Color get hoverForeground => tokens.muted;
  // The row inherits the host's heading face (Inter in Elegant, Hanken in
  // Brutal): `button { font: inherit }` under `main.font-display`.
  TextStyle get title =>
      RaftTypography.heading(
        tokens,
        size: tokens.size('type.sidebarSection.size', fallback: 12),
        line: tokens.size('type.sidebarSection.line', fallback: 16),
        weight: raftFontWeight(
          tokens.size('type.sidebarSection.weight', fallback: 400),
        ),
        color: foreground,
      ).copyWith(
        letterSpacing: tokens.size('type.sidebarSection.tracking', fallback: 0),
      );
  TextStyle get count =>
      RaftTypography.mono(
        tokens,
        size: 12,
        line: 16,
        color:
            tokens.colors['foreground-sidebar-section-count'] ??
            tokens.colors['foreground-placeholder'],
      ).copyWith(
        fontWeight: raftFontWeight(
          tokens.size('type.sidebarSectionCount.weight', fallback: 700),
        ),
      );
}

@immutable
class RaftSidebarSectionAction {
  const RaftSidebarSectionAction({
    required this.label,
    required this.glyph,
    this.onPressed,
    this.key,
    this.testKey,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onPressed;
  final Key? key;

  /// Stable lookup key (the anchor [key] may be a GlobalKey).
  final Key? testKey;
}

/// Controlled presentation. The caller owns count projection, collapse scope,
/// sort persistence, permissions and dialog authority. Labels are already localized.
class RaftSidebarSectionHeader extends StatelessWidget {
  const RaftSidebarSectionHeader({
    super.key,
    required this.label,
    required this.expanded,
    required this.onExpandedChanged,
    this.count,
    this.disclosureKey,
    this.emoji,
    this.attention,
    this.actions = const [],
    this.trailing,
    this.onContextMenu,
    this.contextMenuOnLongPress = true,
    this.topInset,
  });

  /// Sidebar.tsx `SidebarSectionHeader onContextMenu`: right click / long press
  /// anywhere on the header row, at the global pointer position.
  final ValueChanged<Offset>? onContextMenu;

  /// False when a long press belongs to the host instead (a draggable header
  /// lifts on long press); right click still opens [onContextMenu].
  final bool contextMenuOnLongPress;
  final String label;

  /// Overrides the `mt-3` top inset when the row's margin collapses with the
  /// previous sibling's bottom margin (the sibling's box already holds it).
  final double? topInset;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final int? count;
  final Key? disclosureKey;
  final String? emoji;
  final Widget? attention;
  final List<RaftSidebarSectionAction> actions;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftSidebarSectionRecipe(t, RaftDensityScope.of(context));
    final content = Row(
      children: [
        if (onExpandedChanged != null) ...[
          AnimatedRotation(
            turns: expanded ? .25 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : RaftSidebarSectionMetrics.disclosureDuration,
            curve: RaftSidebarSectionMetrics.disclosureCurve,
            child: RaftIcon(
              RaftGlyph.chevronRight,
              size: t.size('size.sidebarSectionGlyph', fallback: 12),
            ),
          ),
          SizedBox(width: t.size('space.sidebarSectionGap', fallback: 4)),
        ],
        if (emoji != null && emoji!.isNotEmpty) ...[
          RaftSidebarText(
            emoji!,
            style: TextStyle(fontFamilyFallback: t.fontFallback),
          ),
          SizedBox(width: t.size('space.sidebarSectionGap', fallback: 4)),
        ],
        Flexible(
          child: RaftSidebarText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: recipe.title,
          ),
        ),
        if (count != null) ...[
          SizedBox(width: t.size('space.sidebarSectionCountGap', fallback: 4)),
          RaftSidebarText('$count', style: recipe.count),
        ],
        if (!expanded && attention != null) ...[
          const SizedBox(width: 4),
          attention!,
        ],
      ],
    );
    // CSS gives the larger action faces negative vertical margins. Allocate
    // their full hit boxes inside the header instead: reduce the surrounding
    // padding by the same amount, keeping both centers and the total height.
    final actionSize = t.size('size.sidebarSectionAction', fallback: 24);
    final overhang = actions.isEmpty
        ? 0.0
        : ((actionSize - recipe.targetSize) / 2).clamp(0.0, double.infinity);
    final inset = recipe.inset;
    final header = Padding(
      padding: inset.copyWith(
        top: ((topInset ?? inset.top) - overhang).clamp(0.0, double.infinity),
        bottom: (inset.bottom - overhang).clamp(0.0, double.infinity),
      ),
      child: Row(
        children: [
          Expanded(
            child: onExpandedChanged == null
                ? Semantics(
                    header: true,
                    child: SizedBox(
                      height: recipe.targetSize,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DefaultTextStyle(
                          style: recipe.title.copyWith(
                            color: recipe.foreground,
                          ),
                          child: content,
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    expanded: expanded,
                    child: RaftControl(
                      key: disclosureKey,
                      semanticLabel: count == null ? label : '$label, $count',
                      visualHeight: recipe.targetSize,
                      minimumTargetSize: recipe.targetSize,
                      recipe: _DisclosureRecipe(t),
                      onPressed: () => onExpandedChanged!(!expanded),
                      child: ExcludeSemantics(child: content),
                    ),
                  ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(
              width: i == 0
                  ? t.size('space.sidebarSectionActions', fallback: 4)
                  : 4,
            ),
            _SectionAction(action: actions[i], targetSize: recipe.targetSize),
          ],
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
    if (onContextMenu == null) return header;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Sidebar.tsx SidebarSectionHeader `onContextMenu`: right click, and on
      // touch the browser's long-press `contextmenu`.
      onSecondaryTapDown: (d) => onContextMenu!(d.globalPosition),
      onLongPressStart: contextMenuOnLongPress
          ? (d) => onContextMenu!(d.globalPosition)
          : null,
      child: header,
    );
  }
}

class _DisclosureRecipe extends RaftControlRecipe {
  const _DisclosureRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get foreground =>
      tokens.colors['foreground-sidebar-section'] ?? tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) => hovered
      ? tokens.colors['foreground-sidebar-section-hover'] ?? tokens.muted
      : foreground;
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => Colors.transparent;
  @override
  EdgeInsets get padding => EdgeInsets.zero;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.zero;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => focused ? [BoxShadow(color: tokens.line, spreadRadius: 2)] : const [];
}

/// Product btn-flat-sm: no border, shadow or transform; visible keyboard focus.
class RaftSidebarSectionActionRecipe extends _DisclosureRecipe {
  const RaftSidebarSectionActionRecipe(
    super.tokens, {
    this.keyboardFocused = false,
  });
  final bool keyboardFocused;
  @override
  Color get foreground => keyboardFocused
      ? tokens.strong
      : tokens.colors['foreground-sidebar-section-control'] ?? tokens.muted;
  @override
  Color foregroundFor({bool hovered = false}) =>
      hovered ? tokens.strong : foreground;
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => pressed
      ? tokens.colors['fill-strong']!
      : hovered || keyboardFocused
      ? tokens.colors['fill-muted']!
      : Colors.transparent;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}

class _SectionAction extends StatefulWidget {
  const _SectionAction({required this.action, required this.targetSize});
  final RaftSidebarSectionAction action;
  final double targetSize;
  @override
  State<_SectionAction> createState() => _SectionActionState();
}

class _SectionActionState extends State<_SectionAction> {
  bool hasFocus = false;
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: widget.action.testKey,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) => setState(() => hasFocus = value),
      child: RaftControl(
        key: widget.action.key,
        semanticLabel: widget.action.label,
        tooltip: widget.action.label,
        onPressed: widget.action.onPressed,
        visualHeight: RaftTokens.of(context)
            .size('size.sidebarSectionAction', fallback: 24),
        visualWidth: RaftTokens.of(context)
            .size('size.sidebarSectionAction', fallback: 24),
        minimumTargetSize: widget.targetSize,
        recipe: RaftSidebarSectionActionRecipe(
          RaftTokens.of(context),
          keyboardFocused:
              hasFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional,
        ),
        child: RaftIcon(
          widget.action.glyph,
          size: RaftTokens.of(context)
              .size('size.sidebarSectionActionGlyph', fallback: 14),
        ),
      ),
    ),
  );
}

/// SidebarSectionDescription under an empty custom section ("No
/// conversations"): mono `text-xs`, `px-2`, the `min-h-7` drop target.
class RaftSidebarSectionEmptyHint extends StatelessWidget {
  const RaftSidebarSectionEmptyHint(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftChatSidebarGroupRecipe(
      RaftTokens.of(context),
      RaftChatSidebarGroupKind.channels,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Padding(
        padding: recipe.descriptionInset,
        child: RaftCssText(label, style: recipe.description),
      ),
    );
  }
}
