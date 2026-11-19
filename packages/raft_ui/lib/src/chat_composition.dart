import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_primitives.dart';
import 'recipe_surface.dart';
import 'recipes/message_list.g.dart';
import 'raft/tabs.dart';
import 'raft/checkbox.dart';
import 'viewport_breakpoints.dart';
import 'icons.dart';
import 'interaction.dart';
import 'message_rule_row.dart';
import 'panel_layout.dart' show RaftCssText;
import 'sidebar_frame.dart';
import 'sidebar_section.dart';
import 'space.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftDesktopTypeScale;
import 'status_bar.dart';
import 'text_scaling.dart';
import 'large_content_viewer.dart';
import 'tap_slop.dart';

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
    bool revealEmptyDropTarget = true,
  }) =>
      kind != RaftChatSidebarGroupKind.channels &&
      hideEmpty &&
      !loading &&
      count == 0 &&
      !(dragActive &&
          (dragSource || (revealWhileDragging && revealEmptyDropTarget)));
  static bool usesDesktopDescription(BuildContext context) =>
      raftBreakpointWidth(context) >= RaftLayoutMetrics.desktopBreakpoint &&
      RaftInteraction.of(context).pointer;

  EdgeInsetsDirectional descriptionInset({required bool desktop}) {
    final block =
        kind == RaftChatSidebarGroupKind.pinned ||
            (desktop && kind == RaftChatSidebarGroupKind.joint)
        ? RaftSpace.x2
        : 0.0;
    return EdgeInsetsDirectional.fromSTEB(
      desktop ? RaftSpace.x4 * 2 : RaftSpace.x5,
      block,
      desktop ? RaftSpace.x2 : RaftSpace.x5,
      block,
    );
  }

  double get minimumDescriptionHeight =>
      kind == RaftChatSidebarGroupKind.pinned ? 36 : 0;
  TextStyle description({required bool desktop}) => RaftTypography.body(
    tokens,
    size: 12,
    line: desktop ? RaftDesktopTypeScale.footnote.lineHeight : 16,
    color:
        tokens.colors[kind == RaftChatSidebarGroupKind.pinned
            ? 'foreground-hint'
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
    this.revealEmptyDropTarget = true,
    this.emptyLabel = '',
    this.loadingRegion,
    this.attention,
    this.actions = const [],
    this.disclosureKey,
    this.headerKey,
    this.onContextMenu,
    this.contextMenuOnLongPress = true,
    this.wrapHeader,
    this.wrapEmpty,
  }) : itemBuilder = null,
       findChildIndexCallback = null,
       onReorderItem = null;

  /// A group in a scroll viewport whose offscreen rows are built on demand.
  const RaftChatSidebarGroup.sliver({
    super.key,
    required this.kind,
    required this.label,
    required this.count,
    required this.expanded,
    required this.hideEmpty,
    required this.onExpandedChanged,
    required IndexedWidgetBuilder this.itemBuilder,
    this.findChildIndexCallback,
    this.onReorderItem,
    this.loading = false,
    this.dragActive = false,
    this.dragSource = false,
    this.revealEmptyDropTarget = true,
    this.emptyLabel = '',
    this.loadingRegion,
    this.attention,
    this.actions = const [],
    this.disclosureKey,
    this.headerKey,
    this.onContextMenu,
    this.contextMenuOnLongPress = true,
    this.wrapHeader,
    this.wrapEmpty,
  }) : children = const [];

  final IndexedWidgetBuilder? itemBuilder;
  final ChildIndexGetter? findChildIndexCallback;

  /// Non-null makes the rows a [SliverReorderableList] (indexes as
  /// [SliverReorderableList.onReorderItem] reports them). Each row must then
  /// carry its own key and drag start listener (long press lifts it).
  final ReorderCallback? onReorderItem;
  final ValueChanged<Offset>? onContextMenu;

  /// See [RaftSidebarSectionHeader.contextMenuOnLongPress].
  final bool contextMenuOnLongPress;

  /// Wraps the built header (the host makes it a drag handle or drop target).
  final Widget Function(Widget header)? wrapHeader;

  /// Wraps the empty-section hint (the host makes it a drop target).
  final Widget Function(Widget empty)? wrapEmpty;
  final RaftChatSidebarGroupKind kind;
  final String label, emptyLabel;
  final int count;
  final bool expanded, hideEmpty, loading, dragActive, dragSource;
  final bool revealEmptyDropTarget;
  final ValueChanged<bool> onExpandedChanged;
  final List<Widget> children;
  final List<RaftSidebarSectionAction> actions;
  final Widget? loadingRegion, attention;
  final Key? disclosureKey, headerKey;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftChatSidebarGroupRecipe(RaftTokens.of(context), kind);
    final compact =
        raftBreakpointWidth(context) < RaftLayoutMetrics.desktopBreakpoint;
    final desktopDescription =
        RaftChatSidebarGroupRecipe.usesDesktopDescription(context);
    if (recipe.hidden(
      count: count,
      loading: loading,
      hideEmpty: hideEmpty,
      dragActive: dragActive,
      dragSource: dragSource,
      revealEmptyDropTarget: revealEmptyDropTarget,
    )) {
      return itemBuilder == null
          ? const SizedBox.shrink()
          : const SliverToBoxAdapter();
    }
    Widget? empty;
    final pinned = kind == RaftChatSidebarGroupKind.pinned;
    final dms = kind == RaftChatSidebarGroupKind.directMessages;
    if (count == 0) {
      if (loading && recipe.loadingRows > 0) {
        empty =
            loadingRegion ??
            RaftChatSidebarLoadingRows(
              rows: recipe.loadingRows,
              icon: kind != RaftChatSidebarGroupKind.directMessages,
            );
      } else if (!dms &&
          emptyLabel.isNotEmpty &&
          !(pinned && loading && hideEmpty)) {
        empty = ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: recipe.minimumDescriptionHeight,
          ),
          child: Padding(
            padding: recipe.descriptionInset(desktop: desktopDescription),
            child: RaftCssText(
              emptyLabel,
              style: recipe.description(desktop: desktopDescription),
            ),
          ),
        );
        if (pinned && loading) {
          empty = Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: empty,
          );
        }
      }
    }
    final built = RaftSidebarSectionHeader(
      key: headerKey,
      label: label,
      count: loading && (pinned || dms) ? null : count,
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      disclosureKey: disclosureKey,
      actions: actions,
      attention: attention,
      onContextMenu: onContextMenu,
      contextMenuOnLongPress: contextMenuOnLongPress,
    );
    final header = wrapHeader?.call(built) ?? built;
    final emptyRegion = empty == null
        ? null
        : (wrapEmpty ?? (Widget w) => w)(
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: empty,
            ),
          );
    final builder = itemBuilder;
    if (builder != null) {
      final rows = onReorderItem != null
          ? SliverReorderableList(
              itemCount: count,
              itemBuilder: builder,
              onReorderItem: onReorderItem!,
              proxyDecorator: raftSidebarReorderProxy,
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                builder,
                childCount: count,
                findChildIndexCallback: findChildIndexCallback,
              ),
            );
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: header),
          if (expanded)
            SliverPadding(
              padding: EdgeInsets.only(
                top: compact ? 8 : 0,
                bottom: compact
                    ? 8 - (count == 0 ? 0 : RaftLayoutMetrics.sidebarRowGap)
                    : 0,
              ),
              sliver: emptyRegion == null
                  ? rows
                  : SliverToBoxAdapter(child: emptyRegion),
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (expanded) ...[...children, if (emptyRegion != null) emptyRegion],
      ],
    );
  }
}

/// The lifted row of a reorderable sidebar list. Rows are ghost controls, so
/// the proxy carries the sidebar canvas to stay legible over the rows below.
Widget raftSidebarReorderProxy(
  Widget child,
  int index,
  Animation<double> animation,
) => Builder(
  builder: (context) {
    final size = MediaQuery.sizeOf(context);
    return ColoredBox(
      color: RaftSidebarRecipe(
        RaftTokens.of(context),
        viewportWidth: size.width,
        viewportHeight: size.height,
        variant: RaftSidebarVariant.mountedProduct,
      ).bodyBackground,
      child: child,
    );
  },
);

/// Product Skeleton.tsx (not RUI Skeleton): px8/py8/gap6,
/// 18px bordered avatar and a 60%-width, 12px line in all three themes.
/// Decorative only; host owns the loading announcement and authority.
class RaftChatSidebarLoadingRows extends RaftSidebarRowsSkeleton {
  const RaftChatSidebarLoadingRows({
    super.key,
    required super.rows,
    super.icon,
  });
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

/// Mounted ConversationPanelTabs layout, with the pack-selected tab surface.
class RaftConversationTabsRecipe {
  const RaftConversationTabsRecipe(
    this.tokens, {
    required this.mobile,
    required this.density,
  });
  final RaftTokens tokens;
  final bool mobile;
  final RaftDensity density;
  RaftTabsVariant get variant =>
      tokens.option('conversationTabs.variant', or: 'underline') == 'default'
      ? RaftTabsVariant.standard
      : RaftTabsVariant.underline;
  bool get compactSticker =>
      !mobile && tokens.desktop && variant == RaftTabsVariant.standard;
  double get sourceTabHeight => compactSticker
      ? RaftLayoutMetrics.desktopControl
      : tokens.size(
          mobile ? 'size.conversationTabPhone' : 'size.conversationTab',
          fallback: mobile ? 40 : 48,
        );
  double get sourceListHeight => compactSticker
      ? 43
      : mobile
      ? tokens.size('size.conversationTabListPhone', fallback: 40)
      : 48;
  double get targetHeight => sourceTabHeight;
  double get effectiveListHeight => math.max(sourceListHeight, targetHeight);
  double get outerBottomBorder => mobile || compactSticker
      ? 1
      : tokens.size('stroke.conversationTabList', fallback: 0);
  Color get background =>
      tokens.colors[mobile
          ? 'layer-conversation-tabs-phone'
          : 'layer-conversation-tabs']!;
  Color get border => tokens.colors['line-conversation-header']!;
  double get gap => tokens.size('space.conversationTabGap', fallback: 20);
  EdgeInsets get listInset => EdgeInsets.symmetric(
    horizontal: mobile || compactSticker
        ? 16
        : tokens.size('space.conversationTabInline', fallback: 16),
    vertical: compactSticker
        ? (sourceListHeight - sourceTabHeight) / 2
        : tokens.size('space.conversationTabVertical', fallback: 0),
  );
  double get glyphSize => 14;
  double get glyphStroke => 1.5;
  Color get indicator => tokens.colors['primary-400']!;
}

class _ConversationTabControlRecipe extends RaftControlRecipe {
  const _ConversationTabControlRecipe(super.tokens, {required super.selected});
  @override
  bool get transformsOnInteraction => false;
  @override
  Color get background => Colors.transparent;
  // Active hover stays primary.
  @override
  Color backgroundFor({bool hovered = false}) => background;
  @override
  Color get foreground =>
      selected ? tokens.ink : tokens.colors['foreground-placeholder']!;
  @override
  Color foregroundFor({bool hovered = false}) =>
      selected || !hovered ? foreground : tokens.muted;
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
    size: 13,
    line: 19.5,
    weight: FontWeight.w500,
  ).copyWith(letterSpacing: -.065);
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
    if (widget.hideHeader || widget.tabs.length <= 1) {
      return const SizedBox.shrink();
    }
    final tokens = RaftTokens.of(context);
    final recipe = RaftConversationTabsRecipe(
      tokens,
      mobile:
          raftBreakpointWidth(context) < RaftLayoutMetrics.desktopBreakpoint,
      density: RaftDensityScope.of(context),
    );
    // Fixed chrome: text is bounded (RaftChrome) and a long press shows the
    // tab large (Large Content Viewer) once the bound hides growth.
    return RaftChrome(
      child: RaftLargeContentScope(child: _tabStrip(context, recipe)),
    );
  }

  Widget _tabStrip(BuildContext context, RaftConversationTabsRecipe recipe) {
    final grows = RaftScaled.grows(context);
    return RaftTapSlopHost(
      child: RaftStatusBarSource(
        color: recipe.background,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: recipe.background,
            // Desktop tabs have no rule (`border-b-0`); a zero-width
            // Flutter BorderSide would still paint a hairline.
            border: Border(
              bottom: recipe.outerBottomBorder == 0
                  ? BorderSide.none
                  : BorderSide(
                      color: recipe.border,
                      width: recipe.outerBottomBorder,
                    ),
            ),
          ),
          child: ConstrainedBox(
            // The strip is a minimum height: the tabs grow with their label.
            constraints: BoxConstraints(
              minHeight: recipe.effectiveListHeight,
              maxHeight: grows ? double.infinity : recipe.effectiveListHeight,
            ),
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
                      ],
                    ),
                  ),
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
    final grows = RaftScaled.grows(context);
    Widget control = Semantics(
      role: SemanticsRole.tab,
      label: tab.label,
      selected: selected,
      enabled: tab.enabled,
      focusable: tab.enabled,
      focused: focus.hasFocus,
      onTap: tab.enabled ? () => widget.onChanged(tab.id) : null,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: recipe.targetHeight,
            maxHeight: grows ? double.infinity : recipe.targetHeight,
          ),
          // The mounted panel selects its tab variant independently of the generic Tabs control.
          child: RaftTabButton(
            key: ValueKey('panel-tab-${tab.id.name}'),
            focusNode: focus,
            label: tab.label,
            variant: recipe.variant,
            selected: selected,
            height: recipe.targetHeight,
            growsWithText: grows,
            glyph: switch (tab.id) {
              RaftConversationTabId.chat => RaftGlyph.messageSquare,
              RaftConversationTabId.files => RaftGlyph.paperclip,
              RaftConversationTabId.tasks => null,
            },
            icon: tab.id == RaftConversationTabId.tasks
                ? (size, color, stroke) => _ConversationTaskGlyph(
                    size: size,
                    stroke: stroke,
                    color: color,
                  )
                : null,
            onPressed: tab.enabled ? () => widget.onChanged(tab.id) : null,
          ),
        ),
      ),
    );
    if (tab.enabled) {
      control = RaftLargeContentViewer(
        label: tab.label,
        onActivate: () => widget.onChanged(tab.id),
        iconBuilder: (context, size) => switch (tab.id) {
          RaftConversationTabId.chat => RaftIcon(
            RaftGlyph.messageSquare,
            size: size,
          ),
          RaftConversationTabId.files => RaftIcon(
            RaftGlyph.paperclip,
            size: size,
          ),
          RaftConversationTabId.tasks => _ConversationTaskGlyph(
            size: size,
            stroke: recipe.glyphStroke,
            color: IconTheme.of(context).color ?? recipe.tokens.ink,
          ),
        },
        child: control,
      );
    }
    if (RaftDensityScope.of(context) == RaftDensity.touch) {
      control = RaftTapSlopAnchor(
        minSize: const Size.square(RaftMetrics.touchTarget),
        child: control,
      );
    }
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
  Widget build(BuildContext context) => RaftIconViewport(
    size: size,
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
  double get gap => mobile ? 2 : 6;
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
          raftBreakpointWidth(context) < RaftLayoutMetrics.desktopBreakpoint,
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
    // raft-ui 0.95.3 `MessageListDateDivider`: `flex items-center gap-2 px-4
    // pt-[calc(24-4-lh/2)] pb-[calc(24-12-lh/2)]`, `font-mono text-mono-meta
    // text-foreground-hint whitespace-nowrap`, flex-1 hairline rules.
    final tokens = t.recipeTokens;
    final recipe = RaftMessageListRecipe.resolve(
      tokens: tokens,
      states: t.recipeStates(responsive: true),
    );
    final text = recipe.dateDividerChip.text(
      tokens,
      base: DefaultTextStyle.of(context).style,
    );
    return Semantics(
      header: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: recipe.dateDividerRoot.padding,
        child: RaftMessageRuleRow(
          gap: recipe.dateDividerRoot.columnGap ?? 8,
          ruleColor: t.colors['line-hairline']!,
          naturalWidth: raftMessageTextWidth(context, label, text),
          child: Text(
            label,
            style: text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
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
  Color get foreground => tokens.colors['foreground-composer-task']!;
  @override
  Color foregroundFor({bool hovered = false}) => foreground;
  @override
  TextStyle get textStyle => RaftTypography.body(
    tokens,
    size: tokens.size('type.composerTaskLabel.size', fallback: 14),
    line: tokens.size('type.composerTaskLabel.line', fallback: 20),
    weight: raftFontWeight(
      tokens.size('type.composerTaskLabel.weight', fallback: 600),
    ),
  );
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
    final native = t.option('checkbox.mark', or: 'fillCheck') == 'fillCheck';
    final face = t.size('size.composerTaskToggle', fallback: 32);
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
            minimumTargetSize: face,
            focusNode: focus,
            focusOnPointer: false,
            visualHeight: face,
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
                RaftCheckboxIndicator(
                  checked: widget.checked,
                  disabled: native && widget.onChanged == null,
                  size: t.size('size.composerTaskCheckbox', fallback: 20),
                  style: native
                      ? null
                      : RaftCheckboxIndicatorStyle(
                          fill: widget.checked
                              ? t.colors['layer-composer-task-checked']
                              : t.panel,
                          borderColor: t.colors['line-composer-task'],
                          markColor: t.colors['foreground-inverse'],
                          radius: 0,
                          borderWidth:
                              t.option('checkbox.mark', or: 'strokeCheck') ==
                                  'thickStroke'
                              ? 2
                              : 1,
                          // Both a57 optional appearances use the same mark.
                          markSize: 10,
                          markStrokeWidth: 4,
                        ),
                ),
                SizedBox(width: t.size('space.composerTaskGap', fallback: 8)),
                Text(widget.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
