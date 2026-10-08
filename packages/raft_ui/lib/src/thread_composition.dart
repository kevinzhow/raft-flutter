import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'conversation_surface.dart';
import 'icons.dart';
import 'theme.dart';

/// Mounted Web ThreadPanel presentation, independent of the host OS.
/// A folded desktop side panel uses the same <1024 back affordance as Web.
enum RaftThreadPresentation { side, modal, mobileModal }

/// Source history predicate: older pages take precedence over a cutoff flag.
enum RaftThreadHistoryState { older, limited, beginning }

RaftThreadHistoryState raftThreadHistoryState({
  required bool hasMore,
  required bool historyLimited,
}) => hasMore
    ? RaftThreadHistoryState.older
    : historyLimited
    ? RaftThreadHistoryState.limited
    : RaftThreadHistoryState.beginning;

/// Product ThreadPanel uses AppPanelHeader's titleSlot, not the generic RUI
/// ThreadPanelTitle/OriginalMessage recipes. See the immutable source receipt.
@immutable
class RaftThreadCompositionRecipe {
  const RaftThreadCompositionRecipe(
    this.tokens, {
    required this.viewportWidth,
    required this.viewportHeight,
    required this.presentation,
  });
  final RaftTokens tokens;
  final double viewportWidth, viewportHeight;
  final RaftThreadPresentation presentation;
  double get backBreakpoint =>
      presentation == RaftThreadPresentation.side ? 1024 : 768;
  bool get showBack => viewportWidth < backBreakpoint;
  bool get showClose =>
      presentation == RaftThreadPresentation.modal ||
      presentation == RaftThreadPresentation.side && viewportWidth >= 1024;
  double get headerHeight =>
      RaftLayoutMetrics.shellHeaderHeight(tokens, viewportHeight);
  EdgeInsetsDirectional get headerInset => tokens.brutal
      ? const EdgeInsetsDirectional.symmetric(horizontal: 20)
      : EdgeInsetsDirectional.only(
          start: viewportWidth < 768 ? 20 : 36,
          end: viewportWidth < 768 ? 14 : 20,
        );
  double get headerGap => tokens.brutal ? 12 : 8;
  double get actionGap => tokens.brutal || viewportWidth >= 768 ? 6 : 2;
  Color get headerBackground => tokens.brutal
      ? Colors.white
      : viewportWidth < 768
      ? tokens.colors['layer-canvas-muted']!
      : Colors.transparent;
  BorderSide get headerBorder => tokens.brutal
      ? const BorderSide(color: Colors.black, width: 2)
      // Mounted ThreadPanelRoot gives its AppPanelHeader a bottom rule.
      : BorderSide(color: tokens.colors['line-muted']!);
  Color get parentBackground =>
      RaftConversationSurfaceRecipe(tokens)
          .background(RaftConversationSurfaceRole.threadParent);
  EdgeInsets get parentInset => const EdgeInsets.all(12);
  BorderSide get parentBorder => BorderSide(
    color: tokens.brutal ? Colors.black : tokens.colors['line-muted']!,
    width: tokens.brutal ? 2 : 1,
  );
  EdgeInsets get summaryInset =>
      const EdgeInsets.only(left: 12, right: 12, top: 8);
  TextStyle get title => RaftTypography.body(
    tokens,
    size: 16,
    line: 24,
    weight: FontWeight.w700,
    color: tokens.brutal ? Colors.black : tokens.strong,
  );
  TextStyle get titleSuffix => title.copyWith(
    fontWeight: FontWeight.w400,
    color: tokens.brutal ? Colors.black.withValues(alpha: .5) : tokens.muted,
  );
  TextStyle get history => RaftTypography.mono(
    tokens,
    color: tokens.brutal ? Colors.black.withValues(alpha: .5) : tokens.muted,
  );
  TextStyle get replyCount => RaftTypography.mono(tokens, color: tokens.muted);
  TextStyle get beginning => history.copyWith(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .4)
        : tokens.colors['foreground-placeholder']!,
  );
  BorderSide get summaryBorder =>
      BorderSide(color: tokens.colors['line-muted']!);
  BorderSide get limitedBorder => BorderSide(
    color: tokens.brutal
        ? Colors.black.withValues(alpha: .2)
        : tokens.colors['line-muted']!,
  );
  Color get limitedBackground =>
      tokens.brutal ? Colors.white.withValues(alpha: .7) : tokens.panel;
}

/// Controlled chrome only. Navigation, follower data, menus, permissions,
/// mobile history/back and any external header portal remain app-owned.
/// [parentLabel] is an already authorized display label, including # or @;
/// null omits the suffix while the identity is resolving.
class RaftThreadHeader extends StatelessWidget {
  const RaftThreadHeader({
    super.key,
    required this.presentation,
    required this.threadLabel,
    required this.jumpLabel,
    required this.backLabel,
    required this.closeLabel,
    this.parentLabel,
    this.onJumpToStart,
    this.onBack,
    this.onClose,
    this.followers,
    this.actions = const [],
    this.viewportWidth,
    this.viewportHeight,
    this.backKey,
    this.closeKey,
    this.jumpKey,
  });
  final RaftThreadPresentation presentation;
  final String threadLabel, jumpLabel, backLabel, closeLabel;
  final String? parentLabel;
  final VoidCallback? onJumpToStart, onBack, onClose;
  final Widget? followers;
  final List<Widget> actions;
  final double? viewportWidth, viewportHeight;
  final Key? backKey, closeKey, jumpKey;

  @override
  Widget build(BuildContext context) {
    final tokens = RaftTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final recipe = RaftThreadCompositionRecipe(
      tokens,
      viewportWidth: viewportWidth ?? viewport.width,
      viewportHeight: viewportHeight ?? viewport.height,
      presentation: presentation,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: recipe.headerBackground,
        border: Border(bottom: recipe.headerBorder),
      ),
      child: SizedBox(
        height: recipe.headerHeight,
        child: Padding(
          padding: recipe.headerInset,
          child: Row(
            children: [
              if (recipe.showBack && onBack != null) ...[
                RaftControl(
                  key: backKey,
                  recipe: _ThreadBackRecipe(tokens),
                  onPressed: onBack,
                  tooltip: backLabel,
                  semanticLabel: backLabel,
                  visualWidth: tokens.brutal ? 26 : 32,
                  visualHeight: tokens.brutal ? 28 : 32,
                  padding: EdgeInsets.zero,
                  child: RaftIcon(
                    RaftGlyph.arrowLeft,
                    size: tokens.brutal ? 14 : 16,
                  ),
                ),
                SizedBox(width: recipe.headerGap),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => RaftControl(
                    key: jumpKey,
                    recipe: _ThreadTitleRecipe(tokens),
                    onPressed: onJumpToStart,
                    tooltip: jumpLabel,
                    semanticLabel: jumpLabel,
                    visualHeight: 40,
                    visualWidth: constraints.maxWidth,
                    padding: EdgeInsets.zero,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExcludeSemantics(
                        child: Text.rich(
                          TextSpan(
                            text: threadLabel,
                            style: recipe.title,
                            children: [
                              if (parentLabel != null)
                                TextSpan(
                                  text: ' — $parentLabel',
                                  style: recipe.titleSuffix,
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (followers != null ||
                  actions.isNotEmpty ||
                  recipe.showClose && onClose != null)
                SizedBox(width: recipe.headerGap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (followers != null) followers!,
                  for (var index = 0; index < actions.length; index++) ...[
                    if (followers != null || index > 0)
                      SizedBox(width: recipe.actionGap),
                    actions[index],
                  ],
                  if (recipe.showClose && onClose != null) ...[
                    if (followers != null || actions.isNotEmpty)
                      SizedBox(width: recipe.actionGap),
                    RaftControl(
                      key: closeKey,
                      recipe: _ThreadCloseRecipe(tokens),
                      tooltip: closeLabel,
                      semanticLabel: closeLabel,
                      onPressed: onClose,
                      visualWidth: 28,
                      visualHeight: 28,
                      padding: EdgeInsets.zero,
                      child: const RaftIcon(RaftGlyph.x, size: 14),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slot action for an app-owned command menu, not a second follow state store.
/// EllipsisVertical is the exact installed Lucide 0.575.0 circle geometry.
class RaftThreadOverflowAction extends StatelessWidget {
  const RaftThreadOverflowAction({
    super.key,
    required this.label,
    this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RaftControl(
    tooltip: label,
    semanticLabel: label,
    variant: RaftControlVariant.outline,
    visualWidth: 28,
    visualHeight: 28,
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: 14,
        child: Builder(
          builder: (context) => CustomPaint(
            painter: _ThreadOverflowPainter(
              IconTheme.of(context).color ?? RaftTokens.of(context).muted,
            ),
          ),
        ),
      ),
    ),
  );
}

class _ThreadOverflowPainter extends CustomPainter {
  const _ThreadOverflowPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final y in [12.0, 5.0, 19.0]) {
      canvas.drawCircle(Offset(12, y), 1, pen);
    }
  }

  @override
  bool shouldRepaint(_ThreadOverflowPainter old) => old.color != color;
}

class _ThreadTitleRecipe extends RaftControlRecipe {
  const _ThreadTitleRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => Colors.transparent;
  @override
  Color get foreground => tokens.brutal ? Colors.black : tokens.strong;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  BorderRadius get radius => BorderRadius.zero;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  double get focusOutlineWidth => 2;
  @override
  double get focusOutlineOffset => 2;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
}

class _ThreadBackRecipe extends RaftControlRecipe {
  const _ThreadBackRecipe(super.tokens)
    : super(variant: RaftControlVariant.outline, visualHeight: 28);
  @override
  bool get transformsOnInteraction => tokens.brutal;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  Color get background => tokens.brutal ? Colors.white : Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => hovered && !tokens.brutal
      ? tokens.colors['fill-strong']!.withValues(
          alpha: tokens.colors['fill-strong']!.a * .8,
        )
      : background;
  @override
  Color get foreground =>
      tokens.brutal ? Colors.black : tokens.colors['foreground-icon']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      hovered && !tokens.brutal ? tokens.strong : foreground;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  BorderSide side({bool hovered = false}) => tokens.brutal
      ? const BorderSide(color: Colors.black, width: 2)
      : BorderSide.none;
  @override
  double get focusOutlineWidth => tokens.brutal ? 2 : 0;
  @override
  double get focusOutlineOffset => tokens.brutal ? 2 : 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => tokens.brutal
      ? [
          BoxShadow(
            color: Colors.black,
            offset: Offset(
              pressed
                  ? 1
                  : hovered
                  ? 4
                  : 2,
              pressed
                  ? 1
                  : hovered
                  ? 4
                  : 2,
            ),
          ),
        ]
      : focused
      ? [BoxShadow(color: tokens.colors['primary-500']!, spreadRadius: .5)]
      : const [];
}

class _ThreadCloseRecipe extends _ThreadBackRecipe {
  const _ThreadCloseRecipe(super.tokens);
  @override
  bool get transformsOnInteraction => true;
  @override
  BorderRadius get radius => RaftShapes.control(tokens, 28);
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered);
  @override
  Color get foreground => tokens.brutal ? Colors.black : tokens.muted;
  @override
  Color backgroundFor({bool hovered = false}) =>
      hovered && !tokens.brutal ? tokens.colors['fill-muted']! : background;
}

/// Parent + older-history hint + loaded reply count live in the SAME sliver
/// viewport as the replies. Do not put this beside the list in a Column or a
/// maxHeight180/nested-scroll parent. The caller retains authority and ledger
/// identity; pass parentKey to support actual parent reveal/anchor admission.
class RaftThreadTimelineTopSliver extends StatelessWidget {
  const RaftThreadTimelineTopSliver({
    super.key,
    required this.hasMore,
    required this.historyLimited,
    required this.loadingOlder,
    required this.loadingOlderLabel,
    required this.historyLimitedLabel,
    required this.beginningLabel,
    required this.replyCountLabel,
    this.parent,
    this.parentSlot,
    this.parentKey,
  });
  final bool hasMore, historyLimited, loadingOlder;
  final String loadingOlderLabel, historyLimitedLabel, beginningLabel;

  /// Source ThreadPanel uses loaded messages.length, not total folded count.
  final String replyCountLabel;
  final Widget? parent, parentSlot;
  final Key? parentKey;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftThreadCompositionRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
      viewportHeight: MediaQuery.sizeOf(context).height,
      presentation: RaftThreadPresentation.side,
    );
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parentSlot != null) parentSlot!,
          if (parent != null)
            Container(
              key: parentKey,
              padding: recipe.parentInset,
              decoration: BoxDecoration(
                color: recipe.parentBackground,
                border: Border(bottom: recipe.parentBorder),
              ),
              child: parent!,
            ),
          Padding(
            padding: recipe.summaryInset,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RaftThreadHistoryTopState(
                  hasMore: hasMore,
                  historyLimited: historyLimited,
                  loadingOlder: loadingOlder,
                  loadingOlderLabel: loadingOlderLabel,
                  historyLimitedLabel: historyLimitedLabel,
                  beginningLabel: beginningLabel,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: recipe.summaryBorder),
                    ),
                    child: Text(
                      replyCountLabel,
                      style: recipe.replyCount,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress/read-cutoff copy only: pagination belongs to the list sentinel.
/// Supply complete localized sentences; do not splice a translated noun.
class RaftThreadHistoryTopState extends StatelessWidget {
  const RaftThreadHistoryTopState({
    super.key,
    required this.hasMore,
    required this.historyLimited,
    required this.loadingOlder,
    required this.loadingOlderLabel,
    required this.historyLimitedLabel,
    required this.beginningLabel,
  });
  final bool hasMore, historyLimited, loadingOlder;
  final String loadingOlderLabel, historyLimitedLabel, beginningLabel;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftThreadCompositionRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
      viewportHeight: MediaQuery.sizeOf(context).height,
      presentation: RaftThreadPresentation.side,
    );
    final state = raftThreadHistoryState(
      hasMore: hasMore,
      historyLimited: historyLimited,
    );
    if (state == RaftThreadHistoryState.older && !loadingOlder) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: state == RaftThreadHistoryState.limited
          ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: recipe.limitedBackground,
                  border: Border.fromBorderSide(recipe.limitedBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RaftIcon(
                      RaftGlyph.lock,
                      size: 12,
                      color: recipe.history.color,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        historyLimitedLabel,
                        style: recipe.history,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Text(
              state == RaftThreadHistoryState.older
                  ? loadingOlderLabel
                  : beginningLabel,
              textAlign: TextAlign.center,
              style: state == RaftThreadHistoryState.older
                  ? recipe.history
                  : recipe.beginning,
            ),
    );
  }
}
