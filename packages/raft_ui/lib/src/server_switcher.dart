import 'sidebar_text.dart';
import 'interaction.dart';
import 'tap_slop.dart';
import 'public_page_mark.dart';
import 'raft/button.dart';
import 'raft/avatar.dart';

import 'dart:math' as math;

import 'dismiss_scope.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_profile.dart';
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'viewport_breakpoints.dart';
import 'mobile_navigation.dart';
import 'recipe_surface.dart';
import 'status_bar.dart';
import 'rail_attention.dart';
import 'recipes/app_rail.g.dart';
import 'recipes/avatar.g.dart';
import 'recipes/badge.g.dart';
import 'recipes/context_menu.g.dart';
import 'recipes/popover.g.dart';
import 'recipes/recipe_runtime.dart';
import 'text_scaling.dart' show RaftChrome;
import 'page_tokens.dart';
import 'theme.dart';
import 'sized_image.dart';
import 'tooltip.dart' show RaftTooltip;

part 'server_switcher_top_bar.dart';

/// Accepted records and actions are supplied by the application, never the SDK.
@immutable
class RaftServerMenuRow {
  const RaftServerMenuRow({
    required this.id,
    required this.name,
    required this.slug,
    required this.onSelected,
    this.current = false,
    this.avatarUrl,
    this.onAuxiliary,
    this.activityUnreadCount,
    this.pushMuted = false,
  });
  final String id, name, slug;
  final String? avatarUrl;
  final VoidCallback onSelected;
  final VoidCallback? onAuxiliary;
  final bool current, pushMuted;

  /// Unknown Activity counts remain absent; legacy sidebar unread is unrelated.
  final int? activityUnreadCount;
}

enum RaftServerMenuActionTone { standard, invite }

/// Source's invitation action has a distinct Brutal hover color.
@immutable
class RaftServerMenuAction extends RaftMenuEntry {
  const RaftServerMenuAction({
    required super.label,
    super.glyph,
    super.onPressed,
    this.tone = RaftServerMenuActionTone.standard,
  });
  final RaftServerMenuActionTone tone;
}

/// ServerSwitcherMenu.tsx120–185/242–307/363–448: bounded list, pinned
/// footer, focus-on-open, plain Tab traversal, outside pointer and Escape.
/// The host owns membership, navigation, unread requests and order persistence.
class RaftServerSwitcher extends StatefulWidget {
  const RaftServerSwitcher({
    super.key,
    required this.controller,
    required this.workspaceName,
    required this.label,
    required this.rows,
    required this.actions,
    this.onReorder,
    this.mobile = false,
    this.topBar = false,
    this.headerActions = const [],
    this.attention = false,
    this.logo,
    this.workspaceAvatarUrl,
    this.publicPageLive = false,
  });

  /// The current server's public page is live: the mobile selector carries a
  /// globe after the name.
  final bool publicPageLive;

  /// The current workspace's resolved public avatar (rail trigger); the
  /// initial shows while absent.
  final String? workspaceAvatarUrl;

  /// Replaces the rail trigger's visual (the public server rail draws its own
  /// black logo block); the trigger still toggles the menu.
  final Widget? logo;

  /// LeftRail `hasOtherServerUnread`: the rail item attention dot on the
  /// workspace avatar.
  final bool attention;
  final RaftMenuController controller;
  final String workspaceName, label;
  final List<RaftServerMenuRow> rows;
  final List<RaftMenuEntry> actions;
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Places the existing menu below the browser workspace trigger.
  final bool topBar;
  final bool mobile;
  final List<Widget> headerActions;
  @override
  State<RaftServerSwitcher> createState() => _RaftServerSwitcherState();
}

class _RaftServerSwitcherState extends State<RaftServerSwitcher> {
  final portal = OverlayPortalController();
  final anchor = GlobalKey();
  final triggerFocus = FocusNode();
  final menuFocus = FocusNode(skipTraversal: true);
  int revision = 0;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  @override
  void didUpdateWidget(RaftServerSwitcher old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(changed);
      widget.controller.addListener(changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) changed();
      });
    }
  }

  void changed() {
    ++revision;
    if (widget.controller.isOpen) {
      portal.show();
      final ticket = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ticket == revision && widget.controller.isOpen) {
          menuFocus.requestFocus();
        }
      });
    } else {
      // Source removal leaves body focus. Do not restore the trigger or an
      // unrelated textarea that was focused before opening this menu.
      menuFocus.unfocus();
      portal.hide();
    }
    if (mounted) setState(() {});
  }

  void activateAction(VoidCallback? action) {
    if (action == null || !widget.controller.isOpen) return;
    widget.controller.close();
    action();
  }

  @override
  void dispose() {
    ++revision;
    widget.controller.removeListener(changed);
    triggerFocus.dispose();
    menuFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final size = MediaQuery.sizeOf(context);
    // A rail on the window's right opens its menu toward the content.
    final onRight = RaftRailEdgeScope.onRightOf(context);
    return TapRegion(
      groupId: this,
      onTapOutside: (event) {
        final box = anchor.currentContext?.findRenderObject() as RenderBox?;
        // The bar owns the full 48px touch target around its 36px trigger.
        if (widget.topBar &&
            box != null &&
            RaftDensityScope.of(context) == RaftDensity.touch) {
          final rect = (box.localToGlobal(Offset.zero) & box.size).inflate(6);
          if (rect.contains(event.position)) return;
        }
        widget.controller.close();
      },
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) {
          final box = anchor.currentContext?.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return const SizedBox.shrink();
          final rect = box.localToGlobal(Offset.zero) & box.size;
          return RaftBackDismiss(
            onDismiss: widget.controller.close,
            child: CustomSingleChildLayout(
              delegate: _ServerMenuPlacement(
                // AppRailRoot's CSS right border is part of its border box;
                // AppRailHeader's positioned containing block excludes it.
                widget.topBar
                    ? Offset(rect.left, rect.bottom + 8)
                    : widget.mobile
                    ? Offset(8, rect.bottom - (1) + 4)
                    : onRight
                    ? Offset(rect.left + (0) - 8, rect.top + 4)
                    : Offset(rect.right - (0) + 8, rect.top + 4),
                mobileWidth: widget.mobile ? size.width - 16 : null,
                horizontalPadding: widget.topBar ? 8 : null,
                leftOfAnchor: !widget.mobile && !widget.topBar && onRight,
              ),
              child: TapRegion(
                groupId: this,
                child: Focus(
                  focusNode: menuFocus,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      widget.controller.close();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: RaftServerMenuPanel(
                    width: widget.mobile ? size.width - 16 : 256,
                    rows: widget.rows,
                    actions: widget.actions,
                    onActivate: activateAction,
                    onReorder: widget.onReorder,
                  ),
                ),
              ),
            ),
          );
        },
        child: SizedBox(
          key: anchor,
          height: widget.topBar
              ? 36
              : RaftLayoutMetrics.shellHeaderHeight(t, size.height),
          child: widget.topBar
              ? _TopBarServerTrigger(
                  rows: widget.rows,
                  workspaceName: widget.workspaceName,
                  avatarUrl: widget.workspaceAvatarUrl,
                  publicPageLive: widget.publicPageLive,
                  attention: widget.attention,
                  focusNode: triggerFocus,
                  open: widget.controller.isOpen,
                  onPressed: () => widget.controller.isOpen
                      ? widget.controller.close()
                      : widget.controller.open(),
                  onReorder: widget.onReorder,
                )
              : widget.mobile
              ? RaftMobileRootHeader(
                  workspace: true,
                  leading: RaftMobileServerSelector(
                    key: const Key('mobile-server-selector'),
                    label: widget.workspaceName,
                    attention: widget.attention,
                    publicPageLive: widget.publicPageLive,
                    attentionLabel: raftText(
                      context,
                      'Other servers have unread messages',
                    ),
                    focusNode: triggerFocus,
                    onPressed: () => widget.controller.isOpen
                        ? widget.controller.close()
                        : widget.controller.open(),
                  ),
                  actions: widget.headerActions,
                )
              : DecoratedBox(
                  // AppRailHeader `border-b-2 border-black` (Brutal): the
                  // border sits inside the 62px box, the avatar centres in 60.
                  decoration: BoxDecoration(),
                  child: Center(
                    child: RaftInteractive(
                      key: const Key('rail-workspace'),
                      semanticLabel: widget.label,
                      tooltip: widget.workspaceName,
                      selected: widget.controller.isOpen,
                      focusNode: triggerFocus,
                      onPressed: () => widget.controller.isOpen
                          ? widget.controller.close()
                          : widget.controller.open(),
                      builder: (context, state) {
                        if (widget.logo != null) return widget.logo!;
                        final slot = RaftAppRailRecipe.resolve(
                          theme: t.recipeTheme,
                          tokens: t.recipeTokens,
                          states: t.recipeStates(
                            hovered: state.hovered,
                            pressed: state.pressed,
                            focusVisible: state.focusVisible,
                            extra: [
                              if (widget.controller.isOpen)
                                'data-selected=true',
                            ],
                          ),
                        ).item;
                        final extent = size.height <= 600 ? 36.0 : 40.0;
                        final compact = size.height <= 600;
                        final avatarExtent = t.size(
                          widget.controller.isOpen
                              ? compact
                                    ? 'size.avatar.workspaceActiveCompact'
                                    : 'size.avatar.workspaceActive'
                              : compact
                              ? 'size.avatar.workspaceCompact'
                              : 'size.avatar.workspace',
                          fallback: extent - 4,
                        );
                        return RaftRecipeBox(
                          style: slot,
                          tokens: t.recipeTokens,
                          width: extent,
                          height: extent,
                          padding: EdgeInsets.zero,
                          child: Center(
                            child: SizedBox.square(
                              dimension: avatarExtent,
                              child: Stack(
                                clipBehavior: Clip.none,
                                fit: StackFit.expand,
                                children: [
                                  _ServerAvatar(
                                    name: widget.workspaceName,
                                    avatarUrl: widget.workspaceAvatarUrl,
                                    size: avatarExtent,
                                    initialSize: 14,
                                  ),
                                  if (widget.attention)
                                    const RaftRailAttention(
                                      child: SizedBox.shrink(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ServerMenuPlacement extends SingleChildLayoutDelegate {
  const _ServerMenuPlacement(
    this.anchored, {
    this.mobileWidth,
    this.horizontalPadding,
    this.leftOfAnchor = false,
  });
  final Offset anchored;
  final double? mobileWidth;

  /// ServerSwitcherMenu.tsx:297 uses Popover collisionPadding={8}; the
  /// top-bar trigger may reach either viewport edge (including in RTL).
  final double? horizontalPadding;

  /// [anchored] is the menu's right edge, not its left.
  final bool leftOfAnchor;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: mobileWidth ?? 0,
        maxWidth: math.min(
          mobileWidth ?? 256,
          math.max(0, constraints.maxWidth - 2 * (horizontalPadding ?? 0)),
        ),
        maxHeight: math.max(0, constraints.maxHeight - 16),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // computeServerSwitcherLayout.ts27–43 caps first, then shifts only up.
    final overflow = anchored.dy + childSize.height - (size.height - 8);
    final shift = overflow > 0
        ? math.min(overflow, math.max(0, anchored.dy - 8))
        : 0.0;
    final x = leftOfAnchor ? anchored.dx - childSize.width : anchored.dx;
    final padding = horizontalPadding;
    return Offset(
      padding == null
          ? x
          : x.clamp(
              padding,
              math.max(padding, size.width - childSize.width - padding),
            ),
      anchored.dy - shift,
    );
  }

  @override
  bool shouldRelayout(_ServerMenuPlacement old) =>
      old.anchored != anchored ||
      old.mobileWidth != mobileWidth ||
      old.horizontalPadding != horizontalPadding ||
      old.leftOfAnchor != leftOfAnchor;
}

/// Public panel makes every server-menu state previewable without an API.
class RaftServerMenuPanel extends StatelessWidget {
  const RaftServerMenuPanel({
    super.key,
    required this.rows,
    required this.actions,
    required this.onActivate,
    this.onReorder,
    this.width = 256,
  });
  final List<RaftServerMenuRow> rows;
  final List<RaftMenuEntry> actions;
  final ValueChanged<VoidCallback?> onActivate;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final double width;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftPopoverRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).content;
    final panel = RaftSlotStyle(
      {
        ...style.properties,
        'background-color': const CssVar(
          '--color-layer-panel',
          null,
          'layerPanel',
        ),
        for (final side in ['top', 'right', 'bottom', 'left']) ...{
          'border-$side-width': const CssNum(1, 'px'),
          'border-$side-style': const CssKeyword('solid'),
          'border-$side-color': const CssVar(
            '--color-line-muted',
            null,
            'lineMuted',
          ),
        },
      },
      style.targets,
      style.classes,
      style.tokens,
    );
    final separator = RaftContextMenuRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).separator;
    return RaftRecipeBox(
      key: const Key('server-switcher-menu'),
      style: panel,
      tokens: t.recipeTokens,
      width: width,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: ReorderableListView.builder(
              key: const Key('server-menu-list'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              itemCount: rows.length,
              onReorderItem: onReorder ?? (_, _) {},
              proxyDecorator: (child, _, animation) =>
                  Opacity(opacity: .6, child: child),
              itemBuilder: (context, i) => _ServerRow(
                key: ValueKey('server-menu-row-${rows[i].id}'),
                row: rows[i],
                index: i,
                reorderEnabled: onReorder != null,
                onActivate: onActivate,
              ),
            ),
          ),
          Padding(
            // Source's -mx-1 extends into a card with overflow:hidden. Its
            // visible span is the full inner width; only vertical margins
            // affect layout. Flutter Padding cannot express negative margins.
            padding: EdgeInsets.only(
              top: separator.margin.top,
              bottom: separator.margin.bottom,
            ),
            child: RaftRecipeBox(
              style: separator,
              tokens: t.recipeTokens,
              padding: EdgeInsets.zero,
              height: separator.height ?? separator.borderWidth.vertical,
            ),
          ),
          for (final entry in actions)
            _ServerAction(entry: entry, onActivate: onActivate),
        ],
      ),
    );
  }
}

/// App.tsx615–621: the URI already identifies an accepted server while the
/// old workspace is retired. This is presentation only, never a server record.
class RaftServerResolutionBody extends StatelessWidget {
  const RaftServerResolutionBody({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // The splash is a page of its own (Material + page text style), never bare
    // text: outside a Material Flutter paints the debug fallback style (yellow
    // double underline). `safe-top` pads the status bar like the Web div.
    // Web v1.21.23 `bg-layer-sidebar` + `text-headline text-foreground-muted`;
    // the pre-theme looks keep the canvas and the strong 20/28 label
    // (layer-standalone, type.splash.*, foreground-splash).
    final canvas = t.standaloneSurface;
    return RaftStatusBarHost(
      fallback: canvas,
      expand: true,
      child: Material(
        color: canvas,
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: t.headingFont,
            color: t.semantic.foreground,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            child: Center(
              child: Text(raftText(context, label), style: t.splashLabel()),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerRow extends StatelessWidget {
  const _ServerRow({
    super.key,
    required this.row,
    required this.index,
    required this.reorderEnabled,
    required this.onActivate,
  });
  final RaftServerMenuRow row;
  final int index;
  final bool reorderEnabled;
  final ValueChanged<VoidCallback?> onActivate;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Listener(
      onPointerDown: (e) {
        if (e.buttons == kMiddleMouseButton) onActivate(row.onAuxiliary);
      },
      child: RaftInteractive(
        semanticLabel: row.name,
        onPressed: () {
          final keys = HardwareKeyboard.instance;
          if (keys.isControlPressed ||
              keys.isMetaPressed ||
              keys.isShiftPressed ||
              keys.isAltPressed) {
            onActivate(row.onAuxiliary);
          } else {
            onActivate(row.onSelected);
          }
        },
        builder: (context, state) {
          final active = state.hovered || state.focusVisible;
          final foreground = active ? t.colors['primary-strong']! : t.strong;
          return Container(
            height: 48,
            color: active ? t.colors['primary-soft']! : Colors.transparent,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Opacity(
                  opacity: row.current ? 1 : 0,
                  child: RaftIcon(RaftGlyph.check, size: 14, color: foreground),
                ),
                const SizedBox(width: 8),
                _ServerAvatar(name: row.name, avatarUrl: row.avatarUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RaftTypography.body(
                          t,
                          size: 14,
                          line: 20,
                          weight: row.current
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: foreground,
                        ),
                      ),
                      Text(
                        '/${row.slug}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RaftTypography.mono(
                          t,
                          color: active ? foreground : t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!row.current && (row.activityUnreadCount ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 4),
                    child: _ServerUnreadCount(
                      count: row.activityUnreadCount!,
                      muted: row.pushMuted,
                    ),
                  ),
                if (reorderEnabled)
                  _ServerDragHandle(
                    key: ValueKey('server-menu-reorder-${row.id}'),
                    index: index,
                    label: 'Reorder ${row.name}',
                    color: foreground,
                  )
                else
                  const SizedBox(width: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServerUnreadCount extends StatelessWidget {
  const _ServerUnreadCount({required this.count, required this.muted});
  final int count;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context), label = count > 99 ? '99+' : '$count';
    if (muted) {
      return RaftTooltip(
        message: 'Notifications muted',
        child: Text(
          label,
          style: RaftTypography.mono(
            t,
            size: 10,
            line: 10,
            color: t.muted,
          ).copyWith(fontWeight: FontWeight.w500),
        ),
      );
    }
    final slot = RaftBadgeRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      variant: RaftBadgeRecipeVariant.accent,
    ).root;
    final style = RaftSlotStyle(
      {
        ...slot.properties,
        'height': const CssKeyword('auto'),
        'min-width': const CssNum(0, 'px'),
        'line-height': const CssNum(1),
        'padding-left': const CssNum(6, 'px'),
        'padding-right': const CssNum(6, 'px'),
        'padding-top': const CssNum(2, 'px'),
        'padding-bottom': const CssNum(2, 'px'),
      },
      slot.targets,
      slot.classes,
      slot.tokens,
    );
    return RaftRecipeBox(
      style: style,
      tokens: t.recipeTokens,
      child: Text(label),
    );
  }
}

class _ServerDragHandle extends StatelessWidget {
  const _ServerDragHandle({
    super.key,
    required this.index,
    required this.label,
    required this.color,
  });
  final int index;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Focus(
      child: Listener(
        onPointerDown: (e) => SliverReorderableList.of(context)
            .startItemDragReorder(
              index: index,
              event: e,
              recognizer: e.kind == PointerDeviceKind.touch
                  ? (DelayedMultiDragGestureRecognizer(
                        delay: const Duration(milliseconds: 500),
                      )
                      ..gestureSettings = const DeviceGestureSettings(
                        touchSlop: 10,
                      ))
                  : _SourceServerPointerRecognizer(),
            ),
        child: SizedBox(
          width: 24,
          height: 48,
          child: Center(
            child: RaftIcon(RaftGlyph.gripVertical, size: 14, color: color),
          ),
        ),
      ),
    ),
  );
}

// PointerSensor's distance6 applies to mouse too. Flutter's ordinary precise
// pointer slop ignores touchSlop and would begin dragging after only 1px.
class _SourceServerPointerRecognizer extends MultiDragGestureRecognizer {
  _SourceServerPointerRecognizer() : super(debugOwner: null);
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _SourceServerPointerState(event.position, event.kind, gestureSettings);
  @override
  String get debugDescription => 'Source server reorder';
}

class _SourceServerPointerState extends MultiDragPointerState {
  _SourceServerPointerState(
    super.initialPosition,
    super.kind,
    super.gestureSettings,
  );
  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > 6) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

class _ServerAvatar extends StatelessWidget {
  const _ServerAvatar({
    required this.name,
    this.avatarUrl,
    this.size = 32,
    this.initialSize = 12,
  });
  final String name;
  final String? avatarUrl;
  final double size, initialSize;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    // AvatarSlot server: Avatar `human` fallback ink (Elegant: muted at 70%).
    final rt = t.recipeTokens;
    final fallbackInk = RaftAvatarRecipe.resolve(
      theme: t.recipeTheme,
      type_: RaftAvatarRecipeType.human,
      size: RaftAvatarRecipeSize.xl,
      tokens: rt,
    ).fallback.color?.resolve(rt);
    final initial = Center(
      child: RaftSidebarText(
        name.trim().isEmpty ? 'S' : name.trim().characters.first.toUpperCase(),
        // Initials fill a fixed-size avatar: they grow with the text size only
        // up to the chrome bound.
        textScaler: RaftChrome.boundedScalerOf(context),
        style:
            RaftTypography.body(
              t,
              size: t.size(
                'type.avatarServerInitial.size',
                fallback: initialSize,
              ),
              line: t.size('type.avatarServerInitial.line', fallback: 16),
              weight: FontWeight.w700,
              color:
                  (t.colors['foreground-avatar-server'] ??
                          fallbackInk ??
                          t.strong)
                      .withValues(
                        alpha: t.size(
                          'opacity.avatarServerInitial',
                          fallback: 1,
                        ),
                      ),
            ).copyWith(
              letterSpacing:
                  t.size('type.avatarServerInitial.tracking', fallback: 0) *
                  t.size(
                    'type.avatarServerInitial.size',
                    fallback: initialSize,
                  ),
            ),
      ),
    );
    return RaftAvatarSlot(
      name: name,
      slot: RaftAvatarSlotContext.surfaceList,
      agent: false,
      server: true,
      sizeOverride: size,
      content: avatarUrl == null
          ? initial
          : RaftSizedImage.avatar(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}

class _ServerAction extends StatelessWidget {
  const _ServerAction({required this.entry, required this.onActivate});
  final RaftMenuEntry entry;
  final ValueChanged<VoidCallback?> onActivate;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      semanticLabel: entry.label,
      onPressed: entry.onPressed == null
          ? null
          : () => onActivate(entry.onPressed),
      builder: (context, state) {
        final active = state.hovered || state.focusVisible;
        final ink = active ? t.colors['primary-strong']! : t.strong;
        return Container(
          height: MediaQuery.sizeOf(context).height <= 600 ? 28 : 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: active ? t.colors['primary-soft']! : null,
          child: Row(
            children: [
              if (entry.glyph != null) ...[
                RaftIcon(entry.glyph!, size: 14, color: ink),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.label ?? '',
                  style: RaftTypography.body(
                    t,
                    size: 14,
                    line: 20,
                    weight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
