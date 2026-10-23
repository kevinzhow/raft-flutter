// Structural anchors of a document preview (Web attachmentCommentAnchors.ts):
// the lines of a text preview and the rows of a CSV / XLSX preview are
// numbered; in comment mode a tap or a drag over them becomes the anchor of
// the next comment, and a comment's anchor scrolls to its rows and flashes
// them. Outside a comment session (a public page, a plain open) the rows are
// inert wrappers.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'attachment_comment_scope.dart';
import 'theme.dart';

const _lines = 'lines', _rows = 'csv-rows';

/// A stored anchor's number: the API validates the vocabulary, but a stored
/// value may be a string; anything unreadable is null (never a crash).
int? _number(Object? value) =>
    value is num && value.isFinite ? value.toInt() : int.tryParse('$value');

/// `.anchor-flash` lasts 1.6 s: 35 % at full strength, then fading out.
const _flash = Duration(milliseconds: 1600);

/// The rows of the document pane that is open, their text and their geometry.
class RaftDocumentAnchors extends ChangeNotifier {
  RaftDocumentAnchors(this._comments);
  final RaftAttachmentCommentState _comments;

  final _keys = <String, Map<int, List<GlobalKey>>>{};
  final _texts = <String, Map<int, String>>{};

  /// How many rows each kind has (set by the pane): a jump past it is a miss.
  final totals = <String, int>{};

  /// A long list that only builds the rows near the viewport: scrolls so row
  /// `number` of `kind` is built (an estimate; the jump then refines it).
  void Function(String kind, int number)? scrollNear;

  // The drag in progress, and the rows flashing after a jump.
  ({String kind, int start, int end})? _drag, _flashing;
  AnimationController? _flashAnimation;

  /// The session or a row set changed: rows repaint their tint.
  void changed() => notifyListeners();

  void register(String kind, int number, GlobalKey key, String text) {
    (_keys.putIfAbsent(kind, () => {}).putIfAbsent(number, () => [])).add(key);
    _texts.putIfAbsent(kind, () => {})[number] = text;
  }

  void unregister(String kind, int number, GlobalKey key) {
    final rows = _keys[kind]?[number];
    rows?.remove(key);
    if (rows != null && rows.isEmpty) {
      _keys[kind]!.remove(number);
      _texts[kind]?.remove(number);
    }
  }

  /// The numbered row of [kind] under the global [position], if any.
  int? rowAt(String kind, Offset position) {
    final rows = _keys[kind];
    if (rows == null) return null;
    for (final entry in rows.entries) {
      final rect = _rect(entry.value);
      if (rect != null && rect.contains(position)) return entry.key;
    }
    return null;
  }

  Rect? _rect(List<GlobalKey> keys) {
    Rect? union;
    for (final key in keys) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      union = union == null ? rect : union.expandToInclude(rect);
    }
    return union;
  }

  bool isBuilt(String kind, int number) => _keys[kind]?[number] != null;

  /// The text of the rows [start]..[end] that are built (Web: the selection's
  /// text), as a quote.
  String? quoteOf(String kind, int start, int end) {
    final texts = _texts[kind];
    if (texts == null) return null;
    final picked = [
      for (var n = start; n <= end; n++)
        if (texts[n] case final text?) text,
    ];
    return raftCommentQuote(picked.join('\n'));
  }

  RaftCommentAnchor? anchorOf(String kind, int a, int b) {
    final start = a < b ? a : b, end = a < b ? b : a;
    final quote = quoteOf(kind, start, end);
    return {
      'type': kind,
      'data': {'start': start, 'end': end, 'quote': ?quote},
    };
  }

  // ---- the highlight of a row ----

  /// How strongly [number] of [kind] is highlighted: the pending anchor and
  /// the drag in progress tint it, a jump flashes it.
  ({bool selected, double flash}) stateOf(String kind, int number) {
    var selected = false;
    bool within(int start, int end) => number >= start && number <= end;
    final drag = _drag;
    if (drag != null && drag.kind == kind) {
      selected = within(
        drag.start < drag.end ? drag.start : drag.end,
        drag.start < drag.end ? drag.end : drag.start,
      );
    }
    final pending = _comments.pendingAnchor;
    if (!selected && pending != null && pending['type'] == kind) {
      final data = pending['data'];
      final start = data is Map ? _number(data['start']) : null;
      final end = data is Map ? _number(data['end']) : null;
      if (start != null) selected = within(start, end ?? start);
    }
    var flash = 0.0;
    final flashing = _flashing;
    if (flashing != null &&
        flashing.kind == kind &&
        within(flashing.start, flashing.end)) {
      final t = _flashAnimation?.value ?? 1;
      // 0-35 %: full; then ease out to nothing.
      flash = t <= .35 ? 1 : (1 - Curves.easeOut.transform((t - .35) / .65));
    }
    return (selected: selected, flash: flash);
  }

  void drag(String kind, int start, int end) {
    _drag = (kind: kind, start: start, end: end);
    notifyListeners();
  }

  void endDrag() {
    if (_drag == null) return;
    _drag = null;
    notifyListeners();
  }

  /// Flashes rows [start]..[end] with [vsync]'s ticker.
  void flash(String kind, int start, int end, TickerProvider vsync) {
    _flashAnimation?.dispose();
    final animation = _flashAnimation = AnimationController(
      vsync: vsync,
      duration: _flash,
    )..addListener(notifyListeners);
    _flashing = (kind: kind, start: start, end: end);
    animation.forward().whenComplete(() {
      if (!identical(_flashAnimation, animation)) return;
      _flashing = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _flashAnimation?.dispose();
    super.dispose();
  }
}

/// Mounts the registry for one document pane and wires the comment session:
/// capture in comment mode, and the jump handler.
class RaftDocumentAnchorHost extends StatefulWidget {
  const RaftDocumentAnchorHost({
    super.key,
    required this.child,
    this.totals = const {},
    this.scrollNear,
  });
  final Widget child;

  /// How many numbered rows each kind has; a jump past it is a miss.
  final Map<String, int> totals;

  /// Scrolls a lazy list near a row that is not built.
  final void Function(String kind, int number)? scrollNear;

  static RaftDocumentAnchors? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AnchorsScope>()?.anchors;

  @override
  State<RaftDocumentAnchorHost> createState() => _RaftDocumentAnchorHostState();
}

class _RaftDocumentAnchorHostState extends State<RaftDocumentAnchorHost>
    with SingleTickerProviderStateMixin {
  RaftAttachmentCommentState? comments;
  RaftDocumentAnchors? anchors;
  ({String kind, int row})? press;
  Offset? pressAt;
  bool moved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = RaftAttachmentCommentScope.read(context);
    if (identical(next, comments) && (anchors != null || next == null)) return;
    _detach();
    comments = next;
    if (next == null) return;
    anchors = RaftDocumentAnchors(next)..addListener(_changed);
    next.addListener(anchors!.changed);
    next.jumpHandler = jump;
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _detach() {
    final old = anchors;
    if (comments?.jumpHandler == jump) comments?.jumpHandler = null;
    if (old != null) comments?.removeListener(old.changed);
    old?.removeListener(_changed);
    old?.dispose();
    anchors = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Web `jumpToAnchor` for `lines` / `csv-rows`.
  bool jump(RaftCommentAnchor anchor) {
    final type = anchor['type'];
    if (type != _lines && type != _rows) return false;
    final data = anchor['data'];
    final start = data is Map ? _number(data['start']) : null;
    if (start == null || start < 1) return false;
    final end = _number((data as Map)['end']) ?? start;
    final kind = type as String;
    final registry = anchors!;
    final total = registry.totals[kind] ?? 0;
    // A preview cut before the anchored row has nothing to show.
    if (start > total) return false;
    final last = end < start ? start : (end > start + 200 ? start + 200 : end);
    Future<void> reveal(int attempt) async {
      if (!mounted) return;
      if (registry.isBuilt(kind, start)) {
        final context = registry._keys[kind]![start]!.first.currentContext;
        if (context != null) {
          await Scrollable.ensureVisible(
            context,
            alignment: .5,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
        if (mounted) registry.flash(kind, start, last, this);
        return;
      }
      if (attempt == 0) registry.scrollNear?.call(kind, start);
      if (attempt >= 4) return;
      await SchedulerBinding.instance.endOfFrame;
      await reveal(attempt + 1);
    }

    unawaited(reveal(0));
    return true;
  }

  // ---- capture in comment mode ----

  void _down(PointerDownEvent event) {
    final state = comments;
    final registry = anchors;
    if (state == null || registry == null || !state.commentMode) return;
    press = null;
    for (final kind in const [_lines, _rows]) {
      final row = registry.rowAt(kind, event.position);
      if (row != null) {
        press = (kind: kind, row: row);
        pressAt = event.position;
        moved = false;
        return;
      }
    }
  }

  void _move(PointerMoveEvent event) {
    final p = press;
    final registry = anchors;
    if (p == null || registry == null) return;
    if (!moved && (event.position - pressAt!).distance < 6) return;
    moved = true;
    final row = registry.rowAt(p.kind, event.position);
    if (row != null) registry.drag(p.kind, p.row, row);
  }

  void _up(PointerUpEvent event) {
    final p = press, registry = anchors, state = comments;
    press = null;
    if (p == null || registry == null || state == null) return;
    final row = moved
        ? (registry.rowAt(p.kind, event.position) ?? p.row)
        : p.row;
    registry.endDrag();
    final anchor = registry.anchorOf(p.kind, p.row, row);
    if (anchor != null) state.pushAnchor(anchor);
  }

  @override
  Widget build(BuildContext context) {
    anchors
      ?..totals.addAll(widget.totals)
      ..scrollNear = widget.scrollNear;
    return buildHost(context);
  }

  Widget buildHost(BuildContext context) => anchors == null
      ? widget.child
      : _AnchorsScope(
          anchors: anchors!,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: (_) {
              press = null;
              anchors?.endDrag();
            },
            child: widget.child,
          ),
        );
}

class _AnchorsScope extends InheritedWidget {
  const _AnchorsScope({required this.anchors, required super.child});
  final RaftDocumentAnchors anchors;
  @override
  bool updateShouldNotify(_AnchorsScope old) =>
      !identical(old.anchors, anchors);
}

/// One numbered line or row of a document pane (Web `data-anchor-line` /
/// `data-anchor-row`). Inert outside a comment session; inside one it
/// registers for capture and jumps, and wears the pending / flash tint.
class RaftAnchorRow extends StatefulWidget {
  const RaftAnchorRow({
    super.key,
    required this.kind,
    required this.number,
    required this.text,
    required this.child,
  });

  /// `lines` or `csv-rows`.
  final String kind;

  /// 1-based.
  final int number;

  /// The row's text, the context quote of an anchor on it.
  final String text;
  final Widget child;

  @override
  State<RaftAnchorRow> createState() => _RaftAnchorRowState();
}

class _RaftAnchorRowState extends State<RaftAnchorRow> {
  final key = GlobalKey();
  RaftDocumentAnchors? registry;
  String? kind;
  int? number;

  void _register() {
    final next = RaftDocumentAnchorHost.of(context);
    if (identical(next, registry) &&
        kind == widget.kind &&
        number == widget.number) {
      return;
    }
    if (registry != null && kind != null) {
      registry!.unregister(kind!, number!, key);
    }
    registry = next;
    kind = widget.kind;
    number = widget.number;
    next?.register(widget.kind, widget.number, key, widget.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(covariant RaftAnchorRow old) {
    super.didUpdateWidget(old);
    _register();
  }

  @override
  void dispose() {
    if (registry != null && kind != null) {
      registry!.unregister(kind!, number!, key);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchors = registry;
    if (anchors == null) return widget.child;
    return ListenableBuilder(
      listenable: anchors,
      builder: (context, child) {
        final state = anchors.stateOf(widget.kind, widget.number);
        final t = RaftTokens.of(context);
        Color? color;
        if (state.flash > 0) {
          color = (t.colors['info-soft'] ?? t.colors['fill-muted']!).withValues(
            alpha: state.flash,
          );
        } else if (state.selected) {
          color = t.colors['fill-muted'];
        }
        return KeyedSubtree(
          key: key,
          child: color == null
              ? child!
              : ColoredBox(color: color, child: child),
        );
      },
      child: widget.child,
    );
  }
}
