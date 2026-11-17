// One column of the side area (Web v1.24 `ChannelSideArea.tsx` SideColumn,
// StackSeam, ColumnResizeHandle): the stacked sections with a draggable seam
// between each two, the width handle on the column's left edge, and, where
// the sections don't fit one under the other, one at a time under a switch.
// Beside the chat, floating over it or covering it.
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_side_card.dart';
import 'channel_side_layout.dart';
import 'channel_side_store.dart';

/// Each stacked section is at least this high (Web `CARD_MIN_HEIGHT`).
const channelSideSectionMinHeight = 160.0;
const _keyboardStep = 16.0, _keyboardStepLarge = 64.0;

/// Where a stacked section stands in its column: [collapsed], and the fold
/// itself ([onCollapsedChanged] null where the section doesn't fold: alone,
/// one at a time, or not Tasks / Files).
typedef ChannelSideFold = ({
  bool collapsed,
  ValueChanged<bool>? onCollapsedChanged,
});

typedef ChannelSideCardBuilder = Widget Function(
  BuildContext context,
  ChannelSideSection section,
  ChannelSideFold fold,
);

/// With [sections] stacked, one under the other when their column is at least
/// this high, else one at a time (Web `sideCardsStackMinHeight`).
double channelSideStackMinHeight(int sections) =>
    sections * channelSideSectionMinHeight + (sections - 1);

bool channelSideOneAtATime(ChannelSideMode mode, double height, int sections) =>
    sections > 1 &&
    (mode == ChannelSideMode.overlay ||
        height < channelSideStackMinHeight(sections));

/// A column's decoration (Web `columnClass`): the card surface and a 1px seam
/// on its left, floating also on its bottom, raised by the float shadow.
BoxDecoration channelSideColumnDecoration(RaftTokens t, ChannelSideMode mode) {
  final seam = BorderSide(color: t.colors['line-seam']!);
  return BoxDecoration(
    color: t.colors['layer-canvas'],
    border: switch (mode) {
      ChannelSideMode.beside => Border(left: seam),
      ChannelSideMode.float => Border(left: seam, bottom: seam),
      ChannelSideMode.overlay => null,
    },
    boxShadow: mode == ChannelSideMode.float
        ? [
            for (final layer in t.shadowLayers('shadow.float').reversed)
              if (!layer.inset) layer.toBoxShadow(),
          ]
        : null,
  );
}

class ChannelSideColumnView extends StatefulWidget {
  const ChannelSideColumnView({
    super.key,
    required this.store,
    required this.mode,
    required this.sections,
    required this.titles,
    required this.cardOf,
    this.resize,
  });

  final ChannelSideStore store;
  final ChannelSideMode mode;

  /// Its open sections, top to bottom.
  final List<ChannelSideSection> sections;
  final Map<ChannelSideSection, String> titles;
  final ChannelSideCardBuilder cardOf;

  /// Beside the chat: how its width drags. Null: not resizable.
  final ChannelSideResize? resize;

  @override
  State<ChannelSideColumnView> createState() => _ChannelSideColumnViewState();
}

/// A column's width as the area shows it and the room it may grow into.
class ChannelSideResize {
  const ChannelSideResize({
    required this.column,
    required this.width,
    required this.maxWidth,
    required this.onResize,
    required this.label,
  });
  final int column;
  final double width, maxWidth;

  /// [commit]: the drag ended (or a key pressed): save.
  final void Function(double width, bool commit) onResize;
  final String label;
}

class _ChannelSideColumnViewState extends State<ChannelSideColumnView> {
  /// The shares a drag shows until it ends (then the store keeps them).
  List<double>? live;
  double? _dragTop;

  ChannelSideStore get store => widget.store;

  ChannelSideCard? _card(ChannelSideSection s) => switch (s) {
    ChannelSideSection.tasks => ChannelSideCard.tasks,
    ChannelSideSection.files => ChannelSideCard.files,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final touch = RaftInteraction.of(context).touch;
    return DecoratedBox(
      decoration: channelSideColumnDecoration(t, widget.mode),
      child: LayoutBuilder(
        builder: (context, box) {
          final height = box.maxHeight;
          final sections = widget.sections;
          final oneAtATime = channelSideOneAtATime(
            widget.mode,
            height,
            sections.length,
          );
          final active = oneAtATime
              ? _active(sections)
              : null; // the one showing where only one fits
          final shown = active == null ? sections : [active];
          final switchHeight = oneAtATime
              ? (touch ? 48.0 : _head(context))
              : 0.0;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    if (oneAtATime)
                      _switch(context, t, sections, active!, switchHeight),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, stackBox) => _stack(
                          context,
                          t,
                          shown,
                          sections,
                          stackBox.maxHeight,
                          folds: !oneAtATime && sections.length > 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.resize != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: touch ? RaftSpace.x6 : RaftSpace.x3,
                  child: _SeamHandle(
                    key: Key(
                      'channel-side-column-resize-${widget.resize!.column}',
                    ),
                    vertical: true,
                    label: widget.resize!.label,
                    value: widget.resize!.width.round(),
                    onDragStart: () => widget.resize!.width,
                    onDrag: (start, delta) => widget.resize!.onResize(
                      math.min(widget.resize!.maxWidth, start - delta),
                      false,
                    ),
                    onDragEnd: (start, delta) => widget.resize!.onResize(
                      math.min(widget.resize!.maxWidth, start - delta),
                      true,
                    ),
                    onKey: (key, large) {
                      final step = large ? _keyboardStepLarge : _keyboardStep;
                      final r = widget.resize!;
                      final next = key == LogicalKeyboardKey.arrowLeft
                          ? r.width + step
                          : key == LogicalKeyboardKey.arrowRight
                          ? r.width - step
                          : null;
                      if (next == null) return false;
                      r.onResize(math.min(r.maxWidth, next), true);
                      return true;
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _head(BuildContext context) => RaftLayoutMetrics.shellHeaderHeight(
    RaftTokens.of(context),
    MediaQuery.sizeOf(context).height,
  );

  /// The store's focus order knows the web page as `app`.
  String _focusKey(ChannelSideSection s) =>
      s == ChannelSideSection.artifact ? 'app' : s.name;

  ChannelSideSection _active(List<ChannelSideSection> sections) {
    final key = {for (final s in sections) _focusKey(s): s};
    return key[store.activeCard(key.keys)] ?? sections.first;
  }

  Widget _switch(
    BuildContext context,
    RaftTokens t,
    List<ChannelSideSection> sections,
    ChannelSideSection active,
    double height,
  ) {
    return Container(
      key: const Key('channel-side-switch'),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x4),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-seam']!)),
      ),
      child: RaftTabsList<ChannelSideSection>(
        label: raftText(context, 'Show Tasks or files'),
        value: active,
        onChanged: (s) => store.focus(_focusKey(s)),
        tabs: [
          for (final s in sections)
            RaftTabItem(
              value: s,
              label: widget.titles[s] ?? s.name,
              glyph: switch (s) {
                ChannelSideSection.tasks => RaftGlyph.listTodo,
                ChannelSideSection.files => RaftGlyph.paperclip,
                _ => RaftGlyph.globe,
              },
              itemKey: Key('channel-side-switch-${s.name}'),
            ),
        ],
      ),
    );
  }

  Widget _stack(
    BuildContext context,
    RaftTokens t,
    List<ChannelSideSection> shown,
    List<ChannelSideSection> all,
    double height, {
    required bool folds,
  }) {
    bool folded(ChannelSideSection s) {
      final card = _card(s);
      return folds && card != null && store.collapsed(card);
    }

    final shares = live ?? store.splitShares(shown);
    final head = _head(context);
    // The open sections split what the folded heads and the 1px seams leave.
    var fixed = 0.0, openTotal = 0.0;
    for (var i = 0; i < shown.length; i++) {
      if (i > 0 && !folded(shown[i - 1])) fixed += 1;
      if (folded(shown[i])) {
        fixed += head;
      } else {
        openTotal += shares[i];
      }
    }
    final room = math.max(1.0, height - fixed);
    final perPixel = (openTotal == 0 ? 1 : openTotal) / room;
    final tops = <double>[], heights = <double>[];
    var y = 0.0;
    for (var i = 0; i < shown.length; i++) {
      if (i > 0 && !folded(shown[i - 1])) y += 1;
      final h = folded(shown[i])
          ? head
          : openTotal == 0
          ? room
          : room * shares[i] / openTotal;
      tops.add(y);
      heights.add(h);
      y += h;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final s in all)
          Positioned(
            key: ValueKey(s),
            left: 0,
            right: 0,
            top: shown.contains(s) ? tops[shown.indexOf(s)] : 0,
            height: shown.contains(s) ? heights[shown.indexOf(s)] : height,
            child: Offstage(
              offstage: !shown.contains(s),
              child: widget.cardOf(context, s, (
                collapsed: folded(s),
                onCollapsedChanged: folds && _card(s) != null
                    ? (v) => store.setCollapsed(_card(s)!, v)
                    : null,
              )),
            ),
          ),
        for (var i = 0; i + 1 < shown.length; i++)
          if (!folded(shown[i]))
            _seam(
              context,
              t,
              shown,
              i,
              tops[i] + heights[i],
              splittable: !folded(shown[i + 1]),
              perPixel: perPixel,
              shares: shares,
              height: height,
            ),
      ],
    );
  }

  /// The seam below section [i]: a 1px line; where both neighbours are open
  /// a 12px handle on it drags their split.
  Widget _seam(
    BuildContext context,
    RaftTokens t,
    List<ChannelSideSection> shown,
    int i,
    double at, {
    required bool splittable,
    required double perPixel,
    required List<double> shares,
    required double height,
  }) {
    final touch = RaftInteraction.of(context).touch;
    final line = Positioned(
      left: 0,
      right: 0,
      top: at,
      height: RaftSpace.hairline,
      child: ColoredBox(color: t.colors['line-seam']!),
    );
    if (!splittable) return line;
    // What the upper section takes the lower gives: the pair keeps its total,
    // each at least 160px.
    List<double> withTop(List<double> base, double top) {
      final pair = base[i] + base[i + 1];
      final min = math.min(pair * .45, channelSideSectionMinHeight * perPixel);
      final out = [...base];
      out[i] = math.max(min, math.min(pair - min, top));
      out[i + 1] = pair - out[i];
      return out;
    }

    final share = shares[i] / (shares[i] + shares[i + 1]);
    final handle = Positioned(
      left: 0,
      right: 0,
      top: at - (touch ? RaftSpace.x3 : RaftSpace.x1_5),
      height: touch ? RaftSpace.x6 : RaftSpace.x3,
      child: _SeamHandle(
        key: Key('channel-side-split-$i'),
        vertical: false,
        label: raftText(context, 'Resize Tasks and files'),
        value: (share * 100).round(),
        onDragStart: () {
          _dragTop = shares[i];
          return 0;
        },
        onDrag: (_, delta) => setState(
          () => live = withTop(shares, _dragTop! + delta * perPixel),
        ),
        onDragEnd: (_, delta) {
          final next = withTop(shares, _dragTop! + delta * perPixel);
          setState(() => live = null);
          store.saveSplit(shown, next);
        },
        onKey: (key, large) {
          final step = (large ? _keyboardStepLarge : _keyboardStep) * perPixel;
          final top = key == LogicalKeyboardKey.arrowDown
              ? shares[i] + step
              : key == LogicalKeyboardKey.arrowUp
              ? shares[i] - step
              : key == LogicalKeyboardKey.home
              ? 0.0
              : key == LogicalKeyboardKey.end
              ? shares[i] + shares[i + 1]
              : null;
          if (top == null) return false;
          store.saveSplit(shown, withTop(shares, top));
          return true;
        },
      ),
    );
    return Positioned.fill(
      key: ValueKey('seam-$i'),
      child: Stack(clipBehavior: Clip.none, children: [line, handle]),
    );
  }
}

/// A seam you can drag, or move with the arrow keys (DS Resizable on a seam):
/// nothing at rest, a 1px `foreground-muted` line on hover and drag, a 2px
/// `foreground` line on keyboard focus, a 12px hit area (24px by touch).
class _SeamHandle extends StatefulWidget {
  const _SeamHandle({
    super.key,
    required this.vertical,
    required this.label,
    required this.value,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
    required this.onKey,
  });

  /// A vertical bar (it resizes a width, col-resize) or a horizontal one.
  final bool vertical;
  final String label;
  final int value;

  /// Returns what the drag measures from (the width now).
  final double Function() onDragStart;
  final void Function(double start, double delta) onDrag, onDragEnd;

  /// Arrow, Home, End keys; true when it handled the key.
  final bool Function(LogicalKeyboardKey key, bool large) onKey;

  @override
  State<_SeamHandle> createState() => _SeamHandleState();
}

class _SeamHandleState extends State<_SeamHandle> {
  bool hovered = false, dragging = false, focused = false;
  double _start = 0, _total = 0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final lit = hovered || dragging;
    final thickness = focused ? 2.0 : (lit ? 1.0 : 0.0);
    final color = focused
        ? t.colors['foreground']!
        : t.colors['foreground-muted']!;
    final v = widget.vertical;
    return Semantics(
      label: widget.label,
      value: '${widget.value}',
      slider: true,
      child: Focus(
        onFocusChange: (f) => setState(
          () => focused =
              f &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional,
        ),
        onKeyEvent: (node, event) {
          if (event is KeyUpEvent) return KeyEventResult.ignored;
          return widget.onKey(
                event.logicalKey,
                HardwareKeyboard.instance.isShiftPressed,
              )
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        },
        child: RaftHoverRegion(
          cursor: v
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
          onEnter: (_) => setState(() => hovered = true),
          onExit: (_) => setState(() => hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: v ? (_) => _begin() : null,
            onHorizontalDragUpdate: v ? (d) => _move(d.delta.dx) : null,
            onHorizontalDragEnd: v ? (_) => _end() : null,
            onHorizontalDragCancel: v ? _end : null,
            onVerticalDragStart: v ? null : (_) => _begin(),
            onVerticalDragUpdate: v ? null : (d) => _move(d.delta.dy),
            onVerticalDragEnd: v ? null : (_) => _end(),
            onVerticalDragCancel: v ? null : _end,
            child: Align(
              alignment: v ? Alignment.centerLeft : Alignment.center,
              child: SizedBox(
                width: v ? thickness : double.infinity,
                height: v ? double.infinity : thickness,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _begin() {
    _start = widget.onDragStart();
    _total = 0;
    setState(() => dragging = true);
  }

  void _move(double delta) {
    _total += delta;
    widget.onDrag(_start, _total);
  }

  void _end() {
    if (!dragging) return;
    setState(() => dragging = false);
    widget.onDragEnd(_start, _total);
  }
}
