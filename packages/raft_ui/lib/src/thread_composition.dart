import 'text_selection_toolbar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_workspace.dart'
    show RaftAdaptiveWorkspace, RaftThreadPlacement;
import 'design_primitives.dart';
import 'focus_visible.dart';
import 'channel_header.dart' show raftConversationHeaderToggle;
import 'conversation_surface.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart';
import 'recipe_surface.dart';
import 'recipes/panel_header.g.dart' as recipes;
import 'side_panel_frame.dart';
import 'text_scaling.dart' show RaftScaled;
import 'theme.dart';
import 'tooltip.dart';
import 'raft/button.dart';
import 'raft/ui_tokens.dart';

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
  EdgeInsetsDirectional get headerInset =>
      EdgeInsetsDirectional.only(start: 20, end: viewportWidth < 768 ? 14 : 20);
  double get headerGap => (viewportWidth >= 768) ? 12 : 8;
  double get actionGap => (viewportWidth >= 768) ? 6 : 2;

  /// The thread column's header container adds
  /// `in-data-[theme=elegant]:bg-layer-canvas-muted` at every width (Web
  /// v1.21.12 `THREAD_HEADER_CONTAINER_CLASS_NAME`).
  Color get headerBackground =>
      tokens.colors[tokens.option('panelAction.surface', or: 'outline') ==
              'ghost'
          ? 'layer-panel-header'
          : 'layer-canvas-muted']!;
  BorderSide get headerBorder =>
      BorderSide(color: tokens.colors['line-muted']!);
  Color get parentBackground =>
      RaftConversationSurfaceRecipe(tokens)
          .background(RaftConversationSurfaceRole.threadParent);
  EdgeInsets get parentInset => const EdgeInsets.all(12);
  BorderSide get parentBorder =>
      BorderSide(color: tokens.colors['line-muted']!, width: 1);
  EdgeInsets get summaryInset =>
      const EdgeInsets.only(left: 12, right: 12, top: 8);
  TextStyle get history => RaftTypography.mono(tokens, color: tokens.muted);
  TextStyle get replyCount => RaftTypography.mono(tokens, color: tokens.muted);
  TextStyle get beginning =>
      history.copyWith(color: tokens.colors['foreground-placeholder']!);
  BorderSide get summaryBorder =>
      BorderSide(color: tokens.colors['line-muted']!);
  BorderSide get limitedBorder =>
      BorderSide(color: tokens.colors['line-muted']!);
  Color get limitedBackground => tokens.panel;
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
    this.replyCount,
    this.onViewParent,
    this.showBackOverride,
    this.showCloseOverride,
    this.allowFocusMode = false,
    this.stackMeta = false,
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
  final int? replyCount;
  final VoidCallback? onViewParent;
  final bool? showBackOverride, showCloseOverride;
  final bool allowFocusMode, stackMeta;
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
    final placement = RaftThreadPlacement.maybeOf(context);
    final desktopSidePanel =
        !RaftAdaptiveWorkspace.compactOf(context) && placement != null;
    final folded = placement?.foldedInSideRow ?? false;
    final showBack = (showBackOverride ?? (folded || recipe.showBack));
    final showClose = (showCloseOverride ?? (!folded && recipe.showClose));
    final toggleFocus = allowFocusMode ? placement?.toggleFocus : null;
    final focused = placement?.focused ?? false;
    final width = viewportWidth ?? viewport.width;
    final inline = !stackMeta && !grows && width >= 768;
    final titleStyle = tokens.scale(tokens.typeSlot('headline'));
    final metaStyle = recipes.RaftPanelHeaderRecipe.resolve(
      tokens: tokens.recipeTokens,
      states: tokens.recipeStates(responsive: true),
    ).meta.text(tokens.recipeTokens);

    final title = interactiveTitle && onJumpToStart != null
        ? RaftTooltip(
            message: jumpLabel,
            child: RaftTextLink(
              key: jumpKey,
              label: threadLabel,
              semanticLabel: jumpLabel,
              variant: RaftTextLinkVariant.strong,
              typeStyle: titleStyle,
              onPressed: onJumpToStart,
            ),
          )
        : Semantics(header: true, child: Text(threadLabel, style: titleStyle));
    final count = replyCount;
    final label = parentLabel;
    final meta = label == null
        ? null
        : LayoutBuilder(
            builder: (context, bounds) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bounds.maxWidth),
                  child: onViewParent == null
                      ? Text(
                          label,
                          style: metaStyle,
                          maxLines: grows ? null : 1,
                          overflow: grows ? null : TextOverflow.ellipsis,
                        )
                      : RaftTextLink(
                          key: const Key('thread-header-channel-link'),
                          label: label,
                          variant: RaftTextLinkVariant.muted,
                          typeStyle: metaStyle,
                          maxLines: grows ? null : 1,
                          onPressed: onViewParent,
                        ),
                ),
                if (count != null)
                  Flexible(
                    child: Text(
                      ' · ${raftFormat(context, count == 1 ? '{count} reply' : '{count} replies', {'count': count})}',
                      key: const Key('thread-header-reply-count'),
                      style: metaStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
    final header = RaftPanelHeaderBar(
      title: threadLabel,
      titleSlot: meta == null
          ? Align(alignment: AlignmentDirectional.centerStart, child: title)
          : inline
          ? Row(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                title,
                Flexible(child: meta),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [title, meta],
            ),
      onBack: showBack ? onBack : null,
      backKey: backKey,
      backTooltip: backLabel,
      background: recipe.headerBackground,
      bottomBorder: desktopSidePanel
          ? RaftSidePanelFrame.headerRule(tokens)
          : Border(bottom: recipe.headerBorder),
      actions: [
        if (followers != null && followersVisible) followers!,
        ...actions,
        if (toggleFocus != null)
          raftConversationHeaderToggle(
            key: const Key('thread-focus-mode'),
            glyph: focused ? RaftGlyph.minimize2 : RaftGlyph.maximize2,
            label: raftText(context, focused ? 'Restore' : 'Expand'),
            pressed: focused,
            onPressed: toggleFocus,
          ),
        if (showClose && onClose != null)
          RaftPanelAction(
            key: closeKey,
            glyph: RaftGlyph.x,
            tooltip: closeLabel,
            onPressed: onClose,
          ),
      ],
    );
    if (viewportWidth == null && viewportHeight == null) return header;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(
          viewportWidth ?? viewport.width,
          viewportHeight ?? viewport.height,
        ),
      ),
      child: header,
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

  // ThreadOverflowMenu trigger: raft-ui PanelAction with EllipsisVertical
  // (Web ThreadOverflowMenu.tsx); the pack's `panelAction.surface` picks the
  // drawing (RaftPanelIconButton).
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
    this.task = false,
  });
  final bool task;
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
    final muted = t.ui.foregroundHint;
    final closeLabel = raftText(context, 'Close thread search');
    final hint = raftText(
      context,
      task ? 'Search this task' : 'Search this thread',
    );
    final fieldText = RaftTypography.inherited(
      t,
      size: 14,
      line: 20,
      weight: FontWeight.w500,
      color: t.ink,
    );
    return Container(
      key: const Key('thread-search-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.colors['layer-conversation-content'],
        border: Border(bottom: BorderSide(color: t.ui.lineSeam)),
      ),
      child: Row(
        spacing: 4,
        children: [
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                focusNode,
                RaftFocusVisible.shared,
              ]),
              builder: (context, _) {
                final focused =
                    focusNode.hasFocus && RaftFocusVisible.shared.keyboard;
                return Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: t.colors['layer-card'],
                    borderRadius: BorderRadius.circular(t.radius),
                    border: Border.all(color: t.ui.lineField, width: 1.5),
                    boxShadow: focused ? t.focusShadows : const [],
                  ),
                  child: Row(
                    spacing: 8,
                    children: [
                      RaftIcon(
                        RaftGlyph.search,
                        size: 16,
                        color: t.ui.foregroundHint,
                      ),
                      Expanded(
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
                                event.logicalKey ==
                                    LogicalKeyboardKey.numpadEnter) {
                              onStep(
                                HardwareKeyboard.instance.isShiftPressed
                                    ? -1
                                    : 1,
                              );
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            contextMenuBuilder:
                                RaftTextSelectionToolbar.editableText,
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
                                color: t.semantic.foregroundPlaceholder,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            key: const Key('thread-search-count'),
            width: 64,
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
          if (t.desktop)
            RaftControl(
              key: const Key('thread-search-close'),
              recipe: _ThreadCloseRecipe(t),
              tooltip: closeLabel,
              semanticLabel: closeLabel,
              onPressed: onClose,
              visualWidth: 28,
              visualHeight: 28,
              minimumTargetSize: 28,
              padding: EdgeInsets.zero,
              child: const RaftIcon(RaftGlyph.x, size: 14),
            )
          else
            RaftButton(
              key: const Key('thread-search-close'),
              uiVariant: RaftButtonVariant.ghost,
              uiSize: RaftButtonSize.iconMd,
              glyph: RaftGlyph.x,
              glyphSize: 14,
              foreground: t.muted,
              tooltip: closeLabel,
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
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
  Color get foreground => tokens.muted;
  @override
  Color backgroundFor({bool hovered = false}) =>
      (hovered) ? tokens.colors['fill-muted']! : background;
}

class _ThreadBackRecipe extends RaftControlRecipe {
  const _ThreadBackRecipe(super.tokens)
    : super(variant: RaftControlVariant.outline, visualHeight: 28);
  @override
  bool get transformsOnInteraction => false;
  @override
  BorderRadius get radius => BorderRadius.circular(6);
  @override
  Color backgroundForInteraction({
    bool hovered = false,
    bool pressed = false,
  }) => backgroundFor(hovered: hovered || pressed);
  @override
  Color get background => Colors.transparent;
  @override
  Color backgroundFor({bool hovered = false}) => (hovered)
      ? tokens.colors['fill-strong']!.withValues(
          alpha: tokens.colors['fill-strong']!.a * .8,
        )
      : background;
  @override
  Color get foreground => tokens.colors['foreground-icon']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      (hovered) ? tokens.strong : foreground;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  double get focusOutlineWidth => 0;
  @override
  double get focusOutlineOffset => 0;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => focused
      ? [BoxShadow(color: tokens.colors['primary-500']!, spreadRadius: .5)]
      : const [];
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
    this.historyLimitedChild,
    this.parent,
    this.parentSlot,
    this.parentKey,
    this.showSummary = true,
  });

  final bool hasMore, historyLimited, loadingOlder;
  final String loadingOlderLabel, historyLimitedLabel, beginningLabel;

  /// What stands in for the one-line cutoff notice once the replies reach the
  /// start of what the plan shows (Web's history paywall); null keeps the line.
  final Widget? historyLimitedChild;

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
                  if (historyLimitedChild != null &&
                      raftThreadHistoryState(
                            hasMore: hasMore,
                            historyLimited: historyLimited,
                          ) ==
                          RaftThreadHistoryState.limited)
                    historyLimitedChild!
                  else
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
