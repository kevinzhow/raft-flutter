// Presentation of the Web member graph (packages/web/src/components/settings/
// MemberGraphSection.tsx + MainLayout `MemberGraphRoute`): the Connections
// header with Refresh, the zoomable / pannable graph canvas, the Humans /
// Agents / Links tiles and the two ranked lists. Layout and zoom maths live in
// member_graph_layout.dart (a port of the Web code); the app owns the request,
// the avatars and the profile hover card and passes them in.
// Tailwind classes written in the JSX are resolved in comments.
import 'card.dart' show RaftCard;
import 'hover_region.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;

import 'agent_profile.dart' show RaftAvatarSlotContext;
import 'design_primitives.dart';
import 'dialog_card.dart';
import 'icons.dart';
import 'list_items.dart' show RaftSectionHeader;
import 'error_presentation.dart';
import 'localization.dart';
import 'member_graph_layout.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/button_variants.g.dart';
import 'system_inset.dart' show raftScrollPadding;
import 'theme.dart';

export 'member_graph_layout.dart'
    show RaftGraphChannel, RaftGraphMember, RaftGraphZoom;

/// `GraphResponse` (edges are not used by the Web view).
@immutable
class RaftMemberGraphData {
  const RaftMemberGraphData({
    this.humans = const [],
    this.agents = const [],
    this.channels = const [],
  });
  final List<RaftGraphMember> humans, agents;
  final List<RaftGraphChannel> channels;
}

/// Wraps a node's avatar (the Web `PreviewCardTrigger`): the app adds the
/// profile hover card.
typedef RaftGraphNodeWrapper = Widget Function(
  BuildContext context,
  RaftGraphMember member,
  Widget node,
);

/// A member's avatar for a slot size (`AvatarSlot`): [fill] fills the node
/// circle, otherwise the compact list avatar.
typedef RaftGraphAvatarBuilder = Widget Function(
  BuildContext context,
  RaftGraphMember member, {
  required bool compact,
});

/// `flex-1 overflow-y-auto bg-layer-panel px-5 py-4 theme-brutal:bg-white`
/// around the section (MainLayout `MemberGraphRoute`).
class RaftMemberGraphPageBody extends StatelessWidget {
  const RaftMemberGraphPageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return ColoredBox(
      color: t.colors['layer-panel']!,
      child: ListView(
        key: const PageStorageKey('member-graph-scroll'),
        padding: raftScrollPadding(
          context,
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        children: [child],
      ),
    );
  }
}

/// The whole member graph body of `MemberGraphSection`.
class RaftMemberGraphView extends StatelessWidget {
  const RaftMemberGraphView({
    super.key,
    required this.data,
    required this.avatar,
    required this.onRefresh,
    this.loading = false,
    this.error,
    this.sectionLabel = 'Connections',
    this.nodeWrapper,
  });

  /// Null before the first answer (the Web view then draws the empty state).
  final RaftMemberGraphData? data;
  final bool loading;
  final String? error;
  final String sectionLabel;
  final RaftGraphAvatarBuilder avatar;
  final VoidCallback onRefresh;
  final RaftGraphNodeWrapper? nodeWrapper;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final d = data ?? const RaftMemberGraphData();
    final members = [...d.humans, ...d.agents];
    final links = raftBuildMemberLinks(members, d.channels);
    final degrees = raftMemberLinkDegrees(links);
    final ranked = _rankedMembers(members, degrees);
    final channels = _rankedChannels(d.channels);
    final canvas = RaftMemberGraphCanvas(
      data: d,
      avatar: avatar,
      nodeWrapper: nodeWrapper,
    );
    final side = _Sidebar(
      humans: d.humans.length,
      agents: d.agents.length,
      links: links.length,
      ranked: ranked,
      degrees: degrees,
      channels: channels,
      avatar: avatar,
    );
    // `grid gap-4 xl:grid-cols-[minmax(0,1fr)_280px]`
    final grid = width >= 1280
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: canvas),
              const SizedBox(width: 16),
              SizedBox(width: 280, child: side),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [canvas, side],
          );
    final header = _Header(
      label: sectionLabel,
      count: data == null ? null : d.humans.length + d.agents.length,
      loading: loading,
      onRefresh: onRefresh,
      wide: width >= 640,
    );
    // `space-y-4`
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        header,
        if (error != null)
          RaftErrorBanner(
            error!,
            key: const ValueKey('member-graph-error'),
            small: true,
            bold: true,
          ),
        grid,
      ],
    );
  }

  static List<RaftGraphMember> _rankedMembers(
    List<RaftGraphMember> members,
    Map<String, int> degrees,
  ) {
    final sorted = [...members]
      ..sort((a, b) {
        final diff = (degrees[b.key] ?? 0) - (degrees[a.key] ?? 0);
        return diff != 0 ? diff : raftLocaleCompare(a.label, b.label);
      });
    return sorted.take(6).toList();
  }

  static List<RaftGraphChannel> _rankedChannels(List<RaftGraphChannel> all) =>
      raftSortedGraphChannels(all).take(6).toList();
}

class _Header extends StatefulWidget {
  const _Header({
    required this.label,
    required this.count,
    required this.loading,
    required this.onRefresh,
    required this.wide,
  });
  final String label;
  final int? count;
  final bool loading, wide;
  final VoidCallback onRefresh;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with SingleTickerProviderStateMixin {
  late final spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
    if (widget.loading) spin.repeat();
  }

  @override
  void didUpdateWidget(_Header old) {
    super.didUpdateWidget(old);
    if (widget.loading && !spin.isAnimating) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      spin.repeat();
    } else if (!widget.loading && spin.isAnimating) {
      spin.stop();
      spin.value = 0;
    }
  }

  @override
  void dispose() {
    spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final heading = RaftSectionHeader(
      icon: const RaftIcon(RaftGlyph.gitBranch, size: 16),
      label: raftText(context, widget.label),
      count: widget.count,
    );
    // `<Button variant="outline" size="sm" className="w-fit">` with a 14px
    // RefreshCw (`animate-spin` while loading).
    final refresh = RaftRecipeButton(
      key: const ValueKey('member-graph-refresh'),
      variant: RaftButtonRecipeVariant.outline,
      size: RaftButtonRecipeSize.sm,
      disabled: widget.loading,
      onPressed: widget.onRefresh,
      gap: 8,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          RotationTransition(
            turns: spin,
            child: RaftIcon(RaftGlyph.refreshCw, size: 14, color: t.ink),
          ),
          Text(raftText(context, 'Refresh')),
        ],
      ),
    );
    // `flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between`
    return widget.wide
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: heading),
              refresh,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [heading, refresh],
          );
  }
}

// ---------------------------------------------------------------- sidebar

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.humans,
    required this.agents,
    required this.links,
    required this.ranked,
    required this.degrees,
    required this.channels,
    required this.avatar,
  });
  final int humans, agents, links;
  final List<RaftGraphMember> ranked;
  final Map<String, int> degrees;
  final List<RaftGraphChannel> channels;
  final RaftGraphAvatarBuilder avatar;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    String tr(String s) => raftText(context, s);
    final muted = t.colors['foreground-muted']!;
    final strong = t.strong;
    TextStyle text({
      double size = 12,
      double line = 16,
      FontWeight? weight,
      Color? color,
      bool mono = false,
    }) => TextStyle(
      fontFamily: mono ? t.monoFont : t.headingFont,
      fontFamilyFallback: t.fontFallback,
      fontSize: size,
      height: line / size,
      fontWeight: weight,
      color: color ?? t.ink,
      leadingDistribution: TextLeadingDistribution.even,
    );
    Widget tile(String value, String label) => Expanded(
      // `Card className="p-2 text-center"`
      child: RaftCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            RaftCssText(
              value,
              style: text(size: 18, line: 28, weight: RaftTypography.black(t)),
            ),
            RaftCssText(
              tr(label),
              style: text(
                size: 10,
                line: 15,
                weight: FontWeight.w700,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
    Widget ranked_(String title, List<Widget> rows, String empty) =>
        // `Card className="p-3"`
        RaftCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RaftCssText(
                  tr(title),
                  style: text(weight: RaftTypography.black(t), color: strong),
                ),
              ),
              if (rows.isEmpty)
                RaftCssText(
                  tr(empty),
                  style: text(color: t.colors['foreground-placeholder'])
                      .copyWith(fontStyle: FontStyle.italic),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: rows,
                ),
            ],
          ),
        );
    Widget row(Widget lead, String name, String value, Key key) => Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            spacing: 6,
            children: [
              lead,
              Expanded(
                child: RaftCssText(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text(weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        RaftCssText(value, style: text(mono: true, color: muted)),
      ],
    );
    // `space-y-3`
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            tile('$humans', 'Humans'),
            tile('$agents', 'Agents'),
            tile('$links', 'Links'),
          ],
        ),
        ranked_('Most connected members', [
          for (final m in ranked)
            row(
              SizedBox.square(
                dimension: RaftAvatarSlotContext.compactList.size,
                child: avatar(context, m, compact: true),
              ),
              m.label,
              '${degrees[m.key] ?? 0}',
              ValueKey('member-graph-ranked-${m.key}'),
            ),
        ], 'No memberships yet.'),
        ranked_('Largest channels', [
          for (final c in channels)
            row(
              RaftIcon(RaftGlyph.hash, size: 13, color: t.ink),
              c.name,
              '${c.humanCount}H/${c.agentCount}A',
              ValueKey('member-graph-channel-${c.id}'),
            ),
        ], 'No visible channels yet.'),
      ],
    );
  }
}

// ----------------------------------------------------------------- canvas

/// `MemberGraphCanvas`: edges are painted from the zoomed view box, the member
/// nodes are positioned over it from the zoom transform (like the Web's
/// absolutely positioned buttons), and d3-zoom's wheel / drag / pinch /
/// double-click gestures move the transform.
class RaftMemberGraphCanvas extends StatefulWidget {
  const RaftMemberGraphCanvas({
    super.key,
    required this.data,
    required this.avatar,
    this.nodeWrapper,
  });
  final RaftMemberGraphData data;
  final RaftGraphAvatarBuilder avatar;
  final RaftGraphNodeWrapper? nodeWrapper;
  @override
  State<RaftMemberGraphCanvas> createState() => _RaftMemberGraphCanvasState();
}

/// Largest graph the layout runs for on the UI thread; bigger ones compute in
/// a background isolate (the force layout is O(iterations * n^2)).
const _syncLayoutLimit = 120;

class _Model {
  _Model(this.members, this.channels, this.links, this.dense, this.layout);
  final List<RaftGraphMember> members;
  final List<RaftGraphChannel> channels;
  final List<RaftGraphLink> links;
  final bool dense;
  final RaftGraphLayout layout;
}

class _LayoutJob {
  _LayoutJob(this.members, this.links, this.dense);
  final List<RaftGraphMember> members;
  final List<RaftGraphLink> links;
  final bool dense;
}

RaftGraphLayout _runLayout(_LayoutJob job) =>
    raftComputeMemberNetworkLayout(job.members, job.links, job.dense);

class _RaftMemberGraphCanvasState extends State<RaftMemberGraphCanvas> {
  _Model? model;
  int modelRevision = 0;
  RaftGraphZoom zoom = RaftGraphZoom.identity;

  // Gesture state.
  RaftGraphZoom? gestureStart;
  Offset? gestureFocal;
  Size dims = Size.zero;

  /// Double click detection (d3-zoom listens to `dblclick`): the previous
  /// primary tap and where the current press began.
  ({Offset at, Duration time})? previousTap;
  Offset? pressAt;

  @override
  void initState() {
    super.initState();
    prepare();
  }

  @override
  void didUpdateWidget(RaftMemberGraphCanvas old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) prepare();
  }

  void prepare() {
    final d = widget.data;
    final members = raftSortedGraphMembers(d.humans, d.agents);
    final channels = raftSortedGraphChannels(d.channels);
    final links = raftBuildMemberLinks(members, channels);
    final dense = raftGraphDense(members.length, links.length);
    final revision = ++modelRevision;
    if (members.length <= _syncLayoutLimit) {
      model = _Model(
        members,
        channels,
        links,
        dense,
        raftComputeMemberNetworkLayout(members, links, dense),
      );
      return;
    }
    // Keep the previous drawing until the new layout is ready.
    unawaited(
      compute(_runLayout, _LayoutJob(members, links, dense)).then((layout) {
        if (!mounted || revision != modelRevision) return;
        setState(() => model = _Model(members, channels, links, dense, layout));
      }),
    );
  }

  // ------------------------------------------------------------- zoom

  void setZoom(RaftGraphZoom next) {
    if (next == zoom) return;
    setState(() => zoom = next);
  }

  void onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || dims.isEmpty) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final e = event as PointerScrollEvent;
      final ctrl =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      setZoom(
        zoom.zoomAt(
          e.localPosition.dx,
          e.localPosition.dy,
          RaftGraphZoom.wheelDelta(e.scrollDelta.dy, ctrl: ctrl),
          dims.width,
          dims.height,
        ),
      );
    });
  }

  void onScaleStart(ScaleStartDetails d) {
    gestureStart = zoom;
    gestureFocal = d.localFocalPoint;
  }

  void onScaleUpdate(ScaleUpdateDetails d) {
    final start = gestureStart, focal = gestureFocal;
    if (start == null || focal == null || dims.isEmpty) return;
    // Pinch: scale about the starting focal point, then follow the focal
    // point (pan). A one-finger drag has scale 1 and only pans.
    var next = start;
    if (d.pointerCount > 1 && d.scale != 1) {
      next = start.zoomTo(
        focal.dx,
        focal.dy,
        start.k * d.scale,
        dims.width,
        dims.height,
      );
    }
    final move = d.localFocalPoint - focal;
    setZoom(next.pan(move.dx, move.dy, dims.width, dims.height));
  }

  void onScaleEnd(ScaleEndDetails d) {
    gestureStart = null;
    gestureFocal = null;
  }

  void onPointerDown(PointerDownEvent e) {
    pressAt = e.localPosition;
  }

  /// A press that did not travel and follows another within 300 ms and 24px.
  void onPointerUp(PointerUpEvent e) {
    final down = pressAt;
    pressAt = null;
    if (down == null || (e.localPosition - down).distance > 8) {
      previousTap = null;
      return;
    }
    final previous = previousTap;
    if (previous != null &&
        e.timeStamp - previous.time < const Duration(milliseconds: 300) &&
        (e.localPosition - previous.at).distance < 24) {
      previousTap = null;
      onDoubleTap(e.localPosition);
    } else {
      previousTap = (at: e.localPosition, time: e.timeStamp);
    }
  }

  void onDoubleTap(Offset at) {
    if (dims.isEmpty) return;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setZoom(
      zoom.zoomTo(
        at.dx,
        at.dy,
        shift ? zoom.k / 2 : zoom.k * 2,
        dims.width,
        dims.height,
      ),
    );
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final d = widget.data;
    if (d.humans.isEmpty && d.agents.isEmpty && d.channels.isEmpty) {
      return _EmptyState(
        label: raftText(context, 'No members or channels to map yet.'),
      );
    }
    final m = model;
    final width = MediaQuery.sizeOf(context).width;
    final svgHeight = width >= 768 ? 520.0 : 360.0;
    final border = 1.0;
    // `rounded-md border border-line-muted bg-layer-panel shadow-raft-sm
    // theme-brutal:border-2 theme-brutal:border-black theme-brutal:rounded-none
    // theme-brutal:bg-white theme-brutal:shadow-brutal-sm`
    return Container(
      key: const ValueKey('member-graph-canvas'),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: t.colors['layer-panel'],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.colors['line-muted']!, width: border),
        boxShadow: t.themeShadows.sm.outer,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // `getBoundingClientRect` of the bordered container.
          dims = Size(box.maxWidth + border * 2, svgHeight + border * 2);
          final size = Size(box.maxWidth, svgHeight);
          final vb = raftGraphViewBox(zoom, dims.width, dims.height);
          return Semantics(
            label: raftText(context, 'Server member connection graph'),
            image: true,
            child: Listener(
              onPointerSignal: onScroll,
              onPointerDown: onPointerDown,
              onPointerUp: onPointerUp,
              // `touch-none`: the graph takes the drag before the page scroll.
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  _EagerScaleRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _EagerScaleRecognizer
                      >(_EagerScaleRecognizer.new, (r) {
                        r
                          ..onStart = onScaleStart
                          ..onUpdate = onScaleUpdate
                          ..onEnd = onScaleEnd;
                      }),
                },
                child: RaftHoverRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: m == null
                        ? null
                        : Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _EdgePainter(
                                      links: m.links,
                                      positions: m.layout.positions,
                                      dense: m.dense,
                                      viewBox: vb,
                                      color: t.colors['line-strong']!,
                                    ),
                                  ),
                                ),
                              ),
                              for (final member in m.members)
                                _node(context, t, m, member),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _node(
    BuildContext context,
    RaftTokens t,
    _Model m,
    RaftGraphMember member,
  ) {
    final p = m.layout.positions[member.key];
    if (p == null) return const SizedBox.shrink();
    // `left = transform.x + x / 920 * width * k`
    final left = zoom.x + p.x / raftGraphViewBoxWidth * dims.width * zoom.k;
    final top = zoom.y + p.y / raftGraphViewBoxHeight * dims.height * zoom.k;
    const half = raftGraphNodeSize / 2;
    Widget circle = Container(
      key: ValueKey('member-graph-node-${member.key}'),
      width: raftGraphNodeSize,
      height: raftGraphNodeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // `var(--info-soft)` / `var(--secondary-400)`: only Brutal declares
        // secondary-400 (the lavender); elsewhere the var is unset.
        color: member.agent ? t.colors['info-soft'] : null,
        border: Border.all(color: t.colors['line-muted']!),
      ),
      child: ClipOval(child: widget.avatar(context, member, compact: false)),
    );
    final wrapper = widget.nodeWrapper;
    if (wrapper != null) circle = wrapper(context, member, circle);
    final degree = m.layout.degrees[member.key] ?? 0;
    return Positioned(
      left: left - half,
      top: top - half,
      width: raftGraphNodeSize,
      height: raftGraphNodeSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: circle),
          _label(context, t, member, degree, m.dense),
        ],
      ),
    );
  }

  /// The node label (`pointer-events-none absolute whitespace-nowrap
  /// text-[12px] font-bold`): below the node, or beside it when dense.
  Widget _label(
    BuildContext context,
    RaftTokens t,
    RaftGraphMember member,
    int degree,
    bool dense,
  ) {
    final name = raftGraphShortLabel(member.label, dense ? 12 : 16);
    final strong = t.strong;
    final nameStyle = TextStyle(
      fontFamily: t.headingFont,
      fontFamilyFallback: t.fontFallback,
      fontSize: 12,
      // `text-[12px]` carries no line-height: the page's 1.5 applies.
      height: 18 / 12,
      fontWeight: FontWeight.w700,
      color: strong,
      leadingDistribution: TextLeadingDistribution.even,
    );
    Widget line(String s, TextAlign align) => RaftCssText(
      s,
      maxLines: 1,
      softWrap: false,
      textAlign: align,
      style: nameStyle,
    );
    const box = 240.0;
    if (!dense) {
      return Positioned(
        left: raftGraphNodeSize / 2 - box / 2,
        width: box,
        top: raftGraphNodeSize + 4,
        child: IgnorePointer(
          child: Column(
            children: [
              line(name, TextAlign.center),
              RaftCssText(
                raftFormat(
                  context,
                  degree == 1 ? '{count} link' : '{count} links',
                  {'count': degree},
                ),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: t.monoFont,
                  fontFamilyFallback: t.fontFallback,
                  fontSize: 10,
                  height: 15 / 10,
                  color: t.colors['foreground-muted'],
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // `right-full top-1/2 -translate-y-1/2 pr-2 text-right` (agents) /
    // `left-full top-1/2 -translate-y-1/2 pl-2` (humans).
    return Positioned(
      left: member.agent ? -box : raftGraphNodeSize,
      width: box,
      top: raftGraphNodeSize / 2 - 9,
      height: 18,
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.only(
            left: member.agent ? 0 : 8,
            right: member.agent ? 8 : 0,
          ),
          child: line(name, member.agent ? TextAlign.right : TextAlign.left),
        ),
      ),
    );
  }
}

/// Claims the arena on the first pointer, like `touch-action: none` keeps the
/// browser from scrolling under a d3-zoom surface.
class _EagerScaleRecognizer extends ScaleGestureRecognizer {
  _EagerScaleRecognizer();
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// `flex min-h-[320px] items-center justify-center border-2 border-dashed
/// border-line-muted theme-brutal:border-black/30 bg-layer-panel
/// theme-brutal:bg-white text-sm font-bold text-foreground-placeholder
/// theme-brutal:text-black/40`.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final color = t.colors['line-muted']!;
    return CustomPaint(
      key: const ValueKey('member-graph-empty'),
      foregroundPainter: _DashedBorderPainter(color: color, width: 2),
      child: Container(
        constraints: const BoxConstraints(minHeight: 320),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(2),
        color: t.colors['layer-panel'],
        child: RaftCssText(
          label,
          style: TextStyle(
            fontFamily: t.headingFont,
            fontFamilyFallback: t.fontFallback,
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w700,
            color: t.colors['foreground-placeholder'],
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.width});
  final Color color;
  final double width;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final r = Rect.fromLTWH(
      width / 2,
      width / 2,
      size.width - width,
      size.height - width,
    );
    // CSS `dashed`: dashes of 2 * width with gaps of the same length.
    final dash = width * 3, gap = width * 3;
    void edge(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var at = 0.0; at < len; at += dash + gap) {
        canvas.drawLine(
          a + dir * at,
          a + dir * math.min(at + dash, len),
          paint,
        );
      }
    }

    edge(r.topLeft, r.topRight);
    edge(r.topRight, r.bottomRight);
    edge(r.bottomRight, r.bottomLeft);
    edge(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.width != width;
}

/// The SVG edge layer: `<g opacity>` of fill-less paths under the viewBox
/// `preserveAspectRatio="xMidYMid meet"` mapping, with non-scaling strokes.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.links,
    required this.positions,
    required this.dense,
    required this.viewBox,
    required this.color,
  });
  final List<RaftGraphLink> links;
  final Map<String, RaftGraphPoint> positions;
  final bool dense;
  final ({double x, double y, double width, double height}) viewBox;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / viewBox.width,
      size.height / viewBox.height,
    );
    final ox = (size.width - viewBox.width * scale) / 2;
    final oy = (size.height - viewBox.height * scale) / 2;
    Offset map(RaftGraphPoint p) =>
        Offset((p.x - viewBox.x) * scale + ox, (p.y - viewBox.y) * scale + oy);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // `<g opacity="0.16|0.34">`: the group composites once, so overlapping
    // edges do not darken each other.
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Color.fromRGBO(0, 0, 0, dense ? 0.16 : 0.34),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..isAntiAlias = true;
    for (final link in links) {
      final a = positions[link.source], b = positions[link.target];
      if (a == null || b == null) continue;
      paint.strokeWidth = dense
          ? math.min(1.8, 0.55 + link.weight * 0.2)
          : math.min(3, 1.1 + link.weight * 0.35);
      final from = map(a), to = map(b);
      if (!dense) {
        canvas.drawLine(from, to, paint);
        continue;
      }
      // `edgePath`: a cubic with horizontal handles.
      final curve = (b.x - a.x).abs() * 0.48;
      final c1 = a.x < b.x ? a.x + curve : a.x - curve;
      final c2 = a.x < b.x ? b.x - curve : b.x + curve;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(
          map(RaftGraphPoint(c1, a.y)).dx,
          from.dy,
          map(RaftGraphPoint(c2, b.y)).dx,
          to.dy,
          to.dx,
          to.dy,
        );
      canvas.drawPath(path, paint);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.viewBox != viewBox ||
      old.color != color ||
      old.dense != dense ||
      !identical(old.links, links) ||
      !identical(old.positions, positions);
}
