import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'sidebar_section.dart';
import 'theme.dart';

enum RaftChatSidebarGroupKind { pinned, joint, channels, directMessages }

/// Mounted Sidebar.tsx groups, not the unmounted generic RUI SidebarSectionEmpty.
class RaftChatSidebarGroupRecipe {
  const RaftChatSidebarGroupRecipe(this.tokens, this.kind);
  final RaftTokens tokens;
  final RaftChatSidebarGroupKind kind;
  bool get revealWhileDragging =>
      kind == RaftChatSidebarGroupKind.pinned ||
      kind == RaftChatSidebarGroupKind.joint;
  int get loadingRows => switch (kind) {
    RaftChatSidebarGroupKind.pinned => 0,
    RaftChatSidebarGroupKind.joint => 2,
    RaftChatSidebarGroupKind.channels => 4,
    RaftChatSidebarGroupKind.directMessages => 3,
  };
  bool hidden({
    required int count,
    required bool loading,
    required bool hideEmpty,
    bool dragActive = false,
    bool dragSource = false,
  }) =>
      kind != RaftChatSidebarGroupKind.channels &&
      hideEmpty &&
      !loading &&
      count == 0 &&
      !(dragActive && (dragSource || revealWhileDragging));
  EdgeInsets get descriptionInset => kind == RaftChatSidebarGroupKind.pinned
      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
      : const EdgeInsets.symmetric(horizontal: 8);
  double get minimumDescriptionHeight =>
      kind == RaftChatSidebarGroupKind.pinned ? 36 : 0;
  double get descriptionBottomMargin =>
      kind == RaftChatSidebarGroupKind.pinned ? 4 : 0;
  TextStyle get description => RaftTypography.mono(
    tokens,
    size: 12,
    line: 16.5,
    color: tokens.brutal
        ? Colors.black.withValues(
            alpha: kind == RaftChatSidebarGroupKind.pinned ? .45 : .5,
          )
        : tokens.colors[kind == RaftChatSidebarGroupKind.pinned
              ? 'foreground-placeholder'
              : 'foreground-muted'],
  );
}

/// Caller owns authoritative filtered entries/count, collapse/preferences,
/// drag admission, actions and loading. Empty DMs deliberately have no hint.
class RaftChatSidebarGroup extends StatelessWidget {
  const RaftChatSidebarGroup({
    super.key,
    required this.kind,
    required this.label,
    required this.count,
    required this.expanded,
    required this.hideEmpty,
    required this.onExpandedChanged,
    required this.children,
    this.loading = false,
    this.dragActive = false,
    this.dragSource = false,
    this.emptyLabel = '',
    this.loadingRegion,
    this.attention,
    this.actions = const [],
    this.disclosureKey,
    this.headerKey,
  });
  final RaftChatSidebarGroupKind kind;
  final String label, emptyLabel;
  final int count;
  final bool expanded, hideEmpty, loading, dragActive, dragSource;
  final ValueChanged<bool> onExpandedChanged;
  final List<Widget> children;
  final List<RaftSidebarSectionAction> actions;
  final Widget? loadingRegion, attention;
  final Key? disclosureKey, headerKey;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftChatSidebarGroupRecipe(RaftTokens.of(context), kind);
    if (recipe.hidden(
      count: count,
      loading: loading,
      hideEmpty: hideEmpty,
      dragActive: dragActive,
      dragSource: dragSource,
    ))
      return const SizedBox.shrink();
    Widget? empty;
    if (count == 0) {
      if (loading && recipe.loadingRows > 0) {
        empty =
            loadingRegion ??
            RaftChatSidebarLoadingRows(rows: recipe.loadingRows);
      } else if (kind != RaftChatSidebarGroupKind.directMessages &&
          emptyLabel.isNotEmpty) {
        empty = Padding(
          padding: EdgeInsets.only(bottom: recipe.descriptionBottomMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: recipe.minimumDescriptionHeight,
            ),
            child: Padding(
              padding: recipe.descriptionInset,
              child: Text(emptyLabel, style: recipe.description),
            ),
          ),
        );
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaftSidebarSectionHeader(
          key: headerKey,
          label: label,
          count: count,
          expanded: expanded,
          onExpandedChanged: onExpandedChanged,
          disclosureKey: disclosureKey,
          actions: actions,
          attention: attention,
        ),
        if (expanded) ...[...children, if (empty != null) empty],
      ],
    );
  }
}

/// Product Skeleton.tsx (not RUI Skeleton): px8/py8/gap6,
/// 18px bordered avatar and a 60%-width, 12px line in all three themes.
/// Decorative only; host owns the loading announcement and authority.
class RaftChatSidebarLoadingRows extends StatefulWidget {
  const RaftChatSidebarLoadingRows({super.key, required this.rows});
  final int rows;
  @override
  State<RaftChatSidebarLoadingRows> createState() => _LoadingRowsState();
}

class _LoadingRowsState extends State<RaftChatSidebarLoadingRows>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final opacity = Tween<double>(
    begin: 1,
    end: .5,
  ).animate(CurvedAnimation(parent: pulse, curve: const Cubic(.4, 0, .6, 1)));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = 0;
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FadeTransition(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < widget.rows; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: .05),
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: .6,
                        child: Container(
                          height: 12,
                          color: Colors.black.withValues(alpha: .1),
                        ),
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

enum RaftConversationTabId { chat, tasks, files }

@immutable
class RaftConversationTab {
  const RaftConversationTab({
    required this.id,
    required this.label,
    this.enabled = true,
  });
  final RaftConversationTabId id;
  final String label;
  final bool enabled;
}

/// ConversationPanelTabs + underline Tabs + product h7/max-md h10 overrides.
class RaftConversationTabsRecipe {
  const RaftConversationTabsRecipe(
    this.tokens, {
    required this.mobile,
    required this.density,
  });
  final RaftTokens tokens;
  final bool mobile;
  final RaftDensity density;
  double get sourceTabHeight => tokens.brutal
      ? 28
      : mobile
      ? 40
      : 28;
  double get sourceListHeight => tokens.brutal
      ? 28
      : mobile
      ? 40
      : 48;
  // ChatPanel mounts h-7 tabs (Elegant mobile is overridden to h-10 by
  // ConversationPanelTabs). Its flow stays source-sized on coarse input too;
  // the generic 48px native target must not enlarge this specific tab strip.
  double get targetHeight => sourceTabHeight;
  double get effectiveListHeight => math.max(sourceListHeight, targetHeight);
  double get outerBottomBorder => tokens.brutal
      ? 2
      : mobile
      ? 1
      : 0;
  Color get background => tokens.brutal
      ? Colors.white
      : mobile
      ? tokens.colors['layer-canvas-muted']!
      // ConversationPanelContent is the mounted ancestor: dark tabs are
      // transparent over its card surface, independently of the panel timeline.
      : tokens.dark
      ? tokens.card
      : tokens.panel;
  Color get border =>
      tokens.brutal ? Colors.black : tokens.colors['line-muted']!;
  double get gap => tokens.brutal ? 0 : 4;
  EdgeInsets get listInset =>
      EdgeInsets.symmetric(horizontal: tokens.brutal ? 0 : 16);
  double horizontalInset(int index) => tokens.brutal
      ? index == 0
            ? 22
            : 16
      : 12;
  EdgeInsets tabInset(int index) => tokens.brutal
      ? EdgeInsets.only(left: index == 0 ? 22 : 16, right: 16)
      : const EdgeInsets.symmetric(horizontal: 12);
  double get glyphSize => 14;
  double get glyphStroke => tokens.brutal ? 2.5 : 1.5;
  double get indicatorHeight => mobile ? 1 : 2;
  Color get indicator => tokens.colors['primary-400']!;
}

class _ConversationTabControlRecipe extends RaftControlRecipe {
  const _ConversationTabControlRecipe(super.tokens, {required super.selected});
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => tokens.brutal
      ? selected
            ? tokens.primaryFill
            : Colors.white
      : Colors.transparent;
  // Product direct-child bg-white selector overrides the lower-specificity
  // generic Brutal tab hover background. Active hover stays primary.
  @override
  Color backgroundFor({bool hovered = false}) => background;
  @override
  Color get foreground => tokens.brutal
      ? Colors.black
      : selected
      ? tokens.ink
      : tokens.colors['foreground-placeholder']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      tokens.brutal || selected || !hovered ? foreground : tokens.muted;
  @override
  Gradient? get overlayGradient => null;
  @override
  double get insetHighlightAlpha => 0;
  @override
  BorderRadius get radius => BorderRadius.zero;
  @override
  BorderSide side({bool hovered = false}) => BorderSide.none;
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => const [];
  @override
  TextStyle get textStyle => RaftTypography.body(
    tokens,
    size: tokens.brutal ? 12 : 13,
    line: tokens.brutal ? 16 : 19.5,
    weight: tokens.brutal ? FontWeight.w600 : FontWeight.w500,
  ).copyWith(letterSpacing: tokens.brutal ? 0 : -.065);
}

/// Controlled selected/query value. Host supplies scoped persisted order and
/// an optional real drag wrapper; no fabricated reorder/network state here.
class RaftConversationTabs extends StatefulWidget {
  const RaftConversationTabs({
    super.key,
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.hideHeader = false,
    this.reorderWrapper,
  });
  final List<RaftConversationTab> tabs;
  final RaftConversationTabId value;
  final ValueChanged<RaftConversationTabId> onChanged;
  final bool hideHeader;
  final Widget Function(Widget child, RaftConversationTab tab, int index)?
  reorderWrapper;
  @override
  State<RaftConversationTabs> createState() => _ConversationTabsState();
}

class _ConversationTabsState extends State<RaftConversationTabs> {
  final nodes = <RaftConversationTabId, FocusNode>{};
  @override
  void dispose() {
    for (final node in nodes.values) {
      node.removeListener(changed);
      node.dispose();
    }
    super.dispose();
  }

  FocusNode node(RaftConversationTabId id) =>
      nodes.putIfAbsent(id, () => FocusNode()..addListener(changed));
  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(RaftConversationTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final id in nodes.keys.toList()) {
      if (!widget.tabs.any((tab) => tab.id == id)) {
        final removed = nodes.remove(id)!;
        removed.removeListener(changed);
        removed.dispose();
      }
    }
  }

  KeyEventResult navigation(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final enabled = widget.tabs.where((tab) => tab.enabled).toList();
    if (enabled.isEmpty) return KeyEventResult.ignored;
    final current = enabled.indexWhere(
      (tab) => nodes[tab.id]?.hasFocus ?? false,
    );
    int next;
    if (event.logicalKey == LogicalKeyboardKey.home) {
      next = 0;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      next = enabled.length - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      var delta = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
      if (Directionality.of(context) == TextDirection.rtl) delta = -delta;
      next =
          ((current < 0
                  ? enabled.indexWhere((tab) => tab.id == widget.value)
                  : current) +
              delta) %
          enabled.length;
    } else {
      return KeyEventResult.ignored;
    }
    node(enabled[next].id).requestFocus();
    widget.onChanged(enabled[next].id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideHeader || widget.tabs.length <= 1)
      return const SizedBox.shrink();
    final tokens = RaftTokens.of(context);
    final recipe = RaftConversationTabsRecipe(
      tokens,
      mobile:
          MediaQuery.sizeOf(context).width <
          RaftLayoutMetrics.desktopBreakpoint,
      density: RaftDensityScope.of(context),
    );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: recipe.background,
        border: Border(
          bottom: BorderSide(
            color: recipe.border,
            width: recipe.outerBottomBorder,
          ),
        ),
      ),
      child: SizedBox(
        height: recipe.effectiveListHeight,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: navigation,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Padding(
              padding: recipe.listInset,
              child: Semantics(
                role: SemanticsRole.tabBar,
                explicitChildNodes: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (
                      var index = 0;
                      index < widget.tabs.length;
                      index++
                    ) ...[
                      if (index > 0 && recipe.gap > 0)
                        SizedBox(width: recipe.gap),
                      buildTab(widget.tabs[index], index, recipe),
                    ],
                    // Source TabsList owns the final right border; separators
                    // belong to the following tab and do not consume its width.
                    if (recipe.tokens.brutal)
                      SizedBox(
                        key: const ValueKey('conversation-tab-list-edge'),
                        width: 2,
                        height: recipe.sourceTabHeight,
                        child: const ColoredBox(color: Colors.black),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildTab(
    RaftConversationTab tab,
    int index,
    RaftConversationTabsRecipe recipe,
  ) {
    final selected = tab.id == widget.value;
    final focus = node(tab.id);
    final control = Semantics(
      role: SemanticsRole.tab,
      label: tab.label,
      selected: selected,
      enabled: tab.enabled,
      focusable: tab.enabled,
      focused: focus.hasFocus,
      onTap: tab.enabled ? () => widget.onChanged(tab.id) : null,
      child: ExcludeSemantics(
        child: SizedBox(
          height: recipe.effectiveListHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              RaftControl(
                key: ValueKey('panel-tab-${tab.id.name}'),
                focusNode: focus,
                recipe: _ConversationTabControlRecipe(
                  recipe.tokens,
                  selected: selected,
                ),
                onPressed: tab.enabled ? () => widget.onChanged(tab.id) : null,
                visualHeight: recipe.sourceTabHeight,
                minimumTargetSize: recipe.targetHeight,
                padding: recipe.tabInset(index),
                shadow: false,
                child: Builder(
                  builder: (context) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.id == RaftConversationTabId.tasks)
                        _ConversationTaskGlyph(
                          size: recipe.glyphSize,
                          stroke: recipe.glyphStroke,
                          color:
                              DefaultTextStyle.of(context).style.color ??
                              recipe.tokens.ink,
                        )
                      else
                        RaftIcon(
                          tab.id == RaftConversationTabId.chat
                              ? RaftGlyph.messageSquare
                              : RaftGlyph.paperclip,
                          size: recipe.glyphSize,
                          strokeWidth: recipe.glyphStroke,
                        ),
                      const SizedBox(width: 6),
                      Text(tab.label),
                    ],
                  ),
                ),
              ),
              if (recipe.tokens.brutal && index > 0)
                Positioned(
                  key: ValueKey('conversation-tab-separator-${tab.id.name}'),
                  left: 0,
                  top:
                      (recipe.effectiveListHeight - recipe.sourceTabHeight) / 2,
                  height: recipe.sourceTabHeight,
                  width: 2,
                  child: IgnorePointer(child: ColoredBox(color: Colors.black)),
                ),
              if (selected && !recipe.tokens.brutal)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: recipe.indicatorHeight,
                  child: IgnorePointer(
                    child: ColoredBox(color: recipe.indicator),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return widget.reorderWrapper?.call(control, tab, index) ?? control;
  }
}

class _ConversationTaskGlyph extends StatelessWidget {
  const _ConversationTaskGlyph({
    required this.size,
    required this.stroke,
    required this.color,
  });
  final double size, stroke;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ListTodoPainter(color, stroke)),
  );
}

class _ListTodoPainter extends CustomPainter {
  // Exact lucide-react 0.575.0 ListTodo geometry; existing Lucide license applies.
  const _ListTodoPainter(this.color, this.stroke);
  final Color color;
  final double stroke;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final y in [5.0, 12.0, 19.0]) {
      canvas.drawLine(Offset(13, y), Offset(21, y), paint);
    }
    canvas.drawPath(
      Path()
        ..moveTo(3, 17)
        ..lineTo(5, 19)
        ..lineTo(9, 15),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 4, 6, 6),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ListTodoPainter old) =>
      color != old.color || stroke != old.stroke;
}

class RaftConversationHeaderActionsRecipe {
  const RaftConversationHeaderActionsRecipe(
    this.tokens, {
    required this.mobile,
  });
  final RaftTokens tokens;
  final bool mobile;
  double get visualSize => 28;
  double get glyphSize => 14;
  double get gap => mobile && !tokens.brutal ? 2 : 6;
}

/// The two real sibling header actions; opening the settings drawer is app-owned.
class RaftConversationHeaderActions extends StatelessWidget {
  const RaftConversationHeaderActions({
    super.key,
    required this.onSearch,
    required this.onSettings,
    required this.searchLabel,
    required this.settingsLabel,
  });
  final VoidCallback onSearch, onSettings;
  final String searchLabel, settingsLabel;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftConversationHeaderActionsRecipe(
      RaftTokens.of(context),
      mobile:
          MediaQuery.sizeOf(context).width <
          RaftLayoutMetrics.desktopBreakpoint,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftIconButton(
          key: const ValueKey('channel-topbar-search'),
          glyph: RaftGlyph.search,
          visualSize: recipe.visualSize,
          glyphSize: recipe.glyphSize,
          variant: RaftControlVariant.outline,
          tooltip: searchLabel,
          onPressed: onSearch,
        ),
        SizedBox(width: recipe.gap),
        RaftIconButton(
          key: const ValueKey('channel-overflow-trigger'),
          glyph: RaftGlyph.settings,
          visualSize: recipe.visualSize,
          glyphSize: recipe.glyphSize,
          variant: RaftControlVariant.outline,
          tooltip: settingsLabel,
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// Already-formatted viewer-zone day label. Grouping/time preferences remain app-owned.
class RaftConversationDateHeader extends StatelessWidget {
  const RaftConversationDateHeader({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final text =
        RaftTypography.mono(
          t,
          size: t.brutal ? 10 : 11,
          line: t.brutal ? 15 : 16.5,
          color: t.brutal ? Colors.black.withValues(alpha: .5) : t.muted,
        ).copyWith(
          fontFamily: t.brutal ? t.bodyFont : t.monoFont,
          fontWeight: t.brutal ? FontWeight.w700 : FontWeight.w400,
          letterSpacing: t.brutal ? 1 : 1.1,
        );
    final line = Divider(
      height: t.brutal ? 2 : 1,
      thickness: t.brutal ? 2 : 1,
      color: t.brutal
          ? Colors.black.withValues(alpha: .15)
          : t.colors[t.dark ? 'ink-4' : 'line-hairline'],
    );
    return Semantics(
      header: true,
      child: Opacity(
        opacity: t.brutal ? 1 : .7,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labelText = label.toUpperCase();
              final painter = TextPainter(
                text: TextSpan(text: labelText, style: text),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: math.max(0.0, constraints.maxWidth - 16));
              final labelWidth = math.min(
                painter.maxIntrinsicWidth,
                math.max(0.0, constraints.maxWidth - 16),
              );
              painter.dispose();
              // RUI MessageListDateDivider has two flex-1 rules around an
              // intrinsic-width chip. A flex6 label reserves unused middle
              // space even when its text is short, shortening both rules.
              return Row(
                children: [
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, t.brutal ? 1 : 0),
                      child: line,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: labelWidth,
                      child: Text(
                        labelText,
                        style: text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, t.brutal ? 1 : 0),
                      child: line,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ComposerTaskControlRecipe extends _ConversationTabControlRecipe {
  const _ComposerTaskControlRecipe(super.tokens) : super(selected: false);
  @override
  Color get background => Colors.transparent;
  @override
  Color get foreground =>
      tokens.brutal ? Colors.black.withValues(alpha: .6) : tokens.strong;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  TextStyle get textStyle =>
      RaftTypography.body(tokens, size: 12, line: 16, weight: FontWeight.w700);
}

/// Controlled checkbox presentation for RaftComposer.taskAction. This never
/// creates a task or sends a message; the host owns both actual source actions.
class RaftComposerTaskToggle extends StatefulWidget {
  const RaftComposerTaskToggle({
    super.key,
    required this.checked,
    required this.label,
    required this.onChanged,
    this.tooltip,
  });
  final bool checked;
  final String label;
  final String? tooltip;
  final ValueChanged<bool>? onChanged;
  @override
  State<RaftComposerTaskToggle> createState() => _ComposerTaskToggleState();
}

class _ComposerTaskToggleState extends State<RaftComposerTaskToggle> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return TextFieldTapRegion(
      child: Semantics(
        label: widget.label,
        checked: widget.checked,
        enabled: widget.onChanged != null,
        focusable: widget.onChanged != null,
        focused: focus.hasFocus,
        onTap: widget.onChanged == null
            ? null
            : () => widget.onChanged!(!widget.checked),
        child: ExcludeSemantics(
          child: RaftControl(
            key: const ValueKey('composer-as-task-toggle'),
            minimumTargetSize: 16,
            focusNode: focus,
            focusOnPointer: false,
            visualHeight: 16,
            padding: EdgeInsets.zero,
            shadow: false,
            tooltip: widget.tooltip,
            recipe: _ComposerTaskControlRecipe(t),
            onPressed: widget.onChanged == null
                ? null
                : () => widget.onChanged!(!widget.checked),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: widget.checked
                        ? t.brutal
                              ? Colors.black
                              : t.strong
                        : t.panel,
                    border: Border.all(
                      color: t.brutal ? Colors.black : t.colors['line-strong']!,
                      width: t.brutal ? 2 : 1,
                    ),
                  ),
                  child: widget.checked
                      ? Center(
                          child: RaftIcon(
                            RaftGlyph.check,
                            size: 10,
                            strokeWidth: 4,
                            color: t.brutal
                                ? Colors.white
                                : t.colors['foreground-inverse'],
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(widget.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
