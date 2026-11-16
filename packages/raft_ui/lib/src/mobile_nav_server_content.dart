part of 'mobile_navigation.dart';

// The parts of the server popover (raft-ui 0.95.3 mobile-nav-server:
// `MobileNavServerPopoverList`, `…Group`, `…Row`, `…Destinations`,
// `…Destination`, and the Popover's own separator).

RaftMobileNavServerRecipeStyle _serverRecipe(
  BuildContext context, {
  RaftRecipeStates? states,
}) {
  final t = RaftTokens.of(context);
  return RaftMobileNavServerRecipe.resolve(
    tokens: t.recipeTokens,
    states: states ?? t.recipeStates(),
  );
}

/// The Popover's `separator`: a hairline across the popover's full width.
class RaftMobileNavServerPopoverSeparator extends StatelessWidget {
  const RaftMobileNavServerPopoverSeparator({super.key});
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final separator = RaftPopoverRecipe.resolve(
      theme: t.recipeTheme,
      tokens: t.recipeTokens,
      states: t.recipeStates(),
    ).separator;
    return RaftRecipeBox(
      style: separator,
      tokens: t.recipeTokens,
      padding: EdgeInsets.zero,
      applyText: false,
      height: separator.height ?? separator.borderWidth.vertical,
    );
  }
}

/// Rows that always stay in view, such as the footer actions.
class RaftMobileNavServerPopoverGroup extends StatelessWidget {
  const RaftMobileNavServerPopoverGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => RaftRecipeBox(
    style: _serverRecipe(context).group,
    tokens: RaftTokens.of(context).recipeTokens,
    applyText: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// The server list: takes the room left in the popover and scrolls inside it,
/// never shorter than one whole two-line row, and opens scrolled to the
/// [RaftMobileNavServerPopoverRow] marked `current`, with no animation, until
/// people scroll or press in it themselves.
///
/// With [onReorder] a row drags: a finger holds it and then moves
/// (hold-then-move), a mouse drags it after 6px. [onReorder] reports the
/// indexes of `ReorderableListView.onReorderItem` (`newIndex` already counts
/// the removed row). Reordering by keyboard is not offered.
class RaftMobileNavServerPopoverList extends StatefulWidget {
  const RaftMobileNavServerPopoverList({
    super.key,
    required this.children,
    this.onReorder,
  });
  final List<Widget> children;
  final void Function(int oldIndex, int newIndex)? onReorder;
  @override
  State<RaftMobileNavServerPopoverList> createState() =>
      _RaftMobileNavServerPopoverListState();
}

class _RaftMobileNavServerPopoverListState
    extends State<RaftMobileNavServerPopoverList> {
  final controller = ScrollController();
  bool pinned = true, queued = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void release() => pinned = false;

  void scheduleShow() {
    if (queued || !pinned) return;
    queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      queued = false;
      if (mounted) showCurrent();
    });
  }

  /// `scrollToElement(list, current, "vertical", { block: "nearest", offset })`.
  void showCurrent() {
    if (!pinned || !controller.hasClients) return;
    final row = _ServerPopoverScope.maybeOf(context)?.currentRow;
    final box = row?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final pad = _serverRecipe(context).list.padding.bottom;
    final bounds = (Offset.zero & box.size).inflate(pad);
    final start = viewport.getOffsetToReveal(box, 0, rect: bounds).offset;
    final end = viewport.getOffsetToReveal(box, 1, rect: bounds).offset;
    final position = controller.position;
    final target = position.pixels > start
        ? start
        : position.pixels < end
        ? end
        : position.pixels;
    position.jumpTo(
      target.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = _serverRecipe(context).list;
    final handle = _ServerPopoverScope.maybeOf(context);
    final padding = slot.padding;
    final reorder = widget.onReorder;
    final Widget scroll = reorder == null
        ? SingleChildScrollView(
            controller: controller,
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          )
        : ReorderableList(
            controller: controller,
            padding: padding,
            shrinkWrap: true,
            itemCount: widget.children.length,
            onReorderItem: reorder,
            proxyDecorator: (child, _, _) => Opacity(opacity: .6, child: child),
            itemBuilder: (context, i) => _ReorderItem(
              key: ValueKey<Object>(('reorder', widget.children[i].key ?? i)),
              index: i,
              child: widget.children[i],
            ),
          );
    // Takes the room the column leaves it: a child of the popover's `Column`
    // (`mainAxisSize: MainAxisSize.min`).
    return Flexible(
      fit: FlexFit.loose,
      child: NotificationListener<ScrollStartNotification>(
        onNotification: (n) {
          if (n.dragDetails != null) release();
          return false;
        },
        child: Listener(
          onPointerDown: (_) => release(),
          onPointerSignal: (_) => release(),
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) release();
              return KeyEventResult.ignored;
            },
            child: _BudgetList(
              metrics: handle?.metrics,
              minHeight: slot.minHeight ?? 0,
              onSized: scheduleShow,
              child: scroll,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the list's one-row minimum and tells the popover its natural height
/// (see [_PopoverSizer]).
class _BudgetList extends SingleChildRenderObjectWidget {
  const _BudgetList({
    required this.metrics,
    required this.minHeight,
    required this.onSized,
    required super.child,
  });
  final _PopoverMetrics? metrics;
  final double minHeight;
  final VoidCallback onSized;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBudgetList(metrics, minHeight, onSized);
  @override
  void updateRenderObject(BuildContext context, _RenderBudgetList ro) => ro
    ..metrics = metrics
    ..minHeight = minHeight
    ..onSized = onSized;
}

class _RenderBudgetList extends RenderProxyBox {
  _RenderBudgetList(this.metrics, this._minHeight, this.onSized);
  _PopoverMetrics? metrics;
  VoidCallback onSized;
  double _minHeight;
  Size? _last;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final m = metrics;
    final room = constraints.maxHeight;
    child!.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: math.min(_minHeight, room),
        maxHeight: room,
      ),
      parentUsesSize: true,
    );
    size = child!.size;
    if (m != null) {
      m.hasList = true;
      m.min = _minHeight;
      if (!room.isFinite) m.natural = size.height;
    }
    if (_last != size) {
      _last = size;
      onSized();
    }
  }
}

/// A reorderable row: a finger holds and then moves, a mouse drags after 6px.
class _ReorderItem extends StatelessWidget {
  const _ReorderItem({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (e) =>
        SliverReorderableList.of(context).startItemDragReorder(
          index: index,
          event: e,
          recognizer: e.kind == PointerDeviceKind.touch
              ? (DelayedMultiDragGestureRecognizer(delay: _serverHold)
                  ..gestureSettings = const DeviceGestureSettings(
                    touchSlop: _serverHoldSlop,
                  ))
              : _MouseDistanceRecognizer(),
        ),
    child: child,
  );
}

// PointerSensor's distance 6 applies to a mouse too; Flutter's precise-pointer
// slop would start a drag after 1px.
class _MouseDistanceRecognizer extends MultiDragGestureRecognizer {
  _MouseDistanceRecognizer() : super(debugOwner: null);
  @override
  MultiDragPointerState createNewPointerState(PointerDownEvent event) =>
      _MouseDistanceState(event.position, event.kind, gestureSettings);
  @override
  String get debugDescription => 'Mobile nav server reorder';
}

class _MouseDistanceState extends MultiDragPointerState {
  _MouseDistanceState(super.initialPosition, super.kind, super.gestureSettings);
  @override
  void checkForResolutionAfterMove() {
    if (pendingDelta!.distance > 6) resolve(GestureDisposition.accepted);
  }

  @override
  void accepted(GestureMultiDragStartCallback starter) {
    starter(initialPosition);
  }
}

/// One row of the popover, at the option height (36 for one line; a second
/// line adds its own height): a 20px avatar or a 16px muted icon, the label
/// (truncates), an optional mono [description] under it, then [trailing]
/// (a check, a count). [current] marks the current server: bold, and the row
/// the list opens on and the focus lands on.
class RaftMobileNavServerPopoverRow extends StatefulWidget {
  const RaftMobileNavServerPopoverRow({
    super.key,
    this.leading,
    required this.label,
    this.description,
    this.trailing,
    this.current = false,
    this.enabled = true,
    this.onPressed,
  });
  final Widget? leading;
  final String label;
  final String? description;
  final Widget? trailing;
  final bool current, enabled;
  final VoidCallback? onPressed;
  @override
  State<RaftMobileNavServerPopoverRow> createState() =>
      _RaftMobileNavServerPopoverRowState();
}

class _RaftMobileNavServerPopoverRowState
    extends State<RaftMobileNavServerPopoverRow> {
  final focus = FocusNode(debugLabel: 'server row');

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _ServerPopoverScope.maybeOf(context);
    if (widget.current && handle != null) {
      handle.currentFocus = focus;
      handle.currentRow = context;
    }
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final pointer = RaftInteraction.of(context).hover;
    final label = raftText(context, widget.label);
    return Opacity(
      // `disabled:opacity-60`, which the app puts on a row it cannot press.
      opacity: widget.enabled ? 1 : .6,
      child: RaftInteractive(
        focusNode: focus,
        semanticLabel: widget.description == null
            ? label
            : '$label, ${widget.description}',
        selected: widget.current ? true : null,
        onPressed: widget.enabled ? widget.onPressed : null,
        builder: (context, state) {
          final r = _serverRecipe(
            context,
            states: t.recipeStates(
              hovered: state.hovered && pointer,
              pressed: state.pressed,
              // The focus the open logic gave the current row shows whatever
              // the input (Web: the focus-visible fill).
              focusVisible:
                  state.focusVisible ||
                  (widget.current &&
                      focus.hasFocus &&
                      (handle?.focusedByOpen ?? false)),
            ),
          );
          final leading = widget.leading;
          final muted = r.row.target('& > svg')?.color?.resolve(rt);
          final icon = r.row.target('& > svg:not([class*=\'size-\'])');
          final avatar = r.row.target(':is(& > *)[data-slot="avatar"]');
          return RaftRecipeBox(
            style: r.row,
            tokens: rt,
            child: Row(
              spacing: r.row.columnGap ?? 10,
              children: [
                if (leading != null)
                  leading is RaftIcon
                      ? RaftIcon(
                          leading.glyph,
                          size: icon?.width ?? 16,
                          color: muted,
                        )
                      : SizedBox.square(
                          dimension: avatar?.width ?? 20,
                          child: leading,
                        ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        // `aria-current:font-bold`
                        style: widget.current
                            ? const TextStyle(fontWeight: FontWeight.w700)
                            : null,
                      ),
                      if (widget.description != null)
                        Text(
                          widget.description!,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: r.rowDescription.text(rt),
                        ),
                    ],
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The server's own pages in equal cells, named for assistive technology.
/// Up to 4 sit side by side in one row; more than 4 take 3 columns, the last
/// row starting at the left.
class RaftMobileNavServerPopoverDestinations extends StatelessWidget {
  const RaftMobileNavServerPopoverDestinations({
    super.key,
    required this.children,
    this.semanticLabel,
  });
  final List<Widget> children;
  final String? semanticLabel;

  /// Past this many pages, the row becomes a grid of 3 columns.
  static const inOneRow = 4;
  @override
  Widget build(BuildContext context) {
    final slot = _serverRecipe(context).destinations;
    final columnGap = slot.columnGap ?? 4, rowGap = slot.rowGap ?? 4;
    final grid = children.length > inOneRow;
    final columns = grid ? 3 : math.max(1, children.length);
    Widget line(List<Widget> cells) => Row(
      spacing: columnGap,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++)
          Expanded(child: i < cells.length ? cells[i] : const SizedBox()),
      ],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel == null ? null : raftText(context, semanticLabel!),
      child: RaftRecipeBox(
        style: slot,
        tokens: RaftTokens.of(context).recipeTokens,
        applyText: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: rowGap,
          children: [
            for (var i = 0; i < children.length; i += columns)
              line(children.sublist(i, math.min(i + columns, children.length))),
          ],
        ),
      ),
    );
  }
}

/// One of the server's pages: a 20px muted icon over a footnote label that
/// truncates. [attention] is the accent pixel at the icon's top-right.
class RaftMobileNavServerPopoverDestination extends StatelessWidget {
  const RaftMobileNavServerPopoverDestination({
    super.key,
    required this.glyph,
    required this.label,
    this.attention = false,
    this.attentionKey,
    this.semanticLabel,
    this.onPressed,
  });
  final RaftGlyph glyph;
  final String label;
  final bool attention;

  /// Key of the accent pixel while [attention] is on.
  final Key? attentionKey;
  final String? semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final pointer = RaftInteraction.of(context).hover;
    final text = raftText(context, label);
    return RaftInteractive(
      semanticLabel: semanticLabel == null
          ? text
          : raftText(context, semanticLabel!),
      onPressed: onPressed,
      builder: (context, state) {
        final r = _serverRecipe(
          context,
          states: t.recipeStates(
            hovered: state.hovered && pointer,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
          ),
        );
        final svg = r.destination.target('& svg');
        final dot = r.destination.target(':is(& > *)[data-slot="status"]');
        final pad = r.destination.padding;
        return RaftRecipeBox(
          style: r.destination,
          tokens: rt,
          child: Stack(
            // Web `items-center`: icon and label sit on the cell's centre.
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: r.destination.rowGap ?? 4,
                children: [
                  RaftIcon(
                    glyph,
                    size: svg?.width ?? 20,
                    color: svg?.color?.resolve(rt),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      text,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (attention)
                // `top-1 left-[calc(50%+6px)]`: the box is centred on the
                // cell, so its left padding of 20 puts the 8px pixel's left
                // edge 6px right of the centre.
                Positioned(
                  top: (dot?.length('top') ?? 4) - pad.top,
                  left: -pad.left,
                  right: -pad.right,
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: RaftStatus(
                          key: attentionKey,
                          size: RaftStatusSize.sm,
                          variant: RaftStatusVariant.accent,
                        ),
                      ),
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
