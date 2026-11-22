part of 'server_switcher.dart';

class _DesktopWorkspaceButtonMetrics {
  const _DesktopWorkspaceButtonMetrics(this.boxWidth, this.textStyle);

  factory _DesktopWorkspaceButtonMetrics.of(BuildContext context) {
    final t = RaftTokens.of(context);
    final tokens = t.recipeTokens;
    final root = RaftButtonRecipe.resolveProps(
      {'variant': RaftButtonVariant.onFrame.css, 'size': RaftButtonSize.md.css},
      states: t.recipeStates(responsive: true),
      tokens: tokens,
    )['root']!;
    final stroke = t.themeValues?.geometry['stroke.control'];
    final border = root.borderWidth;
    return _DesktopWorkspaceButtonMetrics(
      root.padding.horizontal +
          (border.left > 0
              ? raftControlBorderPx(context, stroke ?? border.left)
              : 0) +
          (border.right > 0
              ? raftControlBorderPx(context, stroke ?? border.right)
              : 0),
      RaftControlTypography.of(
        context,
        root
            .text(tokens, base: DefaultTextStyle.of(context).style)
            .copyWith(fontFamilyFallback: t.fontFallback, locale: t.textLocale),
      ),
    );
  }

  static const labelGap = RaftSpace.x2;
  static const chevronGap = RaftSpace.x1;
  static const chevronSize = 16.0;
  static const globe = RaftPublicPageGlobe(live: true);

  final double boxWidth;
  final TextStyle textStyle;

  double chromeWidth({required bool hasLabel}) =>
      boxWidth +
      RaftAvatarSize.sm.extent +
      (hasLabel ? labelGap : 0) +
      chevronGap +
      chevronSize;

  double minimumWidth({required bool hasName, required bool publicPageLive}) =>
      chromeWidth(hasLabel: hasName || publicPageLive) +
      (publicPageLive ? globe.size + (hasName ? labelGap : 0) : 0);
}

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
  static const stripGap = RaftSpace.x1;
  double get dragStride => dragOrigin!.width + stripGap;
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
      dropTo = cancel ? 0 : (to! - from!) * dragStride;
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
    if (index == picked) return (over! - picked!) * dragStride;
    if (index > picked! && index <= over!) return -dragStride;
    if (index < picked! && index >= over!) return dragStride;
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

  Widget avatar(
    RaftServerMenuRow row, {
    bool hiddenUnread = false,
    RaftAvatarSize size = RaftAvatarSize.xs,
  }) {
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
            size: size.text,
            line: size.text,
            weight: FontWeight.w700,
            color: foreground,
          ).copyWith(letterSpacing: -.11),
        ),
      ),
    );
    return SizedBox.square(
      dimension: size.extent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RaftStickerAvatar(
            size: size,
            badgeOutlineColor: t.colors['layer-workspace-rail'],
            child: row.avatarUrl == null
                ? fallback
                : RaftSizedImage.avatar(
                    row.avatarUrl!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, _, _) => fallback,
                  ),
          ),
          if ((!row.current && (row.activityUnreadCount ?? 0) > 0) ||
              hiddenUnread)
            Positioned(
              right: -size.badge / 2,
              top: -size.badge / 2,
              child: RaftAvatarBadge(
                size: size,
                variant: RaftStatusVariant.accent,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final desktop = t.desktop
        ? _DesktopWorkspaceButtonMetrics.of(context)
        : null;
    final hasName = widget.workspaceName.isNotEmpty;
    final hasLabel = hasName || widget.publicPageLive;
    const globe = _DesktopWorkspaceButtonMetrics.globe;
    const labelGap = _DesktopWorkspaceButtonMetrics.labelGap;
    const chevronGap = _DesktopWorkspaceButtonMetrics.chevronGap;
    return LayoutBuilder(
      builder: (context, box) {
        final showFullButton =
            desktop != null &&
            box.maxWidth >=
                desktop.minimumWidth(
                  hasName: hasName,
                  publicPageLive: widget.publicPageLive,
                );
        final currentAvatarSize = showFullButton
            ? RaftAvatarSize.sm
            : RaftAvatarSize.xs;
        final style =
            desktop?.textStyle ??
            RaftTypography.body(t, size: 15, line: 20, weight: FontWeight.w700);
        double measure(String text) {
          if (text.isEmpty) return 0;
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: RaftChrome.boundedScalerOf(context),
            locale: t.textLocale,
          )..layout();
          final width = painter.width.ceilToDouble();
          painter.dispose();
          return width;
        }

        double labelWidth(String name, bool publicPageLive) =>
            measure(name) +
            (desktop != null && publicPageLive
                ? globe.size + (name.isNotEmpty ? labelGap : 0)
                : 0);

        final currentLabelWidth = labelWidth(
          widget.workspaceName,
          widget.publicPageLive,
        );
        final widest = widget.rows.fold(
          currentLabelWidth,
          (max, row) => math.max(max, labelWidth(row.name, row.publicPageLive)),
        );
        // useStripLayout shares one label cap between the title and globe.
        // Reserve the same slot regardless of which workspace is selected.
        const stripLabelCap = 120.0, singleLabelCap = 160.0;
        final nameSlot =
            math.min(stripLabelCap, widest) +
            (desktop?.chromeWidth(hasLabel: widest > 0) ?? 46);
        const stripLead = RaftSpace.x2;
        const extraDividerWidth = stripGap + RaftSpace.hairline;
        final button = RaftButtonRecipe.resolve(
          variant: RaftButtonRecipeVariant.ghost,
          size: RaftButtonRecipeSize.iconMd,
          states: t.recipeStates(responsive: true),
          tokens: t.recipeTokens,
        ).root;
        final stripButtonWidth = button.width ?? button.height ?? 36;
        final stripStride = stripButtonWidth + stripGap;
        // The desktop layout already reserves the gap before History.
        final historyGap = desktop == null ? RaftSpace.x2 : 0.0;
        final free = math.max(
          0.0,
          box.maxWidth -
              nameSlot -
              stripLead -
              historyGap +
              stripGap -
              extraDividerWidth,
        );
        final fit = math.min(widget.rows.length, (free / stripStride).floor());
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
        final currentRow = current < 0 ? null : widget.rows[current];
        final label = Text(
          widget.workspaceName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final name = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (desktop != null || n == 0) ...[
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
                hiddenUnread: n == 0 && hiddenUnread,
                size: currentAvatarSize,
              ),
              // CSS flex gap exists only between children; an unloaded
              // workspace has an avatar but no name to separate from it.
              if (hasName || desktop != null && hasLabel)
                const SizedBox(width: labelGap),
            ],
            if (hasName || desktop != null && hasLabel)
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: n > 0 ? stripLabelCap : singleLabelCap,
                  ),
                  child: desktop != null && widget.publicPageLive
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasName) ...[
                              Flexible(child: label),
                              const SizedBox(width: labelGap),
                            ],
                            globe,
                          ],
                        )
                      : label,
                ),
              ),
            if (desktop == null && widget.publicPageLive)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: labelGap),
                child: globe,
              ),
            if (n > 0 || showFullButton) ...[
              SizedBox(width: t.desktop ? chevronGap : labelGap),
              RaftIcon(
                RaftGlyph.chevronDown,
                size: _DesktopWorkspaceButtonMetrics.chevronSize,
                color: t.desktop ? null : t.colors['foreground-on-frame-muted'],
              ),
            ],
          ],
        );
        return OverlayPortal(
          overlayLocation: OverlayChildLocation.rootOverlay,
          controller: dragPortal,
          overlayChildBuilder: floatingAvatar,
          child: Row(
            mainAxisSize: t.desktop ? MainAxisSize.min : MainAxisSize.max,
            children: [
              SizedBox(
                width: n > 0
                    ? nameSlot
                    : math.min(
                        box.maxWidth,
                        math.min(singleLabelCap, currentLabelWidth) +
                            (showFullButton
                                ? desktop.chromeWidth(hasLabel: hasLabel)
                                : 49),
                      ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
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
                  padding: const EdgeInsetsDirectional.only(start: stripLead),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var slot = 0; slot < indices.length; slot++) ...[
                        if (slot > 0)
                          if (outside && slot == indices.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: stripGap,
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
                            const SizedBox(width: stripGap),
                        stripButton(
                          indices[slot],
                          n - (outside ? 1 : 0),
                          width: stripButtonWidth,
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
              if (!t.desktop) const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget stripButton(
    int index,
    int count, {
    required double width,
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
        offset: Offset(shiftFor(index) / width, 0),
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
              dragDx = dx.clamp(
                -index * dragStride,
                (count - 1 - index) * dragStride,
              );
              moveOver(
                (index + (dragDx / dragStride).round()).clamp(0, count - 1),
              );
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
                  dragDx = (over! - picked!) * dragStride;
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
                        ? .4
                        : !dragging && dragRow?.id == row.id
                        ? 0
                        : 1,
                    child: touchTarget(
                      RaftButton(
                        key: ValueKey('topbar-workspace-${row.id}'),
                        label: '',
                        semanticLabel: row.name,
                        // Keep the tooltip node mounted while a pointer is down.
                        tooltip: dragging
                            ? ''
                            : row.shortcutLabel == null
                            ? row.name
                            : '${row.name}  ${row.shortcutLabel}',
                        leading: avatar(row, hiddenUnread: hiddenUnread),
                        gap: 0,
                        uiVariant: RaftButtonVariant.ghost,
                        uiSize: RaftButtonSize.iconMd,
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
                      left: (width - 14) / 2,
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
