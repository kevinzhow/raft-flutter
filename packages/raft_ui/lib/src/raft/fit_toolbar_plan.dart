// The fit of raft-ui `FitToolbar` as pure functions: which steps each item has
// taken at a width, and how the toolbar lays out in them. The widget
// (fit_toolbar.dart) measures every form of every item once and calls
// [raftFit]; nothing here touches the widget tree.
//
// Port of raft-ui 0.95.3 `fit-toolbar.mjs` `measure` (:99-205) and `fits`
// (:60-97):
//  * every run starts from nothing taken, so the outcome depends on the width
//    and the content only (no hysteresis);
//  * one order for the whole toolbar: ascending number first, the last item
//    first on a tie, an item's own steps in enum order;
//  * the `label` and `plus` steps of the items of one group at one number are
//    taken together;
//  * after the loop, a step an item of a group that wrapped later gave up is
//    given back when the toolbar still fits ("a wrapped group gets back what
//    its items gave before it wrapped").
import 'dart:math' as math;

/// The ways an item gives way, in the order an item takes them (`STEPS`).
enum RaftFitStep { label, more, collapse, wrap, plus }

/// What a toolbar entry (an item, a group or the search) declares: step ->
/// order number, in DOM order of the toolbar.
class RaftFitEntry {
  const RaftFitEntry(
    this.id, {
    this.steps = const {},
    this.groupId,
    this.pinned = false,
    this.firstLine = false,
  });

  final Object id;
  final Map<RaftFitStep, int> steps;

  /// The group an item sits in (null for a group or the search itself).
  final Object? groupId;

  /// In a group's pinned `end`: its steps are not given back.
  final bool pinned;

  /// A group that never wraps (`firstLine`).
  final bool firstLine;
}

typedef RaftFitTaken = Map<Object, Set<RaftFitStep>>;

/// The steps taken, ids in `more` in DOM order, whether any group wrapped.
class RaftFitPlan {
  const RaftFitPlan(this.taken, this.more, this.wrapping);
  final RaftFitTaken taken;
  final List<Object> more;
  final bool wrapping;

  bool has(Object id, RaftFitStep step) => taken[id]?.contains(step) ?? false;
}

class _Queued {
  _Queued(this.entry, this.step, this.order, this.index);
  final RaftFitEntry entry;
  final RaftFitStep step;
  final int order;
  final int index;
}

class _Batch {
  _Batch(this.step, this.members);
  final RaftFitStep step;
  final List<RaftFitEntry> members;
}

/// Takes steps one at a time, in their order, until [fits] says the toolbar
/// fits, then gives back what a later-wrapped group's items gave first.
RaftFitPlan raftFitPlan(
  List<RaftFitEntry> entries, {
  required bool Function(RaftFitTaken taken) fits,
  bool hasMore = false,
  bool allowWrap = false,
}) {
  final byId = {for (final e in entries) e.id: e};
  final queue = <_Queued>[];
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    for (final step in RaftFitStep.values) {
      final order = entry.steps[step];
      if (order == null) continue;
      if (step == RaftFitStep.more && !hasMore) continue;
      if (step == RaftFitStep.wrap && (!allowWrap || entry.firstLine)) continue;
      queue.add(_Queued(entry, step, order, i));
    }
  }
  // Ascending order; the last item first on a tie; one item's steps by enum.
  queue.sort((a, b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    final byIndex = b.index.compareTo(a.index);
    if (byIndex != 0) return byIndex;
    return a.step.index.compareTo(b.step.index);
  });
  final batches = <_Batch>[];
  final byKind = <String, _Batch>{};
  for (final q in queue) {
    final batched =
        (q.step == RaftFitStep.label || q.step == RaftFitStep.plus) &&
        q.entry.groupId != null;
    final kind = batched
        ? '${q.entry.groupId}|${q.step.name}|${q.order}'
        : null;
    final existing = kind == null ? null : byKind[kind];
    if (existing != null) {
      existing.members.add(q.entry);
      continue;
    }
    final batch = _Batch(q.step, [q.entry]);
    batches.add(batch);
    if (kind != null) byKind[kind] = batch;
  }

  final taken = <Object, Set<RaftFitStep>>{};
  bool has(Object id, RaftFitStep s) => taken[id]?.contains(s) ?? false;
  void take(Object id, RaftFitStep s) => (taken[id] ??= {}).add(s);
  void undo(Object id, RaftFitStep s) => taken[id]?.remove(s);

  final history = <_Batch>[];
  for (final batch in batches) {
    if (fits(taken)) break;
    final giving = [
      for (final m in batch.members)
        if (!has(m.id, RaftFitStep.more) &&
            (m.groupId == null || !has(m.groupId!, RaftFitStep.more)))
          m,
    ];
    if (giving.isEmpty) continue;
    for (final m in giving) {
      take(m.id, batch.step);
    }
    history.add(_Batch(batch.step, giving));
  }

  for (var index = history.length - 1; index >= 0; index--) {
    final h = history[index];
    if (h.step == RaftFitStep.wrap) continue;
    final first = h.members.first;
    final Object? group = has(first.id, RaftFitStep.wrap)
        ? first.id
        : (first.groupId != null && has(first.groupId!, RaftFitStep.wrap))
        ? first.groupId
        : null;
    if (group == null) continue;
    final wrappedAt = history.indexWhere(
      (e) =>
          e.step == RaftFitStep.wrap && e.members.any((m) => byId[group] == m),
    );
    if (wrappedAt < index) continue;
    final back = [
      for (final m in h.members)
        if (!m.pinned) m,
    ];
    if (back.isEmpty) continue;
    for (final m in back) {
      undo(m.id, h.step);
    }
    if (!fits(taken)) {
      for (final m in back) {
        take(m.id, h.step);
      }
    }
  }

  final more = [
    for (final e in entries)
      if (has(e.id, RaftFitStep.more)) e.id,
  ];
  final wrapping = taken.values.any((s) => s.contains(RaftFitStep.wrap));
  return RaftFitPlan(
    {
      for (final e in taken.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    },
    more,
    wrapping,
  );
}

// ---------------------------------------------------------------------------
// The width model: what a toolbar looks like in a set of taken steps.

/// One control of a group and the widths of its forms. [label] is the width
/// once its label has gone (null: it has no such form), [plus] the width of
/// its + form. [isMore] is the toolbar's More button: shown only while an item
/// is in More.
class RaftFitLeafSpec {
  const RaftFitLeafSpec(
    this.id, {
    required this.full,
    this.label,
    this.plus,
    this.labelOrder,
    this.plusOrder,
    this.moreOrder,
    this.isMore = false,
    this.pinned = false,
  });
  final Object id;
  final double full;
  final double? label, plus;
  final int? labelOrder, plusOrder, moreOrder;
  final bool isMore, pinned;

  double widthIn(Set<RaftFitStep>? steps) {
    if (steps != null) {
      if (steps.contains(RaftFitStep.plus) && plus != null) return plus!;
      if (steps.contains(RaftFitStep.label) && label != null) return label!;
    }
    return full;
  }
}

sealed class RaftFitNodeSpec {
  const RaftFitNodeSpec(this.id);
  final Object id;
}

/// `FitToolbarGroup`: a row of leaves, or (scroll) a row that scrolls with
/// [endWidth] of pinned `end` after it.
class RaftFitGroupSpec extends RaftFitNodeSpec {
  const RaftFitGroupSpec(
    super.id, {
    required this.leaves,
    this.firstLine = false,
    this.scroll = false,
    this.wrapOrder = 0,
    this.moreOrder,
    this.collapseOrder,
    this.collapsedWidth,
    this.endWidth = 0,
  });
  final List<RaftFitLeafSpec> leaves;
  final bool firstLine, scroll;
  final int wrapOrder;
  final int? moreOrder, collapseOrder;
  final double? collapsedWidth;
  final double endWidth;
}

/// `FitToolbarSearch`: fills the rest of its line, at least [minWidth]; from
/// [collapseOrder] on a [buttonWidth] icon button (order first) and a spacer.
class RaftFitSearchSpec extends RaftFitNodeSpec {
  const RaftFitSearchSpec(
    super.id, {
    required this.minWidth,
    required this.buttonWidth,
    this.collapseOrder,
  });
  final double minWidth, buttonWidth;
  final int? collapseOrder;
}

enum RaftFitSlotKind { group, search, searchButton, spacer }

/// One element of a line with the width the layout gives it.
class RaftFitSlot {
  const RaftFitSlot(this.id, this.kind, this.width);
  final Object id;
  final RaftFitSlotKind kind;
  final double width;
}

class RaftFitLayout {
  const RaftFitLayout(this.lines, this.fits);

  /// The first line, then one line per wrapped group.
  final List<List<RaftFitSlot>> lines;
  final bool fits;
}

const double _tolerance = .5;

/// Lays the toolbar out in [taken] at [width]: the first line holds the
/// search, the groups that did not wrap and More; each wrapped group takes a
/// line of its own below. [fits] is the `fits` of the Web: nothing pokes out
/// of a line, a scroll group's first control is whole, and a scroll group that
/// could still wrap does not yet scroll.
RaftFitLayout raftFitLayout(
  List<RaftFitNodeSpec> nodes,
  RaftFitTaken taken, {
  required double width,
  double gap = 8,
  bool allowWrap = false,
}) {
  bool has(Object id, RaftFitStep s) => taken[id]?.contains(s) ?? false;
  final moreShown = taken.values.any((s) => s.contains(RaftFitStep.more));
  var fits = true;

  List<RaftFitLeafSpec> visible(RaftFitGroupSpec g) => [
    for (final l in g.leaves)
      if (!has(l.id, RaftFitStep.more) && (!l.isMore || moreShown)) l,
  ];
  double rowWidth(RaftFitGroupSpec g) {
    if (has(g.id, RaftFitStep.collapse)) return g.collapsedWidth!;
    final leaves = visible(g);
    var sum = 0.0;
    for (final l in leaves) {
      sum += l.widthIn(taken[l.id]);
    }
    return sum + math.max(0, leaves.length - 1) * gap;
  }

  double endPart(RaftFitGroupSpec g, int leaves) =>
      g.endWidth > 0 ? g.endWidth + (leaves > 0 ? gap : 0) : 0;
  double scrollMin(RaftFitGroupSpec g) {
    final leaves = visible(g);
    final first = leaves.isEmpty
        ? 0.0
        : leaves.first.widthIn(taken[leaves.first.id]);
    return first + endPart(g, leaves.length);
  }

  // The first line, as elements in their order; a collapsed search's button
  // goes to the front (`order-first`).
  final fixed = <RaftFitSlot>[];
  final order = <_El>[];
  var buttons = 0;
  var searchLike = false;
  for (final node in nodes) {
    if (has(node.id, RaftFitStep.wrap)) continue;
    switch (node) {
      case RaftFitSearchSpec():
        searchLike = true;
        if (has(node.id, RaftFitStep.collapse)) {
          order.insert(
            buttons++,
            _El.fixed(
              RaftFitSlot(
                node.id,
                RaftFitSlotKind.searchButton,
                node.buttonWidth,
              ),
            ),
          );
          order.add(
            _El.flex(node.id, RaftFitSlotKind.spacer, 0, 0, search: true),
          );
        } else {
          order.add(
            _El.flex(
              node.id,
              RaftFitSlotKind.search,
              node.minWidth,
              node.minWidth,
              search: true,
            ),
          );
        }
      case RaftFitGroupSpec():
        if (has(node.id, RaftFitStep.more)) continue;
        if (node.scroll) {
          final content = rowWidth(node);
          final n = visible(node).length;
          order.add(
            _El.flex(
              node.id,
              RaftFitSlotKind.group,
              scrollMin(node),
              content + endPart(node, n),
              group: node,
            ),
          );
        } else {
          order.add(
            _El.fixed(
              RaftFitSlot(node.id, RaftFitSlotKind.group, rowWidth(node)),
            ),
          );
        }
    }
  }
  fixed.addAll([
    for (final e in order)
      if (e.slot != null) e.slot!,
  ]);
  final lines = <List<RaftFitSlot>>[];
  if (order.isNotEmpty) {
    final gaps = (order.length - 1) * gap;
    var fixedSum = 0.0, minSum = 0.0, scrollDesired = 0.0, searchMin = 0.0;
    for (final e in order) {
      if (e.slot != null) {
        fixedSum += e.slot!.width;
      } else {
        minSum += e.min;
        if (e.search) {
          searchMin += e.min;
        } else {
          scrollDesired += e.desired;
        }
      }
    }
    final avail = width.isFinite ? width - gaps - fixedSum : double.infinity;
    if (avail + _tolerance < minSum) fits = false;
    // Scroll groups: shrink toward their first control when short, grow into
    // the line when no search takes the rest.
    final scrolls = [
      for (final e in order)
        if (e.slot == null && !e.search) e,
    ];
    final free = avail - searchMin;
    final scrollWidths = <Object, double>{};
    if (scrolls.isNotEmpty) {
      if (!avail.isFinite) {
        for (final e in scrolls) {
          scrollWidths[e.id] = e.desired;
        }
      } else if (searchLike) {
        final total = scrollDesired <= free
            ? scrollDesired
            : math.max(free, scrolls.fold(0.0, (s, e) => s + e.min));
        for (final e in scrolls) {
          scrollWidths[e.id] = scrollDesired <= free
              ? e.desired
              : math.max(
                  e.min,
                  scrollDesired == 0 ? 0.0 : e.desired * total / scrollDesired,
                );
        }
      } else {
        final extra = (avail - scrollDesired) / scrolls.length;
        for (final e in scrolls) {
          scrollWidths[e.id] = math.max(e.min, e.desired + extra);
        }
      }
      for (final e in scrolls) {
        final g = e.group!;
        final w = scrollWidths[e.id]!;
        final content = rowWidth(g);
        if (allowWrap &&
            !g.firstLine &&
            content > w - endPart(g, visible(g).length) + _tolerance) {
          fits = false;
        }
      }
    }
    final scrollTotal = scrollWidths.values.fold(0.0, (s, w) => s + w);
    final rest = avail.isFinite ? math.max(0.0, avail - scrollTotal) : 0.0;
    final line = <RaftFitSlot>[];
    for (final e in order) {
      if (e.slot != null) {
        line.add(e.slot!);
      } else if (e.search) {
        line.add(
          RaftFitSlot(
            e.id,
            e.kind,
            e.kind == RaftFitSlotKind.search ? math.max(e.min, rest) : rest,
          ),
        );
      } else {
        line.add(RaftFitSlot(e.id, e.kind, scrollWidths[e.id]!));
      }
    }
    lines.add(line);
  }

  for (final node in nodes) {
    if (node is! RaftFitGroupSpec || !has(node.id, RaftFitStep.wrap)) continue;
    if (node.scroll) {
      if (width.isFinite && scrollMin(node) > width + _tolerance) fits = false;
      lines.add([
        RaftFitSlot(
          node.id,
          RaftFitSlotKind.group,
          width.isFinite
              ? width
              : rowWidth(node) + endPart(node, visible(node).length),
        ),
      ]);
    } else {
      final w = rowWidth(node);
      if (width.isFinite && w > width + _tolerance) fits = false;
      lines.add([RaftFitSlot(node.id, RaftFitSlotKind.group, w)]);
    }
  }
  return RaftFitLayout(lines, fits);
}

class _El {
  _El.fixed(RaftFitSlot this.slot)
    : id = slot.id,
      kind = slot.kind,
      min = 0,
      desired = 0,
      search = false,
      group = null;
  _El.flex(
    this.id,
    this.kind,
    this.min,
    this.desired, {
    this.search = false,
    this.group,
  }) : slot = null;
  final RaftFitSlot? slot;
  final Object id;
  final RaftFitSlotKind kind;
  final double min, desired;
  final bool search;
  final RaftFitGroupSpec? group;
}

/// The result of [raftFit]: the steps taken and the layout they give.
class RaftFitResult {
  const RaftFitResult(this.plan, this.layout);
  final RaftFitPlan plan;
  final RaftFitLayout layout;
}

/// The whole fit: the steps taken at [width] and the layout in them.
/// [hasMore] says the toolbar has a More button, [allowWrap] that it wraps.
RaftFitResult raftFit(
  List<RaftFitNodeSpec> nodes, {
  required double width,
  double gap = 8,
  bool hasMore = false,
  bool allowWrap = false,
}) {
  final entries = <RaftFitEntry>[];
  for (final node in nodes) {
    switch (node) {
      case RaftFitSearchSpec():
        entries.add(
          RaftFitEntry(
            node.id,
            steps: {
              if (node.collapseOrder != null)
                RaftFitStep.collapse: node.collapseOrder!,
            },
          ),
        );
      case RaftFitGroupSpec():
        entries.add(
          RaftFitEntry(
            node.id,
            firstLine: node.firstLine,
            steps: {
              RaftFitStep.wrap: node.wrapOrder,
              if (node.moreOrder != null) RaftFitStep.more: node.moreOrder!,
              if (node.collapseOrder != null && node.collapsedWidth != null)
                RaftFitStep.collapse: node.collapseOrder!,
            },
          ),
        );
        for (final l in node.leaves) {
          entries.add(
            RaftFitEntry(
              l.id,
              groupId: node.id,
              pinned: l.pinned,
              steps: {
                if (l.labelOrder != null && l.label != null)
                  RaftFitStep.label: l.labelOrder!,
                if (l.moreOrder != null) RaftFitStep.more: l.moreOrder!,
                if (l.plusOrder != null && l.plus != null)
                  RaftFitStep.plus: l.plusOrder!,
              },
            ),
          );
        }
    }
  }
  RaftFitLayout layoutOf(RaftFitTaken taken) =>
      raftFitLayout(nodes, taken, width: width, gap: gap, allowWrap: allowWrap);
  final plan = raftFitPlan(
    entries,
    fits: (taken) => layoutOf(taken).fits,
    hasMore: hasMore,
    allowWrap: allowWrap,
  );
  return RaftFitResult(plan, layoutOf(plan.taken));
}
