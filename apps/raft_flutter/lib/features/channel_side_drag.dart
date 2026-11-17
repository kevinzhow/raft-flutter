// Moving a section among the side columns (Web v1.24 `sideSectionDrag.tsx`):
// a pointer picks a section up by the grip on its head, the keyboard by the
// same grip (Space picks up, the arrows go through the places, Space drops,
// Escape cancels); each step is announced by the section's name.
//
// The section stays where it is, faded, and a compact copy of its head (icon
// and title) follows the pointer. The place under the pointer is a dashed area:
// a strip on a column's edge for a new column, a band in a column for a place
// among its sections; a new column the window can't hold shows why beside the
// pointer. Nothing moves until the drop, which saves the layout once
// (ChannelSideStore.moveSection). Escape, or a release over no place, cancels.
//
// Only where Web allows it: beside the chat (not floating or covering), with a
// pointer (not by touch), and more than one section open. The area keeps
// [ChannelSideDragController.enabled] current.
//
// Where the sections' boxes are is read from the tree when the drag starts, by
// the card's GlobalKey (also what lets a card keep its body, scroll and focus
// when a move puts it in another column).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_side_drop_targets.dart';
import 'channel_side_layout.dart';
import 'channel_side_store.dart';

/// The pointer must move this far from the press to pick a section up.
const channelSideDragSlop = 4.0;

/// A keyboard drag sets the copy this far in from the place's corner, so the
/// place's dashed outline still shows (Web `DRAG_KEYBOARD_OFFSET_PX`).
const _keyboardLift = 6.0;
const _proxyMaxWidth = 240.0, _proxyMinHeight = 40.0, _hintMaxWidth = 320.0;

// The grip (Web `top-1.5 h-6 w-24`) and its bar (`top-[2px] h-1 w-14`).
const _gripWidth = 96.0, _gripHeight = 24.0, _gripTop = RaftSpace.x1_5;
const _barWidth = 56.0, _barHeight = RaftSpace.x1, _barTop = RaftSpace.half;

enum ChannelSideDragVia { pointer, keyboard }

/// A section's name as the drag says it (Web `SECTION_TITLE`).
String channelSideDragTitle(BuildContext context, ChannelSideSection s) =>
    switch (s) {
      ChannelSideSection.tasks => raftText(context, 'Tasks'),
      ChannelSideSection.files => raftText(context, 'Files'),
      ChannelSideSection.artifact => raftText(context, 'Artifact'),
      _ => s.name,
    };

/// "A, B and C" the way `Intl.ListFormat` writes a conjunction.
String channelSideNames(BuildContext context, List<String> names) {
  final zh = Localizations.localeOf(context).languageCode == 'zh';
  if (names.length < 2) return names.join();
  final head = names.sublist(0, names.length - 1);
  return zh
      ? '${head.join('、')}和${names.last}'
      : names.length == 2
      ? '${names[0]} and ${names[1]}'
      : '${head.join(', ')}, and ${names.last}';
}

typedef _Head = ({BuildContext context, FocusNode focus});

class ChannelSideDragController extends ChangeNotifier {
  /// One per section: the card keeps its element (body, scroll, focus) when a
  /// move puts it in another column.
  final cardKeys = <ChannelSideSection, GlobalKey>{
    for (final s in ChannelSideSection.values)
      s: GlobalKey(debugLabel: 'channel side card ${s.name}'),
  };

  /// The section held now; for the faded card and the grips.
  final active = ValueNotifier<ChannelSideSection?>(null);

  final _heads = <ChannelSideSection, _Head>{};

  ChannelSideStore? _store;
  BuildContext? _area;
  bool _enabled = false;
  bool Function(ChannelSideLayout moved) _fits = (_) => false;

  ChannelSideSection? get section => active.value;
  ChannelSideDragVia? via;
  List<ChannelSideDropTarget> targets = const [];
  ChannelSideDropTarget? target;

  /// The pointer in the area's coordinates; where a keyboard drag's copy
  /// stands is [lift].
  Offset pointer = Offset.zero;
  Offset grab = Offset.zero;
  Offset? lift;

  /// The grip a keyboard drop put the focus back on: its tooltip stays shut
  /// until the focus leaves it.
  ChannelSideSection? quietGrip;

  BuildContext? _at;
  bool _disposed = false;
  bool get enabled => _enabled;
  bool get dragging => section != null;

  /// What the area says, every build: [fits] tells whether the window holds a
  /// layout; [enabled] where sections may be moved at all.
  void sync({
    required ChannelSideStore store,
    required BuildContext area,
    required bool enabled,
    required bool Function(ChannelSideLayout moved) fits,
  }) {
    _store = store;
    _area = area;
    _fits = fits;
    _enabled = enabled;
    if (!enabled && dragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) => end(false));
    }
  }

  void register(ChannelSideSection s, BuildContext context, FocusNode focus) =>
      _heads[s] = (context: context, focus: focus);

  void unregister(ChannelSideSection s, BuildContext context) {
    if (_heads[s]?.context == context) _heads.remove(s);
    // The card went while it was held (closed, or another channel).
    if (section == s) {
      WidgetsBinding.instance.addPostFrameCallback((_) => end(false));
    }
  }

  /// A card's own element, and its fade while it is the one held.
  Widget card(ChannelSideSection s, Widget child) => KeyedSubtree(
    key: cardKeys[s],
    child: ValueListenableBuilder<ChannelSideSection?>(
      valueListenable: active,
      child: child,
      builder: (context, held, child) =>
          Opacity(opacity: held == s ? .4 : 1, child: child),
    ),
  );

  // ---- the places ----------------------------------------------------------

  /// Picks [s] up. [at] is its head's context (the words come from it);
  /// [global] the pointer for a pointer drag. False where there is nowhere to
  /// go.
  bool begin(
    ChannelSideSection s,
    BuildContext at,
    ChannelSideDragVia how, {
    Offset? global,
  }) {
    final store = _store;
    final area = _area?.findRenderObject();
    if (!_enabled || dragging || store == null) return false;
    if (area is! RenderBox || !area.attached || !area.hasSize) return false;
    final head = _heads[s]?.context.findRenderObject();
    final headBox = head is RenderBox && head.hasSize ? head : null;
    final found = _measure(area, headBox?.size.height ?? 56);
    final places = channelSideDropTargets(
      layout: store.layout,
      section: s,
      columns: found.columns,
      chat: found.chat,
      head: found.head,
      fits: _fits,
    );
    if (places.isEmpty) return false;
    _at = at;
    via = how;
    targets = places;
    target = null;
    pointer = global == null ? Offset.zero : area.globalToLocal(global);
    grab = headBox != null && global != null
        ? headBox.globalToLocal(global)
        : const Offset(12, 20);
    lift = headBox == null
        ? null
        : MatrixUtils.transformPoint(headBox.getTransformTo(area), Offset.zero);
    quietGrip = null;
    HardwareKeyboard.instance.addHandler(_onKey);
    active.value = s;
    final picked = raftFormat(at, 'Picked up {name}.', {
      'name': channelSideDragTitle(at, s),
    });
    // An edge too narrow for a new column isn't offered to the keyboard: it
    // hears why once, here.
    _say(
      how == ChannelSideDragVia.keyboard && places.any((t) => !t.fits)
          ? '$picked ${raftText(at, 'The window is too narrow for another column.')}'
          : picked,
    );
    notifyListeners();
    return true;
  }

  ({List<ChannelSideColumnBox> columns, Rect? chat, double head}) _measure(
    RenderBox area,
    double head,
  ) {
    final columns =
        <
          int,
          ({Rect rect, List<({ChannelSideSection section, Rect rect})> boxes})
        >{};
    final byIndex = RegExp(r'^channel-side-column-(\d+)$');
    Rect local(RenderBox b) =>
        MatrixUtils.transformRect(b.getTransformTo(area), Offset.zero & b.size);
    for (final entry in cardKeys.entries) {
      final context = entry.value.currentContext;
      final box = context?.findRenderObject();
      if (context == null || box is! RenderBox || !box.attached) continue;
      if (!box.hasSize || box.size.height <= 0) continue;
      int? found;
      RenderBox? holder;
      var hidden = false;
      context.visitAncestorElements((e) {
        final widget = e.widget;
        if (widget is Offstage && widget.offstage) {
          hidden = true;
          return false;
        }
        final key = widget.key;
        final match = key is ValueKey<String>
            ? byIndex.firstMatch(key.value)
            : null;
        if (match == null) return true;
        found = int.parse(match[1]!);
        final render = e.renderObject;
        holder = render is RenderBox ? render : null;
        return false;
      });
      final index = found, column = holder;
      if (hidden || index == null || column == null || !column.hasSize) {
        continue;
      }
      columns
          .putIfAbsent(index, () => (rect: local(column), boxes: []))
          .boxes
          .add((section: entry.key, rect: local(box)));
    }
    final list = <ChannelSideColumnBox>[
      for (final e in columns.entries)
        (
          index: e.key,
          rect: e.value.rect,
          boxes: [...e.value.boxes]
            ..sort((a, b) => a.rect.top.compareTo(b.rect.top)),
        ),
    ];
    final left = list.isEmpty
        ? null
        : list.map((c) => c.rect.left).reduce((a, b) => a < b ? a : b);
    return (
      columns: list,
      chat: left == null ? null : Rect.fromLTWH(0, 0, left, area.size.height),
      head: head,
    );
  }

  void pointerTo(Offset global) {
    final area = _area?.findRenderObject();
    if (!dragging || via != ChannelSideDragVia.pointer || area is! RenderBox) {
      return;
    }
    pointer = area.globalToLocal(global);
    final next = channelSideTargetAt(targets, pointer);
    if (next != target) {
      target = next;
      if (next != null && !next.fits) _say(_noRoom());
    }
    notifyListeners();
  }

  /// Arrows go through the places the window holds, wrapping round.
  void step(int by) {
    if (!dragging || via != ChannelSideDragVia.keyboard) return;
    final places = [
      for (final t in targets)
        if (t.fits) t,
    ];
    if (places.isEmpty) return;
    final at = target == null
        ? (by > 0 ? -1 : places.length)
        : places.indexOf(target!);
    final next = places[(at + by + places.length) % places.length];
    target = next;
    lift = next.area.topLeft + const Offset(_keyboardLift, _keyboardLift);
    final c = _at;
    if (c != null && c.mounted) {
      _say(
        raftFormat(c, '{name} will move {target}.', {
          'name': channelSideDragTitle(c, section!),
          'target': _describe(c, next),
        }),
      );
    }
    notifyListeners();
  }

  /// Puts the section down at the place under the hand, or back where it was.
  void end(bool commit) {
    final s = section;
    if (s == null || _disposed) return;
    final t = target;
    final how = via;
    final c = _at;
    HardwareKeyboard.instance.removeHandler(_onKey);
    via = null;
    targets = const [];
    target = null;
    lift = null;
    _at = null;
    final landing = commit && t != null && t.fits && _store != null;
    if (how == ChannelSideDragVia.keyboard && landing) quietGrip = s;
    active.value = null;
    if (landing) {
      _store!.moveSection(s, t.drop);
      if (how == ChannelSideDragVia.keyboard) {
        // The move can put its head in another column: the keyboard stays on
        // the grip.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _heads[s]?.focus.requestFocus(),
        );
      }
      if (c != null && c.mounted) {
        _say(
          raftFormat(c, '{name} moved {target}.', {
            'name': channelSideDragTitle(c, s),
            'target': _describe(c, t),
          }),
          c,
        );
      }
    } else if (c != null && c.mounted) {
      _say(
        raftFormat(c, 'Moving {name} cancelled.', {
          'name': channelSideDragTitle(c, s),
        }),
        c,
      );
    }
    notifyListeners();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.escape &&
        dragging) {
      end(false);
      return true;
    }
    return false;
  }

  String _noRoom() =>
      raftText(_at!, 'The window is too narrow for another column.');

  String _describe(BuildContext c, ChannelSideDropTarget t) {
    final names = channelSideNames(c, [
      for (final s in t.sections) channelSideDragTitle(c, s),
    ]);
    return switch (t.place) {
      ChannelSidePlace.above => raftFormat(c, 'above {section}', {
        'section': channelSideDragTitle(c, t.above!),
      }),
      ChannelSidePlace.bottom => raftFormat(c, 'to the bottom of {sections}', {
        'sections': names,
      }),
      ChannelSidePlace.newLeft => raftFormat(
        c,
        'to a new column left of {sections}',
        {'sections': names},
      ),
      ChannelSidePlace.newRight => raftFormat(
        c,
        'to a new column right of {sections}',
        {'sections': names},
      ),
    };
  }

  void _say(String text, [BuildContext? from]) {
    final c = from ?? _at;
    final view = c == null || !c.mounted ? null : View.maybeOf(c);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      text,
      Directionality.of(c!),
      assertiveness: Assertiveness.assertive,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_onKey);
    active.dispose();
    super.dispose();
  }
}

// ---- the grip ---------------------------------------------------------------

/// A card's head with its drag grip (the `ChannelSideHeadWrapper` the area
/// gives every card): a 96x24 target centred on the head's top edge, only the
/// grip is the handle, the rest of the head keeps its clicks. Hovering the head
/// shows the grip's 56x4 bar. [enabled] false: no grip at all.
class ChannelSideHead extends StatefulWidget {
  const ChannelSideHead({
    super.key,
    required this.drag,
    required this.section,
    required this.enabled,
    required this.child,
  });
  final ChannelSideDragController drag;
  final ChannelSideSection section;
  final bool enabled;
  final Widget child;

  @override
  State<ChannelSideHead> createState() => _ChannelSideHeadState();
}

class _ChannelSideHeadState extends State<ChannelSideHead> {
  final focus = FocusNode(debugLabel: 'side section grip');
  bool hovered = false;
  int? _pointer;
  Offset _start = Offset.zero;

  ChannelSideDragController get drag => widget.drag;
  ChannelSideSection get section => widget.section;

  @override
  void initState() {
    super.initState();
    drag.register(section, context, focus);
  }

  @override
  void dispose() {
    drag.unregister(section, context);
    focus.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse || e.buttons != kPrimaryMouseButton) {
      return;
    }
    _pointer = e.pointer;
    _start = e.position;
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (drag.section != section) {
      if ((e.position - _start).distance < channelSideDragSlop) return;
      if (!drag.begin(
        section,
        context,
        ChannelSideDragVia.pointer,
        global: _start,
      )) {
        _pointer = null;
        return;
      }
    }
    drag.pointerTo(e.position);
  }

  void _up(PointerEvent e, bool commit) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (drag.section == section && drag.via == ChannelSideDragVia.pointer) {
      drag.end(commit);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final pick = k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter;
    if (drag.section != section) {
      if (drag.dragging || !pick || e is! KeyDownEvent) {
        return KeyEventResult.ignored;
      }
      drag.begin(section, context, ChannelSideDragVia.keyboard);
      return KeyEventResult.handled;
    }
    if (drag.via != ChannelSideDragVia.keyboard) return KeyEventResult.ignored;
    if (pick) {
      if (e is KeyDownEvent) drag.end(true);
      return KeyEventResult.handled;
    }
    final by =
        k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowRight
        ? 1
        : k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowLeft
        ? -1
        : 0;
    if (by == 0) return KeyEventResult.ignored;
    drag.step(by);
    return KeyEventResult.handled;
  }

  void _focusChanged(bool focused) {
    if (!focused) {
      // Picked up by keyboard and the focus moves away: cancelled, not left
      // armed.
      if (drag.section == section && drag.via == ChannelSideDragVia.keyboard) {
        drag.end(false);
      }
      if (drag.quietGrip == section) drag.quietGrip = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.enabled)
          Positioned(
            top: _gripTop,
            left: 0,
            right: 0,
            height: _gripHeight,
            child: Center(
              child: SizedBox(
                width: _gripWidth,
                height: _gripHeight,
                child: _grip(context),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _grip(BuildContext context) {
    final t = RaftTokens.of(context);
    return ValueListenableBuilder<ChannelSideSection?>(
      valueListenable: drag.active,
      builder: (context, held, _) {
        final dragging = held == section;
        final keyboard =
            focus.hasFocus &&
            FocusManager.instance.highlightMode ==
                FocusHighlightMode.traditional;
        final bar = dragging
            ? t.colors['foreground-muted']
            : keyboard
            ? t.colors['foreground']
            : hovered
            ? t.colors['line-seam']
            : null;
        return RaftTooltip(
          message: raftText(context, 'Drag to move'),
          enabled: !dragging && drag.quietGrip != section,
          child: Semantics(
            container: true,
            button: true,
            toggled: dragging,
            label: raftFormat(context, 'Move {name}', {
              'name': channelSideDragTitle(context, section),
            }),
            value: raftText(context, 'movable section'),
            hint: raftText(
              context,
              'Press Space to pick up the section, arrow keys to choose where it goes, Space to drop it there, Escape to cancel.',
            ),
            child: Focus(
              focusNode: focus,
              onKeyEvent: _key,
              onFocusChange: _focusChanged,
              child: MouseRegion(
                cursor: dragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab,
                child: Listener(
                  key: Key('side-section-grip-${section.name}'),
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: (e) => _up(e, true),
                  onPointerCancel: (e) => _up(e, false),
                  child: CustomPaint(painter: _GripBar(bar)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The grip's bar: 56x4, rounded, 2px from the grip's top.
class _GripBar extends CustomPainter {
  const _GripBar(this.color);
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    if (color == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (size.width - _barWidth) / 2,
          _barTop,
          _barWidth,
          _barHeight,
        ),
        const Radius.circular(RaftSpace.half),
      ),
      Paint()..color = color!,
    );
  }

  @override
  bool shouldRepaint(_GripBar old) => old.color != color;
}

// ---- what the hand holds ------------------------------------------------------

/// In the area's stack, over everything: the place's dashed area, the copy the
/// hand holds, and the refusal's reason.
class ChannelSideDragLayer extends StatelessWidget {
  const ChannelSideDragLayer({super.key, required this.drag});
  final ChannelSideDragController drag;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: drag,
    builder: (context, _) {
      final s = drag.section;
      if (s == null) return const SizedBox.shrink();
      final t = RaftTokens.of(context);
      final target = drag.target;
      final keyboard = drag.via == ChannelSideDragVia.keyboard;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (!keyboard)
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.grabbing,
                child: const SizedBox.expand(),
              ),
            ),
          if (target != null && target.fits)
            Positioned.fromRect(
              key: const Key('side-section-drop-slot'),
              rect: target.area.deflate(4),
              child: IgnorePointer(child: _Placeholder(tokens: t)),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomSingleChildLayout(
                delegate: _ProxyLayout(
                  at: keyboard ? drag.lift : null,
                  pointer: drag.pointer,
                  grab: drag.grab,
                ),
                child: _Proxy(tokens: t, section: s),
              ),
            ),
          ),
          if (target != null && !target.fits)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomSingleChildLayout(
                  delegate: _HintLayout(drag.pointer),
                  child: _Hint(
                    tokens: t,
                    text: raftText(
                      context,
                      'The window is too narrow for another column.',
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// `DropPlaceholder opaque`: a 1.5px dashed `line-strong` outline on
/// `fill-subtle` over the canvas, square.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tokens});
  final RaftTokens tokens;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBox(
      fill: Color.alphaBlend(
        tokens.colors['fill-subtle']!,
        tokens.colors['layer-canvas']!,
      ),
      line: tokens.colors['line-strong']!,
    ),
  );
}

class _DashedBox extends CustomPainter {
  const _DashedBox({required this.fill, required this.line});
  final Color fill, line;
  static const width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final path = Path()..addRect((Offset.zero & size).deflate(width / 2));
    final paint = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    // Chromium's dashes: 3x the width, the gaps spread evenly over the path.
    const dash = width * 3;
    for (final metric in path.computeMetrics()) {
      final count = ((metric.length + dash) / (dash * 2)).floor().clamp(
        1,
        10000,
      );
      final gap = count > 1 ? (metric.length - count * dash) / count : 0.0;
      for (var i = 0; i < count; i++) {
        final start = i * (dash + gap);
        canvas.drawPath(metric.extractPath(start, start + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.fill != fill || old.line != line;
}

/// `DragLift`: an opaque popover surface, `shadow-float` and the `line-seam`
/// ring; the section's icon and title, 240px at most.
class _Proxy extends StatelessWidget {
  const _Proxy({required this.tokens, required this.section});
  final RaftTokens tokens;
  final ChannelSideSection section;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final radius = BorderRadius.circular(
      t.size('radius.control', fallback: RaftRadius.control),
    );
    return Container(
      constraints: const BoxConstraints(
        minHeight: _proxyMinHeight,
        maxWidth: _proxyMaxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: RaftSpace.x3),
      decoration: BoxDecoration(
        color: t.colors['layer-popover'],
        borderRadius: radius,
        border: Border.all(color: t.colors['line-seam']!),
        boxShadow: [
          for (final layer in t.shadowLayers('shadow.float').reversed)
            if (!layer.inset) layer.toBoxShadow(),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaftIcon(
            switch (section) {
              ChannelSideSection.tasks => RaftGlyph.listTodo,
              ChannelSideSection.files => RaftGlyph.paperclip,
              ChannelSideSection.artifact => RaftGlyph.fileText,
              _ => RaftGlyph.userRound,
            },
            size: RaftSpace.x4,
            color: t.colors['foreground-muted'],
          ),
          const SizedBox(width: RaftSpace.x2),
          Flexible(
            child: RaftCssText(
              channelSideDragTitle(context, section),
              key: const Key('side-section-proxy'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.scale(
                RaftTypeScale.subhead,
                weight: FontWeight.w600,
                color: t.colors['foreground'],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `DragRefusalHint`: a HUD chip with the reason.
class _Hint extends StatelessWidget {
  const _Hint({required this.tokens, required this.text});
  final RaftTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      constraints: const BoxConstraints(maxWidth: _hintMaxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: RaftSpace.x2,
        vertical: RaftSpace.x1,
      ),
      decoration: BoxDecoration(
        color: t.colors['layer-hud'],
        borderRadius: BorderRadius.circular(
          t.size('radius.chip', fallback: RaftRadius.chip),
        ),
        border: Border.all(color: t.colors['line-seam']!),
        boxShadow: [
          for (final layer in t.shadowLayers('shadow.float').reversed)
            if (!layer.inset) layer.toBoxShadow(),
        ],
      ),
      child: RaftCssText(
        text,
        style: t.scale(
          t.typeSlot('caption'),
          color: t.colors['foreground-on-hud'],
        ),
      ),
    );
  }
}

/// The copy: with the pointer it hangs by the point it was picked up at (kept
/// inside it); with the keyboard it stands at [at], the place's corner.
class _ProxyLayout extends SingleChildLayoutDelegate {
  const _ProxyLayout({this.at, required this.pointer, required this.grab});
  final Offset? at;
  final Offset pointer, grab;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().copyWith(maxWidth: _proxyMaxWidth);

  @override
  Offset getPositionForChild(Size size, Size child) {
    if (at != null) return at!;
    final dx = grab.dx.clamp(12.0, (child.width - 12).clamp(12.0, 1e9));
    return Offset(pointer.dx - dx, pointer.dy - child.height / 2);
  }

  @override
  bool shouldRelayout(_ProxyLayout old) =>
      old.at != at || old.pointer != pointer || old.grab != grab;
}

/// The chip sits right of and below the pointer; left of it near the right
/// edge, above it near the bottom; 8px inside the area (Web
/// `placeRefusalHint`).
class _HintLayout extends SingleChildLayoutDelegate {
  const _HintLayout(this.pointer);
  final Offset pointer;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final maxX = size.width - 8 - child.width;
    final maxY = size.height - 8 - child.height;
    final right = pointer.dx + 14, below = pointer.dy + 16;
    final x = right <= maxX ? right : pointer.dx - 14 - child.width;
    final y = below <= maxY ? below : pointer.dy - 16 - child.height;
    return Offset(
      x.clamp(8.0, maxX < 8 ? 8.0 : maxX),
      y.clamp(8.0, maxY < 8 ? 8.0 : maxY),
    );
  }

  @override
  bool shouldRelayout(_HintLayout old) => old.pointer != pointer;
}
