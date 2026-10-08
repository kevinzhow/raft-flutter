import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'design_primitives.dart';
import 'primitive_tokens.dart';
import 'theme.dart';

/// ThreadPanelContent applies its own descendant padding below lg.
enum RaftMessageRowContext { main, thread }

/// Pinned raft-ui 0.5.27 MessageItem plus mounted MessageItem.tsx overrides.
/// The adapter owns identity, grouping, pointer capability, and permissions.
@immutable
class RaftMessageRowRecipe {
  const RaftMessageRowRecipe(
    this.tokens, {
    required this.viewportWidth,
    this.rowContext = RaftMessageRowContext.main,
    this.continuation = false,
    this.nextContinuation = false,
    this.hovered = false,
    this.focused = false,
    this.popupOpen = false,
    this.highlighted = false,
  });
  final RaftTokens tokens;
  final double viewportWidth;
  final RaftMessageRowContext rowContext;
  final bool continuation, nextContinuation, hovered, focused, popupOpen;
  final bool highlighted;
  bool get mobile => viewportWidth < 768;
  double get horizontalPadding =>
      rowContext == RaftMessageRowContext.thread && viewportWidth < 1024
      ? 12
      : mobile
      ? 16
      : 28;
  bool get attention => hovered || popupOpen;
  bool get toolbarVisible => hovered || focused || popupOpen;
  double get borderWidth => tokens.brutal ? 2 : 1;
  double get minimumHeight => continuation ? 0 : 48;
  EdgeInsets get margin => tokens.brutal
      ? EdgeInsets.fromLTRB(12, continuation ? 0 : 6, 12, 4)
      : EdgeInsets.zero;
  EdgeInsets get padding => tokens.brutal
      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
      : EdgeInsets.fromLTRB(
          horizontalPadding,
          continuation
              ? 6
              : mobile
              ? 8
              : 14,
          horizontalPadding,
          continuation
              ? 6
              : nextContinuation
              ? (mobile ? 0 : 2)
              : (mobile ? 6 : 12),
        );
  double get gutterWidth => tokens.brutal || !mobile ? 36 : 32;
  double get avatarExtent => 36; // AvatarSlot(panel-header): !size-9 !border-2.
  double get avatarTop =>
      2; // MessageSenderAvatar: mt-0.5; flex slot avoids baseline drift.
  double get gap => tokens.brutal || !mobile ? 12 : 8;
  double get headerReserve => 96;
  double get headerGap => tokens.brutal ? 8 : 6;
  double get headerLine => tokens.brutal ? 20 : 21;
  double get bodyGap => tokens.brutal || continuation
      ? 0
      : mobile
      ? 4
      : 6;
  double get attachmentGap => 4;
  double get footerGap =>
      6; // Mounted MessageItemFooter overrides generic Elegant desktop mt10.
  double get toolbarTop => tokens.brutal ? -14 : 4;
  double get toolbarRight => tokens.brutal ? 8 : 29;
  double get toolbarButtonExtent => tokens.brutal ? 24 : 28;
  double get toolbarGap => tokens.brutal ? 0 : 2;
  EdgeInsets get toolbarPadding => tokens.brutal
      ? EdgeInsets.zero
      : const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
  Color get background => highlighted
      ? tokens.colors[tokens.brutal ? 'color-brutal-cyan' : 'info']!.withValues(
          alpha: tokens.brutal ? .25 : .1,
        )
      : attention
      ? (tokens.brutal ? tokens.panel : tokens.colors['ink-2']!)
      : Colors.transparent;
  Color get border => tokens.brutal && attention
      ? (popupOpen ? RaftPrimitives.rgbaff000000 : tokens.strong)
      : Colors.transparent;
  TextStyle get body => TextStyle(
    // Mounted host uses font-display, not Elegant's generic font-sans (Geist).
    fontFamily: tokens.headingFont,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: tokens.brutal ? 0 : -.14,
    color: tokens.brutal ? RaftPrimitives.rgbaff000000 : tokens.muted,
  );
  TextStyle get author => body.copyWith(
    height: tokens.brutal ? 20 / 14 : 1,
    fontWeight: tokens.brutal ? FontWeight.w700 : FontWeight.w500,
  );
  TextStyle get time => TextStyle(
    fontFamily: tokens.brutal ? tokens.monoFont : tokens.bodyFont,
    fontSize: 12,
    height: tokens.brutal ? 16 / 12 : 1,
    letterSpacing: tokens.brutal ? 0 : -.14,
    color: tokens.brutal
        ? RaftPrimitives.rgbaff000000.withValues(alpha: .4)
        : tokens.muted.withValues(alpha: tokens.muted.a * .7),
  );
  TextStyle get continuationTime => TextStyle(
    fontFamily: tokens.monoFont,
    fontSize: 10,
    height: 1,
    color: hovered
        ? (tokens.brutal
              ? RaftPrimitives.rgbaff000000.withValues(alpha: .4)
              : tokens.colors['foreground-placeholder']!)
        : Colors.transparent,
  );
  BoxDecoration get decoration => BoxDecoration(
    color: background,
    border: Border.all(color: border, width: borderWidth),
    boxShadow: tokens.brutal && (highlighted || popupOpen)
        ? [
            // Mounted index.css91–92 overrides the generic RUI elevation.
            BoxShadow(
              color: RaftPrimitives.rgbaff141111,
              offset: Offset(highlighted ? 4 : 2, highlighted ? 4 : 2),
            ),
          ]
        : null,
  );
  BoxDecoration? get highlightRing => highlighted
      ? BoxDecoration(
          border: Border.all(
            color: tokens.colors['info']!.withValues(alpha: .5),
            width: 1,
          ),
        )
      : null;
  BoxDecoration get toolbarDecoration => BoxDecoration(
    color: tokens.panel,
    border: Border.all(
      color: tokens.brutal
          ? tokens.strong
          : tokens.dark
          ? Colors.transparent
          : tokens.colors['line-muted']!,
      width: tokens.brutal ? 2 : .5,
    ),
    borderRadius: BorderRadius.circular(tokens.brutal ? 0 : 8),
    boxShadow: tokens.brutal || tokens.dark
        ? tokens.shadows
        : const [
            // foundation.css360: --theme-shadow-xs, original OKLCH atom resolved to sRGB.
            BoxShadow(color: Color(0x120a0a09), offset: Offset(0, .5)),
          ],
  );
}

/// Controlled mounted row. No message model, cache, API, or authority lookup.
/// Toolbar stays hit-testable above the row while invisible, as source does.
class RaftMessageRow extends StatefulWidget {
  const RaftMessageRow({
    super.key,
    required this.author,
    required this.timestamp,
    required this.content,
    this.avatar,
    this.metadata,
    this.subtitle,
    this.attachments,
    this.footer,
    this.inlineReplies,
    this.toolbar,
    this.onAuthor,
    this.onActions,
    this.onTap,
    this.rowContext = RaftMessageRowContext.main,
    this.continuation = false,
    this.nextContinuation = false,
    this.coarsePointer = false,
    this.popupOpen = false,
    this.highlighted = false,
  });
  final String author, timestamp;
  final RaftMessageRowContext rowContext;
  final Widget content;
  final Widget? avatar, metadata, attachments, footer, inlineReplies, toolbar;
  final String? subtitle;
  final VoidCallback? onAuthor, onActions, onTap;
  final bool continuation,
      nextContinuation,
      coarsePointer,
      popupOpen,
      highlighted;
  @override
  State<RaftMessageRow> createState() => _RaftMessageRowState();
}

class _RaftMessageRowState extends State<RaftMessageRow> {
  bool hovered = false, toolbarHovered = false, focused = false;
  final portal = OverlayPortalController()..show();
  ScrollPosition? position;
  bool overlayUpdateQueued = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != position) {
      position?.removeListener(scrollChanged);
      position = next;
      position?.addListener(scrollChanged);
    }
  }

  void scrollChanged() {
    // Scroll corrections can occur during layout. Coalesce a current-frame
    // overlay refresh rather than writing state from that layout callback.
    if (overlayUpdateQueued) return;
    overlayUpdateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      overlayUpdateQueued = false;
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RaftMessageRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coarsePointer || widget.toolbar == null) toolbarHovered = false;
  }

  @override
  void dispose() {
    position?.removeListener(scrollChanged);
    super.dispose(); // OverlayPortal removes its owned overlay on unmount.
  }

  Widget overlay(
    BuildContext overlayContext,
    OverlayChildLayoutInfo info,
    RaftMessageRowRecipe recipe,
  ) {
    var viewport = Offset.zero & info.overlaySize;
    final scrollBox = Scrollable.maybeOf(context)?.context.findRenderObject();
    final overlayBox = Overlay.of(context).context.findRenderObject();
    if (scrollBox is RenderBox &&
        scrollBox.hasSize &&
        overlayBox is RenderBox) {
      viewport = viewport.intersect(
        MatrixUtils.transformRect(
          scrollBox.getTransformTo(overlayBox),
          Offset.zero & scrollBox.size,
        ),
      );
    }
    final row = MatrixUtils.transformRect(
      info.childPaintTransform,
      Offset.zero & info.childSize,
    );
    if (row.width <= 0 ||
        row.bottom <= viewport.top ||
        row.top >= viewport.bottom) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: ClipRect(
        clipper: _MessageToolbarClip(viewport),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: row.top + recipe.toolbarTop,
              right: info.overlaySize.width - row.right + recipe.toolbarRight,
              child: MouseRegion(
                onEnter: (_) {
                  if (!toolbarHovered) setState(() => toolbarHovered = true);
                },
                onExit: (_) {
                  if (toolbarHovered) setState(() => toolbarHovered = false);
                },
                child: ExcludeSemantics(
                  excluding: !recipe.toolbarVisible,
                  child: IgnorePointer(
                    ignoring: !recipe.toolbarVisible,
                    child: Opacity(
                      opacity: recipe.toolbarVisible ? 1 : 0,
                      child: widget.toolbar!,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget portalBody(
    BuildContext context,
    RaftMessageRowRecipe recipe,
    Widget child,
  ) {
    if (widget.coarsePointer ||
        widget.toolbar == null ||
        !TickerMode.valuesOf(context).enabled) {
      return child;
    }
    // Detachment clears the controller visibility. A re-enabled retained row
    // owns a newly mounted portal, which must reopen explicitly.
    if (!portal.isShowing) portal.show();
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: portal,
      overlayChildBuilder: (context, info) => overlay(context, info, recipe),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = RaftMessageRowRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
      rowContext: widget.rowContext,
      continuation: widget.continuation,
      nextContinuation: widget.nextContinuation,
      hovered: hovered || toolbarHovered,
      focused: focused,
      popupOpen: widget.popupOpen,
      highlighted: widget.highlighted,
    );
    final author = widget.onAuthor == null
        ? Text(
            widget.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: recipe.author,
          )
        : RaftControl(
            onPressed: widget.onAuthor,
            kind: RaftControlKind.textLink,
            shadow: false,
            visualHeight: recipe.tokens.brutal ? 20 : 14,
            minimumTargetSize: 0,
            padding: EdgeInsets.zero,
            child: Text(
              widget.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: recipe.author,
            ),
          );
    final header = ClipRect(
      child: _MessageHeader(
        lineHeight: recipe.headerLine,
        reserve: recipe.headerReserve,
        gap: recipe.headerGap,
        baseline: !recipe.tokens.brutal,
        subtitleIndex: widget.subtitle != null && widget.subtitle!.isNotEmpty
            ? (widget.metadata == null ? 1 : 2)
            : null,
        children: [
          author,
          if (widget.metadata != null)
            SizedBox(
              height: recipe.headerLine,
              child: Align(
                alignment: Alignment.centerLeft,
                child: widget.metadata!,
              ),
            ),
          if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
            Text(
              widget.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: recipe.time,
            ),
          Text(
            widget.timestamp,
            maxLines: 1,
            softWrap: false,
            style: recipe.time,
          ),
        ],
      ),
    );
    return Focus(
      canRequestFocus: false,
      onFocusChange: (value) {
        if (focused != value) setState(() => focused = value);
      },
      child: MouseRegion(
        onEnter: (_) {
          if (!hovered) setState(() => hovered = true);
        },
        onExit: (_) {
          if (hovered) setState(() => hovered = false);
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onActions,
          onSecondaryTap: widget.onActions,
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: recipe.margin,
            child: Container(
              constraints: BoxConstraints(minHeight: recipe.minimumHeight),
              decoration: recipe.decoration,
              foregroundDecoration: recipe.highlightRing,
              child: portalBody(
                context,
                recipe,
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: recipe.padding,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: recipe.gutterWidth,
                            height: widget.continuation
                                ? 14
                                : recipe.avatarExtent + recipe.avatarTop,
                            child: widget.continuation
                                ? Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        right: 4,
                                        top: 4,
                                        child: Text(
                                          widget.timestamp,
                                          style: recipe.continuationTime,
                                        ),
                                      ),
                                    ],
                                  )
                                : Padding(
                                    padding: EdgeInsets.only(
                                      top: recipe.avatarTop,
                                    ),
                                    child: OverflowBox(
                                      alignment: Alignment.topLeft,
                                      minWidth: recipe.avatarExtent,
                                      maxWidth: recipe.avatarExtent,
                                      minHeight: recipe.avatarExtent,
                                      maxHeight: recipe.avatarExtent,
                                      child: SizedBox.square(
                                        dimension: recipe.avatarExtent,
                                        child: widget.avatar,
                                      ),
                                    ),
                                  ),
                          ),
                          SizedBox(width: recipe.gap),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!widget.continuation) header,
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: recipe.bodyGap,
                                  ),
                                  child: DefaultTextStyle.merge(
                                    style: recipe.body,
                                    child: widget.content,
                                  ),
                                ),
                                if (widget.attachments != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: recipe.attachmentGap,
                                    ),
                                    child: widget.attachments!,
                                  ),
                                if (widget.footer != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      // Source block margins collapse: body
                                      // bottom6 + footer top6 paint one6 gap.
                                      top: widget.attachments == null
                                          ? (recipe.footerGap - recipe.bodyGap)
                                                .clamp(0.0, double.infinity)
                                          : recipe.footerGap,
                                    ),
                                    child: widget.footer!,
                                  ),
                                if (widget.inlineReplies != null)
                                  widget.inlineReplies!,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Source action-strip frame; its children are permission-controlled actions.
class RaftMessageToolbar extends StatelessWidget {
  const RaftMessageToolbar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final recipe = RaftMessageRowRecipe(
      RaftTokens.of(context),
      viewportWidth: MediaQuery.sizeOf(context).width,
    );
    return Container(
      decoration: recipe.toolbarDecoration,
      padding: recipe.toolbarPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: recipe.toolbarGap),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Fine-pointer toolbar action. Icon geometry remains a caller-supplied slot,
/// so missing source ThreadIcon/SmilePlus paths cannot silently become Material glyphs.
class RaftMessageToolbarAction extends StatelessWidget {
  const RaftMessageToolbarAction({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.active = false,
    this.popupOpen = false,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool active, popupOpen;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final extent = t.brutal ? 24.0 : 28.0;
    return RaftControl(
      onPressed: onPressed,
      tooltip: label,
      semanticLabel: label,
      visualHeight: extent,
      visualWidth: extent,
      minimumTargetSize: extent,
      padding: EdgeInsets.zero,
      shadow: true,
      recipe: _MessageActionRecipe(t, active: active, popupOpen: popupOpen),
      child: SizedBox.square(dimension: 13, child: icon),
    );
  }
}

class _MessageActionRecipe extends RaftControlRecipe {
  const _MessageActionRecipe(
    super.tokens, {
    required this.active,
    required this.popupOpen,
  }) : super(variant: RaftControlVariant.ghost);
  final bool active, popupOpen;
  @override
  bool get transformsOnInteraction => false;
  @override
  BorderRadius get radius => BorderRadius.circular(tokens.brutal ? 0 : 6);
  @override
  Color get foreground => foregroundFor();
  @override
  Color foregroundFor({bool hovered = false}) => active
      ? tokens.colors[tokens.brutal ? 'color-brutal-orange' : 'accent-strong']!
      : tokens.brutal
      ? RaftPrimitives.rgbaff000000.withValues(
          alpha: hovered || popupOpen ? 1 : .5,
        )
      : hovered || popupOpen
      ? tokens.strong
      : tokens.colors['foreground-icon']!;
  @override
  Color backgroundFor({bool hovered = false}) => hovered || popupOpen
      ? tokens.brutal
            ? tokens.primaryFill.withValues(alpha: .3)
            : tokens.colors['fill-muted']!
      : Colors.transparent;
  @override
  Color get focusRing =>
      tokens.brutal ? Colors.transparent : tokens.colors['primary-500']!;
  @override
  BorderSide side({bool hovered = false}) =>
      const BorderSide(color: Colors.transparent, width: 0);
  @override
  List<BoxShadow> shadows({
    bool hovered = false,
    bool pressed = false,
    bool focused = false,
  }) => focused && !tokens.brutal
      ? [BoxShadow(color: focusRing, spreadRadius: .5)]
      : const [];
}

class _MessageToolbarClip extends CustomClipper<Rect> {
  const _MessageToolbarClip(this.viewport);
  final Rect viewport;
  @override
  Rect getClip(Size size) => viewport;
  @override
  bool shouldReclip(covariant _MessageToolbarClip oldClipper) =>
      oldClipper.viewport != viewport;
}

// Source flex header keeps sender/model/clock shrink-0. Only description can
// shrink; fixed children may paint into pr-24, clipped at the header boundary.
// A normal constrained Row reports an overflow instead of that CSS behavior.
class _MessageHeader extends MultiChildRenderObjectWidget {
  const _MessageHeader({
    required super.children,
    required this.lineHeight,
    required this.reserve,
    required this.gap,
    required this.baseline,
    required this.subtitleIndex,
  });
  final double lineHeight, reserve, gap;
  final bool baseline;
  final int? subtitleIndex;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageHeader(lineHeight, reserve, gap, baseline, subtitleIndex);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMessageHeader renderObject,
  ) {
    renderObject.update(lineHeight, reserve, gap, baseline, subtitleIndex);
  }
}

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMessageHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  _RenderMessageHeader(
    this.lineHeight,
    this.reserve,
    this.gap,
    this.baseline,
    this.subtitleIndex,
  );
  double lineHeight, reserve, gap;
  bool baseline;
  int? subtitleIndex;
  void update(
    double height,
    double inset,
    double spacing,
    bool alignBaseline,
    int? subtitle,
  ) {
    if (lineHeight == height &&
        reserve == inset &&
        gap == spacing &&
        baseline == alignBaseline &&
        subtitleIndex == subtitle)
      return;
    lineHeight = height;
    reserve = inset;
    gap = spacing;
    baseline = alignBaseline;
    subtitleIndex = subtitle;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData)
      child.parentData = _HeaderParentData();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final sizes = [
      for (final child in getChildrenAsList())
        child.getDryLayout(BoxConstraints(maxHeight: lineHeight)),
    ];
    final height = sizes.fold(
      0.0,
      (value, size) => value > size.height ? value : size.height,
    );
    return constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : 0, height),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => lineHeight;
  @override
  double computeMaxIntrinsicHeight(double width) => lineHeight;
  @override
  void performLayout() {
    final children = getChildrenAsList();
    var fixed = gap * (children.length - 1).clamp(0, children.length);
    final natural = BoxConstraints(maxHeight: lineHeight);
    for (var i = 0; i < children.length; i++) {
      if (i == subtitleIndex) continue;
      children[i].layout(natural, parentUsesSize: true);
      fixed += children[i].size.width;
    }
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : fixed + reserve;
    if (subtitleIndex != null) {
      final remaining = (width - reserve - fixed).clamp(0.0, double.infinity);
      children[subtitleIndex!].layout(
        BoxConstraints(maxWidth: remaining, maxHeight: lineHeight),
        parentUsesSize: true,
      );
    }
    final height = children.fold(
      0.0,
      (value, child) => value > child.size.height ? value : child.size.height,
    );
    size = constraints.constrain(Size(width, height));
    final baselines = [
      for (final child in children)
        child.getDistanceToBaseline(TextBaseline.alphabetic) ??
            child.size.height,
    ];
    final topBaseline = baselines.fold(0.0, (a, b) => a > b ? a : b);
    var x = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      (child.parentData! as _HeaderParentData).offset = Offset(
        x,
        baseline
            ? topBaseline - baselines[i]
            : (size.height - child.size.height) / 2,
      );
      x += child.size.width + gap;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
