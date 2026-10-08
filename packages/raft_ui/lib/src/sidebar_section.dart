import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
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

  /// Native targets own real non-overlapping slots. Desktop uses source24.
  double get targetSize => density == RaftDensity.touch
      ? RaftMetrics.touchTarget
      : RaftSidebarSectionMetrics.headerHeight;
  EdgeInsets get inset => const EdgeInsets.fromLTRB(8, 12, 8, 4);
  Color get foreground => tokens.brutal ? Colors.black : tokens.strong;
  Color get hoverForeground =>
      tokens.brutal ? Colors.black.withValues(alpha: .7) : tokens.muted;
  TextStyle get title => TextStyle(
    fontFamily: tokens.bodyFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );
  TextStyle get count => RaftTypography.mono(
    tokens,
    size: 12,
    line: 16,
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .4)
        : tokens.colors['foreground-placeholder'],
  ).copyWith(fontWeight: FontWeight.w700);
}

@immutable
class RaftSidebarSectionAction {
  const RaftSidebarSectionAction({
    required this.label,
    required this.glyph,
    this.onPressed,
    this.key,
  });
  final String label;
  final RaftGlyph glyph;
  final VoidCallback? onPressed;
  final Key? key;
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
  });
  final String label;
  final bool expanded;
  final ValueChanged<bool>? onExpandedChanged;
  final int? count;
  final Key? disclosureKey;
  final String? emoji;
  final Widget? attention;
  final List<RaftSidebarSectionAction> actions;
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
            child: const RaftIcon(RaftGlyph.chevronRight, size: 12),
          ),
          const SizedBox(width: 4),
        ],
        if (emoji != null && emoji!.isNotEmpty) ...[
          Text(emoji!),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: recipe.title,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 4),
          Text('$count', style: recipe.count),
        ],
        if (!expanded && attention != null) ...[
          const SizedBox(width: 4),
          attention!,
        ],
      ],
    );
    return Padding(
      padding: recipe.inset,
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
                      visualHeight: RaftSidebarSectionMetrics.headerHeight,
                      minimumTargetSize: recipe.targetSize,
                      recipe: _DisclosureRecipe(t),
                      onPressed: () => onExpandedChanged!(!expanded),
                      child: ExcludeSemantics(child: content),
                    ),
                  ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: 4),
            _SectionAction(action: action, targetSize: recipe.targetSize),
          ],
        ],
      ),
    );
  }
}

class _DisclosureRecipe extends RaftControlRecipe {
  const _DisclosureRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get foreground => tokens.brutal ? Colors.black : tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) => hovered
      ? tokens.brutal
            ? Colors.black.withValues(alpha: .7)
            : tokens.muted
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
  }) => focused
      ? [
          BoxShadow(
            color: tokens.brutal ? Colors.black : tokens.line,
            spreadRadius: 2,
          ),
        ]
      : const [];
}

/// Product btn-flat-sm: no border, shadow or transform; visible keyboard focus.
class _SectionActionRecipe extends _DisclosureRecipe {
  const _SectionActionRecipe(super.tokens, {this.keyboardFocused = false});
  final bool keyboardFocused;
  @override
  Color get foreground => keyboardFocused ? tokens.strong : tokens.muted;
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
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (value) => setState(() => hasFocus = value),
    child: RaftControl(
      key: widget.action.key,
      semanticLabel: widget.action.label,
      tooltip: widget.action.label,
      onPressed: widget.action.onPressed,
      visualHeight: 24,
      visualWidth: 24,
      minimumTargetSize: widget.targetSize,
      recipe: _SectionActionRecipe(
        RaftTokens.of(context),
        keyboardFocused:
            hasFocus &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional,
      ),
      child: RaftIcon(widget.action.glyph, size: 14),
    ),
  );
}
