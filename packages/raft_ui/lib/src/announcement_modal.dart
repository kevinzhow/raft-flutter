// Web account-level announcement popup (packages/web/src/components/
// AnnouncementModal.tsx, v1.21.12): raft-ui's `AnnouncementDialog` (wip) on
// `layer={1}` holding a label row with the close button, the title, an
// optional picture, the Markdown of the first page and a footer with one
// primary action ("Got it", or the CTA label) next to an optional "Got it"
// link.
//
// Presentation and the dialog's own keyboard contract only; loading, the
// dismiss write, the CTA navigation and when it is shown belong to the app.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'announcement_markdown.dart';
import 'dialog_card.dart';
import 'localization.dart';
import 'overlays/dialog.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'sized_image.dart';
import 'theme.dart';

/// The announcement's picture (`image { assetId, alt }`): [url] is the public
/// `GET /announcements/images/:id`.
@immutable
class RaftAnnouncementImage {
  const RaftAnnouncementImage({required this.url, required this.alt});
  final String url, alt;
}

/// Copy of the Web `common.announcement.*` messages (en / zh-cn).
@immutable
class RaftAnnouncementLabels {
  const RaftAnnouncementLabels({
    required this.dismiss,
    required this.gotIt,
    required this.latestUpdates,
  });

  /// `common.announcement.*` in the [context] locale.
  factory RaftAnnouncementLabels.of(BuildContext context) =>
      RaftAnnouncementLabels(
        dismiss: raftText(context, 'Dismiss'),
        gotIt: raftText(context, 'Got it'),
        latestUpdates: raftText(context, 'Latest updates'),
      );

  final String dismiss, gotIt, latestUpdates;
}

/// The whole Web dialog content (the route supplies the scrim).
///
/// * The primary button reads [ctaLabel] and calls [onCta] when the
///   announcement has a CTA, else it reads "Got it" and calls [onDismiss].
///   With a CTA a "Got it" link beside it calls [onDismiss].
/// * ✕, Escape and a press on the scrim dismiss (closing counts as read).
/// * Enter acts like the primary button wherever focus is in the dialog (Web:
///   a capture-phase window listener, so a focused link does not swallow it).
/// * The primary button takes focus when the dialog opens.
///
/// Key the widget by announcement id so a new announcement starts fresh.
class RaftAnnouncementModal extends StatefulWidget {
  const RaftAnnouncementModal({
    super.key,
    required this.title,
    required this.body,
    required this.onDismiss,
    this.label,
    this.image,
    this.ctaLabel,
    this.onCta,
    this.labels,
    this.onLink,
  }) : assert(ctaLabel == null || onCta != null);

  final String title;

  /// Markdown (GFM) of the first page.
  final String body;

  /// Eyebrow beside the dot; null reads "Latest updates".
  final String? label;
  final RaftAnnouncementImage? image;
  final String? ctaLabel;
  final VoidCallback onDismiss;
  final VoidCallback? onCta;
  final RaftAnnouncementLabels? labels;
  final ValueChanged<String>? onLink;

  @override
  State<RaftAnnouncementModal> createState() => _RaftAnnouncementModalState();
}

class _RaftAnnouncementModalState extends State<RaftAnnouncementModal> {
  final primary = FocusNode(debugLabel: 'announcement-primary');

  /// Web focuses the action on open (`:focus-visible`); the ring stays while
  /// that button keeps focus, including after it is clicked.
  bool ring = true;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    primary.addListener(_primaryFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) primary.requestFocus();
    });
  }

  void _primaryFocus() {
    if (_hadFocus && !primary.hasFocus && ring) setState(() => ring = false);
    _hadFocus = primary.hasFocus;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    primary.removeListener(_primaryFocus);
    primary.dispose();
    super.dispose();
  }

  bool get _hasCta => widget.ctaLabel != null;
  void _primaryAction() => _hasCta ? widget.onCta!() : widget.onDismiss();

  /// Sees every key from inside the dialog before the app's activation
  /// shortcuts, so a focused link does not swallow Enter.
  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _primaryAction();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.labels ?? RaftAnnouncementLabels.of(context);
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _key,
      child: RaftAnnouncementCard(
        title: widget.title,
        body: widget.body,
        label: widget.label ?? labels.latestUpdates,
        image: widget.image,
        labels: labels,
        ctaLabel: widget.ctaLabel,
        onDismiss: widget.onDismiss,
        onPrimary: _primaryAction,
        primaryFocusNode: primary,
        primaryFocusRing: ring,
        onLink: widget.onLink,
      ),
    );
  }
}

/// The dialog content: `AnnouncementDialogContent` (`max-w-xl gap-0
/// overflow-clip p-0`) with its body and footer slots.
class RaftAnnouncementCard extends StatelessWidget {
  const RaftAnnouncementCard({
    super.key,
    required this.title,
    required this.body,
    required this.label,
    required this.labels,
    required this.onDismiss,
    required this.onPrimary,
    this.image,
    this.ctaLabel,
    this.primaryFocusNode,
    this.primaryFocusRing = false,
    this.onLink,
  });

  final String title, body, label;
  final RaftAnnouncementImage? image;
  final String? ctaLabel;
  final RaftAnnouncementLabels labels;
  final VoidCallback onDismiss, onPrimary;
  final FocusNode? primaryFocusNode;

  /// The primary action was focused by the dialog on open and still is.
  final bool primaryFocusRing;
  final ValueChanged<String>? onLink;

  /// `max-w-xl` (36rem).
  static const maxWidth = 576.0;

  /// `@max-[28rem]/announcement`: below it the footer stacks.
  static const stackBelow = 448.0;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rt = t.recipeTokens;
    final slots = RaftDialogSlots.of(context);
    final media = MediaQuery.of(context);
    // `w-[calc(100%-2rem)] max-w-xl max-h-[calc(100dvh-2rem)]`.
    final width = math.min(maxWidth, math.max(0.0, media.size.width - 32));
    final maxHeight = math.max(
      0.0,
      media.size.height - 32 - media.viewInsets.bottom,
    );
    final ink = t.semantic.foreground;
    final titleStyle = slots.title
        .text(rt)
        .copyWith(
          // `text-2xl font-bold tracking-tight normal-case`.
          color: ink,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          leadingDistribution: TextLeadingDistribution.even,
        );
    final bodyStyle = raftCssTextStyle(
      family: t.bodyFont,
      step: (14, 22.75), // text-sm/relaxed
      color: ink,
    ).copyWith(fontFamilyFallback: t.fontFallback);
    final rule = BorderSide(
      color: t.brutal ? t.semantic.lineStrong : t.semantic.lineMuted,
      width: t.brutal ? 2 : 1,
    );
    final picture = image;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * .7),
            child: SingleChildScrollView(
              key: const ValueKey('announcement-body'),
              // `px-7 pt-6 pb-5`.
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    key: const ValueKey('announcement-header'),
                    children: [
                      Expanded(child: _Label(label)),
                      const SizedBox(width: 12),
                      RaftDialogClose(
                        onPressed: onDismiss,
                        semanticLabel: labels.dismiss,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: RaftCssText(
                      title,
                      key: const ValueKey('announcement-title'),
                      style: titleStyle,
                    ),
                  ),
                  if (picture != null) ...[
                    const SizedBox(height: 20),
                    _Picture(picture),
                  ],
                  // `mt-3`, `mt-5` right after the picture.
                  SizedBox(height: picture == null ? 12 : 20),
                  DefaultTextStyle(
                    key: const ValueKey('announcement-page-body'),
                    style: bodyStyle,
                    child: RaftAnnouncementMarkdown(body, onLink: onLink),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          key: const ValueKey('announcement-footer'),
          // `border-t px-7 py-4`.
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(border: Border(top: rule)),
          child: _Footer(
            secondary: ctaLabel == null
                ? null
                : RaftRecipeButton(
                    key: const ValueKey('announcement-dismiss'),
                    variant: RaftButtonRecipeVariant.link,
                    size: RaftButtonRecipeSize.md,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    autoHeight: true,
                    underline: true,
                    label: labels.gotIt,
                    onPressed: onDismiss,
                  ),
            primary: RaftRecipeButton(
              key: const ValueKey('announcement-ok'),
              variant: RaftButtonRecipeVariant.accent,
              size: RaftButtonRecipeSize.md,
              autoHeight: true,
              fontWeight: FontWeight.w700,
              focusNode: primaryFocusNode,
              focusRing: primaryFocusRing,
              label: ctaLabel ?? labels.gotIt,
              onPressed: onPrimary,
            ),
          ),
        ),
      ],
    );
    return Center(
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
          child: SizedBox(
            width: width,
            child: Material(
              type: MaterialType.transparency,
              child: RaftRecipeBox(
                key: const ValueKey('announcement-modal'),
                style: slots.content,
                tokens: rt,
                width: width,
                // `p-0 gap-0` over the dialog recipe's padding and gap.
                padding: EdgeInsets.zero,
                clip: !t.brutal,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `AnnouncementDialogLabel`: `flex items-center gap-2 text-xs
/// text-foreground-muted` with a `size-1.5 rounded-full bg-accent` dot.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: t.colors['accent'],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RaftCssText(
            text,
            key: const ValueKey('announcement-label'),
            style: raftCssTextStyle(
              family: t.bodyFont,
              step: RaftTextSteps.xs,
              color: t.semantic.foregroundMuted,
            ).copyWith(fontFamilyFallback: t.fontFallback),
          ),
        ),
      ],
    );
  }
}

/// `AnnouncementDialogPicture`: `h-44 w-full overflow-hidden border
/// border-line-muted` (brutal `border-2 border-line-strong`, elegant
/// `rounded-lg`) with the image `object-contain`.
class _Picture extends StatelessWidget {
  const _Picture(this.image);
  final RaftAnnouncementImage image;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final border = Border.all(
      color: t.brutal ? t.semantic.lineStrong : t.semantic.lineMuted,
      width: t.brutal ? 2 : 1,
    );
    final radius = t.brutal ? BorderRadius.zero : BorderRadius.circular(8);
    return Container(
      key: const ValueKey('announcement-picture'),
      height: 176,
      decoration: BoxDecoration(border: border, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) => RaftSizedImage.network(
          image.url,
          width: box.maxWidth,
          height: box.maxHeight,
          fit: BoxFit.contain,
          semanticLabel: image.alt,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// `AnnouncementDialogFooter`: `flex flex-wrap items-center justify-between
/// gap-3`; the actions are `ml-auto` (right) and, in a container narrower
/// than 28rem, `flex-col` with `w-full` actions.
class _Footer extends MultiChildRenderObjectWidget {
  _Footer({required Widget? secondary, required Widget primary})
    : super(children: [?secondary, primary]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFooter();
}

class _FooterParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFooter extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FooterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FooterParentData> {
  static const _gap = 12.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterParentData) {
      child.parentData = _FooterParentData();
    }
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    for (var c = firstChild; c != null; c = childAfter(c)) {
      out.add(c);
    }
    return out;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final width = constraints.maxWidth;
    final children = _children;
    Size measure(RenderBox c, BoxConstraints box) =>
        dry ? c.getDryLayout(box) : (c..layout(box, parentUsesSize: true)).size;
    void place(RenderBox c, Offset offset) {
      if (!dry) (c.parentData! as _FooterParentData).offset = offset;
    }

    // The query measures the dialog's content box: the footer plus its `px-7`.
    if (width + 2 * 28 < stackBelow) {
      // flex-col: every action `w-full`.
      var y = 0.0;
      for (final c in children) {
        final s = measure(c, BoxConstraints.tightFor(width: width));
        place(c, Offset(0, y));
        y += s.height + _gap;
      }
      return constraints.constrain(Size(width, y - _gap));
    }
    final loose = BoxConstraints(maxWidth: width);
    final sizes = [for (final c in children) measure(c, loose)];
    final total =
        sizes.fold<double>(0, (sum, s) => sum + s.width) +
        _gap * (sizes.length - 1);
    if (total <= width) {
      // One row: the first action at the start, the last `ml-auto`.
      final height = sizes.fold<double>(0, (m, s) => math.max(m, s.height));
      for (var i = 0; i < children.length; i++) {
        final x = i == 0 && children.length > 1 ? 0.0 : width - sizes[i].width;
        place(children[i], Offset(x, (height - sizes[i].height) / 2));
      }
      return constraints.constrain(Size(width, height));
    }
    // flex-wrap: one action per line, each `ml-auto` after the first.
    var y = 0.0;
    for (var i = 0; i < children.length; i++) {
      final x = i == 0 && children.length > 1 ? 0.0 : width - sizes[i].width;
      place(children[i], Offset(x, y));
      y += sizes[i].height + _gap;
    }
    return constraints.constrain(Size(width, y - _gap));
  }

  static const stackBelow = RaftAnnouncementCard.stackBelow;

  @override
  double computeMinIntrinsicHeight(double width) =>
      getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
