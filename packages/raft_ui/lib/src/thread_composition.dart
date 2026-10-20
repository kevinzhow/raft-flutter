import 'text_selection_toolbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'channel_header.dart' show RaftConversationHeader;
import 'design_primitives.dart';
import 'conversation_surface.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart';
import 'status_bar.dart';
import 'text_scaling.dart' show RaftScaled;
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

  /// `PanelHeader` (raft-ui 0.5.52): padding 20/20 (right 14 below 768 in
  /// elegant) and gap 12 (8 below 768 in elegant).
  EdgeInsetsDirectional get headerInset => tokens.brutal
      ? const EdgeInsetsDirectional.symmetric(horizontal: 20)
      : EdgeInsetsDirectional.only(
          start: 20,
          end: viewportWidth < 768 ? 14 : 20,
        );
  double get headerGap => tokens.brutal || viewportWidth >= 768 ? 12 : 8;
  double get actionGap => tokens.brutal || viewportWidth >= 768 ? 6 : 2;

  /// The thread column's header container adds
  /// `in-data-[theme=elegant]:bg-layer-canvas-muted` at every width (Web
  /// v1.21.12 `THREAD_HEADER_CONTAINER_CLASS_NAME`).
  Color get headerBackground =>
      tokens.brutal ? Colors.white : tokens.colors['layer-canvas-muted']!;
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
    this.followersVisible = true,
    this.actions = const [],
    this.viewportWidth,
    this.viewportHeight,
    this.backKey,
    this.closeKey,
    this.jumpKey,
    this.interactiveTitle = true,
  });
  final RaftThreadPresentation presentation;
  final String threadLabel, jumpLabel, backLabel, closeLabel;
  final String? parentLabel;
  final VoidCallback? onJumpToStart, onBack, onClose;
  final Widget? followers;

  /// False while the [followers] slot renders nothing (no followers yet): the
  /// slot stays mounted so it can load, but takes no header gap.
  final bool followersVisible;
  final List<Widget> actions;
  final double? viewportWidth, viewportHeight;
  final Key? backKey, closeKey, jumpKey;

  /// Source pending channel resolution has a plain PanelHeader title.
  final bool interactiveTitle;

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
    final grows = RaftScaled.grows(context);
    // `PanelTitle` (17/600 elegant, 16/700 brutal) and the parent label span:
    // `ml-1 font-normal in-data-[theme=elegant]:text-[15px]
    // text-foreground-placeholder theme-brutal:text-black/50`.
    final titleStyle = RaftConversationHeader.text(
      context,
      RaftConversationHeader.recipeOf(context).title,
    );
    final suffixStyle = titleStyle.copyWith(
      fontWeight: FontWeight.w400,
      fontSize: tokens.brutal ? null : 15,
      color: tokens.brutal
          ? Colors.black.withValues(alpha: .5)
          : tokens.colors['foreground-placeholder'],
    );
    Widget title() => Text.rich(
      TextSpan(
        text: threadLabel,
        style: titleStyle,
        children: [
          // Source `<span className="ml-1"> — {label}</span>` is a flex item
          // of the title button: the gap is a margin, not a collapsed space.
          if (parentLabel != null) ...[
            // A zero-height box: `middle` leaves the line box alone and, unlike
            // `baseline`, needs no dry baseline from the Semantics RichText
            // wraps around a placeholder.
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: SizedBox(width: 4),
            ),
            TextSpan(text: '— $parentLabel', style: suffixStyle),
          ],
        ],
      ),
      semanticsLabel: parentLabel == null
          ? threadLabel
          : '$threadLabel — $parentLabel',
      // Larger text wraps the title and grows the header.
      maxLines: grows ? null : 1,
      overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
    );
    final hasFollowers = followers != null && followersVisible;
    // CSS border-box: the bottom rule is inside the header height and the
    // row is centred in the remaining content box.
    return RaftStatusBarSource(
      color: recipe.headerBackground,
      child: Container(
        // The header height is a minimum once the text grows.
        height: grows ? null : recipe.headerHeight,
        constraints: grows
            ? BoxConstraints(minHeight: recipe.headerHeight)
            : null,
        decoration: BoxDecoration(
          color: recipe.headerBackground,
          border: Border(bottom: recipe.headerBorder),
        ),
        child: SizedBox(
          height: grows
              ? null
              : recipe.headerHeight - recipe.headerBorder.width,
          child: Padding(
            padding: grows
                ? recipe.headerInset.add(
                    const EdgeInsets.symmetric(vertical: 6),
                  )
                : recipe.headerInset,
            child: Row(
              children: [
                if (recipe.showBack && onBack != null) ...[
                  // AppPanelHeader's mobile Back is the raft-ui PanelAction (the
                  // same control as the channel header): source-sized layout,
                  // touch hit area extended without moving the title.
                  RaftPanelAction(
                    key: backKey,
                    glyph: RaftGlyph.arrowLeft,
                    tooltip: backLabel,
                    onPressed: onBack,
                    minHitExtent: RaftMetrics.touchTarget,
                  ),
                  SizedBox(width: recipe.headerGap),
                ],
                Expanded(
                  child: !interactiveTitle
                      ? Semantics(
                          header: true,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: title(),
                          ),
                        )
                      : LayoutBuilder(
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
                              child: ExcludeSemantics(child: title()),
                            ),
                          ),
                        ),
                ),
                if (hasFollowers ||
                    actions.isNotEmpty ||
                    recipe.showClose && onClose != null)
                  SizedBox(width: recipe.headerGap),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (followers != null) followers!,
                    for (var index = 0; index < actions.length; index++) ...[
                      if (hasFollowers || index > 0)
                        SizedBox(width: recipe.actionGap),
                      actions[index],
                    ],
                    if (recipe.showClose && onClose != null) ...[
                      if (hasFollowers || actions.isNotEmpty)
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

  // ThreadOverflowMenu trigger: Button size="icon-sm" variant="outline" with
  // EllipsisVertical (14px), the same control as the channel topbar actions.
  @override
  Widget build(BuildContext context) => RaftPanelIconButton(
    glyph: RaftGlyph.ellipsisVertical,
    tooltip: label,
    onPressed: onPressed,
  );
}

/// Web ThreadPanel `thread-search-bar`: a search icon, the query field, the
/// "n/m" count, previous / next match steppers and a close control. The app
/// owns the query, the matches and the scrolling; this is chrome only.
class RaftThreadSearchBar extends StatelessWidget {
  const RaftThreadSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.countLabel,
    required this.canStep,
    required this.onChanged,
    required this.onStep,
    required this.onClose,
  });
  final TextEditingController controller;
  final FocusNode focusNode;

  /// "1/2", "0/0", the loading label or empty (no query yet).
  final String countLabel;
  final bool canStep;
  final ValueChanged<String> onChanged;

  /// `1` next, `-1` previous (Enter / Shift+Enter, the chevron buttons).
  final ValueChanged<int> onStep;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final muted = t.brutal ? Colors.black.withValues(alpha: .5) : t.muted;
    final hint = raftText(context, 'Search this thread');
    final fieldText = RaftTypography.inherited(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w500,
      color: t.brutal ? Colors.black : t.ink,
    );
    return Container(
      key: const Key('thread-search-bar'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.brutal
            ? Colors.white
            : t.dark
            ? t.card
            : t.panel,
        border: Border(
          bottom: BorderSide(
            color: t.brutal ? Colors.black : t.colors['line-muted']!,
            width: t.brutal ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        spacing: 6,
        children: [
          RaftIcon(RaftGlyph.search, size: 14, color: muted),
          Expanded(
            child: ListenableBuilder(
              listenable: focusNode,
              builder: (context, _) {
                final focused = focusNode.hasFocus;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: t.brutal ? Colors.white : t.panel,
                    border: Border.all(
                      color: t.brutal
                          ? Colors.black
                          : t.colors[focused ? 'line-strong' : 'line-muted']!,
                      width: t.brutal ? 2 : 1,
                    ),
                    boxShadow: focused ? t.themeShadows.sm.outer : const [],
                  ),
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.escape) {
                        onClose();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        onStep(
                          HardwareKeyboard.instance.isShiftPressed ? -1 : 1,
                        );
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      contextMenuBuilder: RaftTextSelectionToolbar.editableText,
                      key: const Key('thread-search-input'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: fieldText,
                      strutStyle: StrutStyle.fromTextStyle(
                        fieldText,
                        forceStrutHeight: true,
                      ),
                      cursorColor: fieldText.color,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: hint,
                        hintStyle: fieldText.copyWith(
                          color: t.brutal
                              ? Colors.black.withValues(alpha: .4)
                              : t.semantic.foregroundPlaceholder,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            key: const Key('thread-search-count'),
            width: 80,
            child: Text(
              countLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: RaftTypography.mono(t, color: muted),
            ),
          ),
          RaftIconButton(
            key: const Key('thread-search-previous'),
            glyph: RaftGlyph.chevronUp,
            tooltip: 'Previous match',
            visualSize: 28,
            minimumTargetSize: 28,
            onPressed: canStep ? () => onStep(-1) : null,
          ),
          RaftIconButton(
            key: const Key('thread-search-next'),
            glyph: RaftGlyph.chevronDown,
            tooltip: 'Next match',
            visualSize: 28,
            minimumTargetSize: 28,
            onPressed: canStep ? () => onStep(1) : null,
          ),
          RaftControl(
            key: const Key('thread-search-close'),
            recipe: _ThreadCloseRecipe(t),
            tooltip: raftText(context, 'Close thread search'),
            semanticLabel: raftText(context, 'Close thread search'),
            onPressed: onClose,
            visualWidth: 28,
            visualHeight: 28,
            minimumTargetSize: 28,
            padding: EdgeInsets.zero,
            child: const RaftIcon(RaftGlyph.x, size: 14),
          ),
        ],
      ),
    );
  }
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
    this.showSummary = true,
  });

  final bool hasMore, historyLimited, loadingOlder;
  final String loadingOlderLabel, historyLimitedLabel, beginningLabel;

  /// Web ThreadPanel renders the history state and the reply count only in
  /// its timeline header; a thread with no replies (not loading) shows the
  /// parent and the empty state instead.
  final bool showSummary;

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
          if (showSummary)
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
