part of 'server_switcher.dart';

/// AppTopBar/useStripLayout: reserve the longest name while avatars show;
/// avatar capacity and ordering depend on the list and available width.
class _TopBarServerTrigger extends StatefulWidget {
  const _TopBarServerTrigger({
    required this.rows,
    required this.workspaceName,
    required this.avatarUrl,
    required this.publicPageLive,
    required this.attention,
    required this.focusNode,
    required this.open,
    required this.onPressed,
    this.onReorder,
  });
  final List<RaftServerMenuRow> rows;
  final String workspaceName;
  final String? avatarUrl;
  final bool publicPageLive, attention, open;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final void Function(int, int)? onReorder;
  @override
  State<_TopBarServerTrigger> createState() => _TopBarServerTriggerState();
}

class _TopBarServerTriggerState extends State<_TopBarServerTrigger>
    with SingleTickerProviderStateMixin {
  Offset? start;
  int? picked, over;
  bool dragging = false, suppressClick = false, keyboardDrag = false;

  // WorkspaceStrip / dnd-kit defaults: ease200 neighbours, ease250 drop.
  static const ease = Cubic(.25, .1, .25, 1);
  final dragPortal = OverlayPortalController();
  final anchors = <String, GlobalKey>{};
  bool escapeListening = false;
  late final AnimationController drop;

  @override
  void initState() {
    super.initState();
    drop =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) clearOverlay();
        });
  }

  Rect? dragOrigin;
  RaftServerMenuRow? dragRow;
  double dragDx = 0, dropFrom = 0, dropTo = 0;
  String announcement = '';
  bool get reducedMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    stopEscapeListener();
    drop.dispose();
    super.dispose();
  }

  void clearOverlay() {
    drop.stop();
    dragPortal.hide();
    setState(() {
      dragRow = null;
      dragOrigin = null;
    });
  }

  void beginDrag(int index) {
    drop.stop();
    final row = widget.rows[index];
    final box =
        anchors[row.id]!.currentContext!.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    dragOrigin = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    dragRow = row;
    announcement = raftFormat(context, 'Picked up {name}.', {'name': row.name});
    dragDx = 0;
    dragPortal.show();
    if (!escapeListening) {
      // dnd-kit PointerSensor listens on document, independent of item focus.
      HardwareKeyboard.instance.addHandler(cancelDragOnEscape);
      escapeListening = true;
    }
  }

  bool cancelDragOnEscape(KeyEvent event) {
    if (!dragging ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape)
      return false;
    finish(cancel: true, pointerStillDown: !keyboardDrag);
    return true;
  }

  void stopEscapeListener() {
    if (!escapeListening) return;
    HardwareKeyboard.instance.removeHandler(cancelDragOnEscape);
    escapeListening = false;
  }

  void clearReleaseClickNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) suppressClick = false;
    });
  }

  void finish({bool cancel = false, bool pointerStillDown = false}) {
    if (!mounted) return;
    stopEscapeListener();
    final from = picked, to = over;
    final moved = dragging;
    if (moved) {
      dropFrom = dragDx;
      dropTo = cancel ? 0 : ((to! - from!) * 36).toDouble();
      announcement = raftFormat(
        context,
        cancel
            ? 'Moving {name} cancelled.'
            : '{name} dropped at the position of {target}.',
        {'name': dragRow!.name, 'target': widget.rows[to!].name},
      );
    }
    setState(() {
      start = null;
      picked = null;
      over = null;
      dragging = false;
      keyboardDrag = false;
    });
    if (!moved) return;
    suppressClick = true;
    // Escape may cancel after6px, before Flutter's tap slop is exceeded.
    // Consume that pointer's later release; a new pointer down still resets it.
    if (!pointerStillDown) clearReleaseClickNextFrame();
    if (!cancel && from != null && to != null && from != to) {
      widget.onReorder?.call(from, to);
    }
    if (reducedMotion || dropFrom == dropTo) {
      clearOverlay();
    } else {
      drop.forward(from: 0);
    }
  }

  void moveOver(int target) {
    if (over == target) return;
    over = target;
    announcement = raftFormat(context, '{name} is over {target}.', {
      'name': dragRow!.name,
      'target': widget.rows[target].name,
    });
  }

  double shiftFor(int index) {
    if (!dragging) return 0;
    if (index == picked) return ((over! - picked!) * 36).toDouble();
    if (index > picked! && index <= over!) return -36;
    if (index < picked! && index >= over!) return 36;
    return 0;
  }

  Widget floatingAvatar(BuildContext context) {
    final rect = dragOrigin;
    final row = dragRow;
    if (rect == null || row == null) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return AnimatedBuilder(
      animation: drop,
      builder: (context, child) {
        final dx = dragging
            ? dragDx
            : dropFrom + (dropTo - dropFrom) * ease.transform(drop.value);
        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                duration: keyboardDrag && !reducedMotion
                    ? const Duration(milliseconds: 250)
                    : Duration.zero,
                curve: ease,
                tween: Tween(end: dx),
                builder: (_, value, child) =>
                    Transform.translate(offset: Offset(value, 0), child: child),
                child: Transform.scale(
                  scale: 1.1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        t.size('radius.sticker', fallback: 4),
                      ),
                      boxShadow: t.themeShadows.lg.paintOrder,
                    ),
                    child: SizedBox.expand(
                      key: const Key('topbar-workspace-drag-overlay'),
                      child: Center(child: avatar(row)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget touchTarget(Widget child) => RaftInteraction.of(context).touch
      ? RaftTapSlopAnchor(
          minSize: const Size.square(RaftMetrics.touchTarget),
          child: child,
        )
      : child;

  Widget avatar(RaftServerMenuRow row, {bool hiddenUnread = false}) {
    final t = RaftTokens.of(context);
    final initial = row.name.trim().isEmpty
        ? 'S'
        : row.name.trim().characters.first.toUpperCase();
    final ink = t.colors['layer-avatar-server']!,
        foreground = t.colors['foreground-avatar-server']!;
    final fallback = ColoredBox(
      color: ink,
      child: Center(
        child: Text(
          initial,
          style: RaftTypography.body(
            t,
            size: 11,
            line: 11,
            weight: FontWeight.w700,
            color: foreground,
          ).copyWith(letterSpacing: -.11),
        ),
      ),
    );
    return SizedBox.square(
      dimension: 19,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RaftStickerAvatar(
            size: RaftAvatarSize.xs,
            badgeOutlineColor: t.colors['layer-workspace-rail'],
            child: row.avatarUrl == null
                ? fallback
                : RaftSizedImage.avatar(
                    row.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          ),
          if ((!row.current && (row.activityUnreadCount ?? 0) > 0) ||
              hiddenUnread)
            Positioned(
              right: -3.5,
              top: -3.5,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: t.colors['layer-rail-attention'],
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: t.colors['line-rail-attention']!),
                  boxShadow: [BoxShadow(color: t.canvas, spreadRadius: 1)],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final style = RaftTypography.body(
          t,
          size: 15,
          line: 20,
          weight: FontWeight.w700,
        );
        double measure(String text) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: RaftChrome.boundedScalerOf(context),
          )..layout();
          final width = painter.width.ceilToDouble();
          painter.dispose();
          return width;
        }

        final widest = widget.rows.fold(
          measure(widget.workspaceName),
          (double max, row) => math.max(max, measure(row.name)),
        );
        // Both used 1px borders + px10 + gap8 + Chevron16. The end region
        // reserves its pl8; stripFreePx subtracts lead8, adds gap4, reserves line5.
        final nameSlot = math.min(120.0, widest) + 46;
        final free = math.max(0.0, box.maxWidth - nameSlot - 8 - 8 + 4 - 5);
        final fit = math.min(widget.rows.length, (free / 36).floor());
        final n = fit >= 2 ? fit : 0;
        final current = widget.rows.indexWhere((row) => row.current);
        final outside = n > 0 && current >= n;
        final indices = n == 0
            ? <int>[]
            : [
                for (var i = 0; i < n - (outside ? 1 : 0); i++) i,
                if (outside) current,
              ];
        final hiddenUnread = widget.rows.asMap().entries.any(
          (e) =>
              !e.value.current &&
              !indices.contains(e.key) &&
              (e.value.activityUnreadCount ?? 0) > 0,
        );
        final currentRow = widget.rows.where((r) => r.current).firstOrNull;
        final name = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n == 0) ...[
              avatar(
                currentRow ??
                    RaftServerMenuRow(
                      id: '',
                      name: widget.workspaceName,
                      slug: '',
                      current: true,
                      avatarUrl: widget.avatarUrl,
                      onSelected: widget.onPressed,
                    ),
                hiddenUnread: hiddenUnread,
              ),
              // CSS flex gap exists only between children; an unloaded
              // workspace has an avatar but no name to separate from it.
              if (widget.workspaceName.isNotEmpty) const SizedBox(width: 8),
            ],
            if (widget.workspaceName.isNotEmpty)
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: n > 0 ? 120 : 160),
                  child: Text(
                    widget.workspaceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            if (widget.publicPageLive)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: RaftPublicPageGlobe(live: true),
              ),
            if (n > 0) ...[
              const SizedBox(width: 8),
              RaftIcon(
                RaftGlyph.chevronDown,
                size: 16,
                color: t.colors['foreground-on-frame-muted'],
              ),
            ],
          ],
        );
        return OverlayPortal(
          overlayLocation: OverlayChildLocation.rootOverlay,
          controller: dragPortal,
          overlayChildBuilder: floatingAvatar,
          child: Row(
            children: [
              SizedBox(
                width: n > 0
                    ? nameSlot
                    : math.min(
                        box.maxWidth,
                        math.min(160.0, measure(widget.workspaceName)) + 49,
                      ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.open
                          ? t.colors['fill-frame-pressed']
                          : null,
                      borderRadius: BorderRadius.circular(t.radius),
                    ),
                    child: touchTarget(
                      RaftButton(
                        key: const Key('topbar-workspace'),
                        label: '',
                        semanticLabel: widget.workspaceName,
                        leading: name,
                        gap: 0,
                        focusNode: widget.focusNode,
                        uiVariant: RaftButtonVariant.onFrame,
                        uiSize: RaftButtonSize.md,
                        onPressed: widget.onPressed,
                      ),
                    ),
                  ),
                ),
              ),
              if (n > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var slot = 0; slot < indices.length; slot++) ...[
                        if (slot > 0)
                          if (outside && slot == indices.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: SizedBox(
                                width: 1,
                                height: 16,
                                child: ColoredBox(
                                  color: t.colors['line-seam']!,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 4),
                        stripButton(
                          indices[slot],
                          n - (outside ? 1 : 0),
                          hiddenUnread:
                              widget.rows[indices[slot]].current &&
                              hiddenUnread,
                          draggable: !(outside && slot == indices.length - 1),
                        ),
                      ],
                    ],
                  ),
                ),
              Semantics(
                container: true,
                liveRegion: true,
                label: announcement,
                child: const SizedBox.shrink(),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget stripButton(
    int index,
    int count, {
    required bool hiddenUnread,
    required bool draggable,
  }) {
    final row = widget.rows[index];
    final sortable = draggable && count > 1 && widget.onReorder != null;
    return KeyedSubtree(
      key: anchors.putIfAbsent(row.id, () => GlobalKey()),
      child: AnimatedSlide(
        duration: dragging && !reducedMotion
            ? const Duration(milliseconds: 200)
            : Duration.zero,
        curve: ease,
        offset: Offset(shiftFor(index) / 32, 0),
        child: Listener(
          key: ValueKey('topbar-strip-item-${row.id}'),
          onPointerDown: sortable
              ? (e) {
                  if (dragRow != null) clearOverlay();
                  start = e.position;
                  picked = index;
                  over = index;
                  suppressClick = false;
                }
              : null,
          onPointerMove: (e) {
            if (start == null ||
                picked != index ||
                keyboardDrag ||
                widget.onReorder == null)
              return;
            final dx = e.position.dx - start!.dx;
            // PointerSensor activates before restrictToHorizontalAxis applies.
            if (!dragging && (e.position - start!).distance <= 6) return;
            if (!dragging) beginDrag(index);
            setState(() {
              dragging = true;
              dragDx = dx.clamp(-index * 36.0, (count - 1 - index) * 36.0);
              moveOver((index + (dragDx / 36).round()).clamp(0, count - 1));
            });
          },
          onPointerUp: (_) {
            if (picked == index && !keyboardDrag) {
              finish();
            } else if (suppressClick && mounted) {
              clearReleaseClickNextFrame();
            }
          },
          onPointerCancel: (_) {
            if (picked == index && !keyboardDrag) finish(cancel: true);
          },
          child: Focus(
            onKeyEvent: (_, event) {
              if (!sortable || event is! KeyDownEvent)
                return KeyEventResult.ignored;
              if (dragging && event.logicalKey == LogicalKeyboardKey.escape) {
                finish(cancel: true, pointerStillDown: !keyboardDrag);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.space) {
                if (keyboardDrag) {
                  finish();
                } else {
                  beginDrag(index);
                  setState(() {
                    keyboardDrag = true;
                    dragging = true;
                    picked = index;
                    over = index;
                  });
                }
                return KeyEventResult.handled;
              }
              if (keyboardDrag &&
                  (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowRight)) {
                setState(() {
                  moveOver(
                    (over! +
                            (event.logicalKey == LogicalKeyboardKey.arrowRight
                                ? 1
                                : -1))
                        .clamp(0, count - 1),
                  );
                  dragDx = ((over! - picked!) * 36).toDouble();
                });
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Semantics(
              selected: row.current,
              hint: sortable
                  ? raftText(
                      context,
                      'Press Space to pick up the server, arrow keys to move it, Space to drop, Escape to cancel. Press Enter to switch to it.',
                    )
                  : null,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: dragging && picked == index
                        ? .3
                        : !dragging && dragRow?.id == row.id
                        ? 0
                        : 1,
                    child: touchTarget(
                      RaftButton(
                        key: ValueKey('topbar-workspace-${row.id}'),
                        label: '',
                        semanticLabel: row.name,
                        // Keep the tooltip node mounted while a pointer is down.
                        tooltip: dragging ? '' : row.name,
                        leading: avatar(row, hiddenUnread: hiddenUnread),
                        gap: 0,
                        uiVariant: RaftButtonVariant.ghost,
                        uiSize: RaftButtonSize.iconSm,
                        foreground: RaftTokens.of(context)
                            .colors['foreground-on-frame'],
                        onPressed: () {
                          if (!dragging && !suppressClick && !row.current)
                            row.onSelected();
                        },
                      ),
                    ),
                  ),
                  if (row.current && !(dragging && picked == index))
                    Positioned(
                      bottom: -6,
                      left: 9,
                      child: Container(
                        width: 14,
                        height: 3,
                        decoration: BoxDecoration(
                          color: RaftTokens.of(context).colors['foreground'],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
