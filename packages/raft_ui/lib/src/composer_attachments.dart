// Presentation of the Web MessageInput pending attachments
// (packages/web/src/components/message/MessageInput.tsx: SortableAttachment,
// `<ComposerAttachments>` and the failed-upload alert rows) over the raft-ui
// `composerAttachment` recipe. The app owns the upload lifecycle and passes a
// view model; this file never reads files, network or controllers.
import 'reduced_motion.dart';
import 'hover_region.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'panel_layout.dart' show RaftCssText;
import 'recipes/composer_attachment.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'raft/button.dart' show RaftButton, RaftButtonSize, RaftButtonVariant;
import 'raft/css_box.dart' show raftControlBorderPx;
import 'raft/ui_tokens.dart';
import 'theme.dart';
import 'tokens/tokens.dart' show RaftTypeScale;
import 'tooltip.dart';
import 'sized_image.dart';
import 'reorderable_wrap.dart';

/// Web `PendingFile.uploadStatus`: `validating` is the local selection check
/// that runs before any transfer, `queued` is not shown separately.
enum RaftComposerAttachmentStatus { checking, uploading, ready, failed }

/// One pending file as Web `SortableAttachment` / the failure row shows it.
@immutable
class RaftComposerAttachment {
  const RaftComposerAttachment({
    required this.id,
    required this.name,
    this.mimeType = '',
    this.preview,
    this.status = RaftComposerAttachmentStatus.ready,
    this.progress = 0,
    this.error,
    this.canRetry = true,
    this.quotaBlocked = false,
  });
  final String id, name;

  /// Browser `file.type`; empty falls back to the localized "file".
  final String mimeType;

  /// Bytes of a previewable raster image (Web `preview` object URL), or null
  /// for the file card.
  final Uint8List? preview;
  final RaftComposerAttachmentStatus status;

  /// Whole percent 0..100 (Web `uploadProgress`).
  final int progress;
  final String? error;

  /// Web `uploadCanRetry !== false`.
  final bool canRetry;

  /// Web `isBillingUploadQuotaError`: the failed file stays a chip (with the
  /// failed overlay) and the banner carries the message.
  final bool quotaBlocked;

  /// Failed files except quota errors leave the chip list for an alert row.
  bool get inFailureRow =>
      status == RaftComposerAttachmentStatus.failed && !quotaBlocked;
}

/// Lets a subtree paint and hit-test outside the box it occupies in layout
/// (CSS overflow that is not clipped): the remove badge of a chip sits at
/// `top:-6 right:-6`, and Flutter hit tests stop at the parent's size. The
/// child is laid out [overhang] larger on each affected side and shifted back,
/// so the box taking part in the parent's layout is unchanged while hover and
/// taps reach the overhanging part.
class _Overhang extends SingleChildRenderObjectWidget {
  const _Overhang({required this.overhang, super.child});
  final EdgeInsets overhang;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderOverhang(overhang);
  @override
  void updateRenderObject(BuildContext context, _RenderOverhang renderObject) =>
      renderObject.overhang = overhang;
}

const _overhangInset = EdgeInsets.only(top: 6, right: 6);

class _RenderOverhang extends RenderShiftedBox {
  _RenderOverhang(this._overhang) : super(null);
  EdgeInsets _overhang;
  set overhang(EdgeInsets value) {
    if (value == _overhang) return;
    _overhang = value;
    markNeedsLayout();
  }

  BoxConstraints _inflate(BoxConstraints c) => BoxConstraints(
    minWidth: c.minWidth + _overhang.horizontal,
    maxWidth: c.hasBoundedWidth
        ? c.maxWidth + _overhang.horizontal
        : double.infinity,
    minHeight: c.minHeight + _overhang.vertical,
    maxHeight: c.hasBoundedHeight
        ? c.maxHeight + _overhang.vertical
        : double.infinity,
  );

  Size _own(Size child, BoxConstraints c) => c.constrain(
    Size(child.width - _overhang.horizontal, child.height - _overhang.vertical),
  );

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return _own(child.getDryLayout(_inflate(constraints)), constraints);
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_inflate(constraints), parentUsesSize: true);
    size = _own(child.size, constraints);
    (child.parentData! as BoxParentData).offset = Offset(
      -_overhang.left,
      -_overhang.top,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final area = Rect.fromLTRB(
      -_overhang.left,
      -_overhang.top,
      size.width + _overhang.right,
      size.height + _overhang.bottom,
    );
    if (!area.contains(position)) return false;
    if (hitTestChildren(result, position: position) || hitTestSelf(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// `ComposerAttachments` plus the failed-upload alert rows, inside the
/// MessageInput `flex-col gap-2` column.
class RaftComposerAttachments extends StatelessWidget {
  const RaftComposerAttachments({
    super.key,
    required this.items,
    required this.onRemove,
    this.onRetry,
    this.onPreview,
    this.onReorder,
  });
  final List<RaftComposerAttachment> items;

  /// Web `handleAttachmentDragEnd`: the chips were dragged into a new order
  /// (ids of every chip, in order). Null leaves them fixed.
  final ValueChanged<List<String>>? onReorder;
  final ValueChanged<RaftComposerAttachment> onRemove;
  final ValueChanged<RaftComposerAttachment>? onRetry;

  /// Opens the local preview of a ready image (Web `openDraftImagePreview`).
  final ValueChanged<RaftComposerAttachment>? onPreview;

  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final i in items)
        if (!i.inFailureRow) i,
    ];
    final failures = [
      for (final i in items)
        if (i.inFailureRow) i,
    ];
    if (chips.isEmpty && failures.isEmpty) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    final root = _style(t, image: false, touch: false).attachments;
    // Each chip's layout box carries the 6px its remove badge overhangs
    // (top and right), so hover and taps reach the badge; the gaps shrink by
    // the same 6px and [_Overhang] shifts the whole slot back, which leaves
    // the CSS geometry (`flex flex-wrap gap-2`) unchanged.
    final hang = chips.isEmpty ? EdgeInsets.zero : _overhangInset;
    return _Overhang(
      overhang: hang,
      child: Column(
        key: const ValueKey('composer-attachments'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (chips.isNotEmpty)
            Padding(
              // raft-ui 0.7 `attachments`: `pt-1.5 pe-1.5`.
              padding: t.option('composerAttachment.style', or: 'recipe') == 'raft'
                  ? const EdgeInsets.only(top: 6, right: 6)
                  : root.padding,
              child: RaftReorderableWrap<RaftComposerAttachment>(
                spacing: (root.columnGap ?? gap) - hang.right,
                runSpacing: (root.rowGap ?? gap) - hang.top,
                items: chips,
                idOf: (item) => item.id,
                onReorder: onReorder,
                itemBuilder: (context, item) => _AttachmentChip(
                  key: ValueKey('composer-attachment-${item.id}'),
                  item: item,
                  sortable: onReorder != null,
                  onRemove: () => onRemove(item),
                  onPreview:
                      onPreview != null &&
                          item.preview != null &&
                          item.status == RaftComposerAttachmentStatus.ready
                      ? () => onPreview!(item)
                      : null,
                ),
              ),
            ),
          for (final item in failures) ...[
            if (chips.isNotEmpty || item != failures.first)
              const SizedBox(height: gap),
            Padding(
              padding: EdgeInsets.only(right: hang.right),
              child: _FailureRow(
                key: ValueKey('composer-upload-error-${item.id}'),
                item: item,
                onRetry: onRetry == null ? null : () => onRetry!(item),
                onRemove: () => onRemove(item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

RaftComposerAttachmentRecipeStyle _style(
  RaftTokens t, {
  required bool image,
  required bool touch,
  bool hovered = false,
}) => RaftComposerAttachmentRecipe.resolve(
  theme: RaftRecipeTheme.elegant,
  states: RaftRecipeStates({
    if (t.dark) RaftRecipeStates.dark,
    if (image) 'has:data-slot=composer-attachment-image',
    if (touch) RaftRecipeStates.hoverNone,
    if (hovered) 'group/composer-attachment:hover',
  }),
  tokens: RaftRecipeTokens(t),
);

class _AttachmentChip extends StatefulWidget {
  const _AttachmentChip({
    super.key,
    required this.item,
    required this.onRemove,
    this.onPreview,
    this.sortable = false,
  });
  final RaftComposerAttachment item;
  final bool sortable;
  final VoidCallback onRemove;
  final VoidCallback? onPreview;
  @override
  State<_AttachmentChip> createState() => _AttachmentChipState();
}

class _AttachmentChipState extends State<_AttachmentChip> {
  bool hovered = false;

  RaftComposerAttachment get item => widget.item;

  /// raft-ui 0.7 `composerAttachment`: a `fill-muted` card with a hairline
  /// (file 176x64 / image 64x64), a bare ink-bordered remove square that is
  /// always visible, and `layer-card` washes for checking / uploading / failed.
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final image = item.preview != null;
    final radius = t.size('radius.control', fallback: 8);
    final hairline = raftControlBorderPx(context, 1);
    final preview = widget.onPreview;
    Widget body;
    if (image) {
      body = SizedBox.square(
        dimension: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ui.fillMuted,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: ui.lineHairline, width: hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius - hairline),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _TransparencyPainter()),
                RaftSizedImage.memory(
                  item.preview!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  semanticLabel: item.name,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final metaText = item.mimeType.isEmpty
          ? raftText(context, 'file')
          : item.mimeType;
      body = Container(
        width: 176,
        // `h-16`: a minimum, so larger text never overflows the chip.
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: ui.fillMuted,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ui.lineHairline, width: hairline),
        ),
        child: Row(
          children: [
            RaftIcon(RaftGlyph.fileText, size: 16, color: ui.foregroundMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftCssText(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      RaftTypeScale.footnote,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RaftCssText(
                    metaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.scale(
                      RaftTypeScale.monoMeta,
                      mono: true,
                      color: ui.foregroundHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (preview != null) {
      body = Semantics(
        button: true,
        label: raftFormat(context, 'Preview {file}', {'file': item.name}),
        child: RaftTooltip(
          message: raftText(context, 'Preview Image'),
          child: RaftHoverRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: preview,
              child: ExcludeSemantics(child: body),
            ),
          ),
        ),
      );
    } else if (widget.sortable) {
      body = RaftHoverRegion(cursor: SystemMouseCursors.grab, child: body);
    }
    Widget wash(Color fill, List<Widget> children, {Border? border}) =>
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(radius),
              border: border,
            ),
            child: ClipRect(
              child: OverflowBox(
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: children,
                ),
              ),
            ),
          ),
        );
    TextStyle meta(Color color) => t.scale(
      RaftTypeScale.monoMeta,
      mono: true,
      weight: FontWeight.w700,
      color: color,
    );
    final overlays = <Widget>[
      if (item.status == RaftComposerAttachmentStatus.checking)
        wash(ui.layerCard.withValues(alpha: .8), [
          const Padding(padding: EdgeInsets.only(bottom: 4), child: RaftSpinner()),
          RaftCssText(
            raftText(context, 'Checking file…'),
            textAlign: TextAlign.center,
            style: meta(ui.foreground),
          ),
        ]),
      if (item.status == RaftComposerAttachmentStatus.uploading) ...[
        wash(ui.layerCard.withValues(alpha: .8), [
          const Padding(padding: EdgeInsets.only(bottom: 4), child: RaftSpinner()),
          RaftCssText(
            item.progress >= 99
                ? raftText(context, 'Finishing upload…')
                : item.progress > 0
                ? '${item.progress}%'
                : raftText(context, 'Uploading'),
            textAlign: TextAlign.center,
            style: meta(ui.foreground),
          ),
        ]),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          height: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ui.layerCard,
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: item.progress.clamp(0, 100) / 100,
                  heightFactor: 1,
                  child: ColoredBox(color: ui.info),
                ),
              ),
            ),
          ),
        ),
      ],
      if (item.status == RaftComposerAttachmentStatus.failed)
        wash(
          ui.layerCard.withValues(alpha: .9),
          [
            RaftCssText(
              raftText(context, 'Upload failed'),
              textAlign: TextAlign.center,
              style: t.scale(
                RaftTypeScale.caption,
                weight: FontWeight.w600,
                color: ui['danger-strong'],
              ),
            ),
          ],
          border: Border.all(color: ui['danger-strong'], width: hairline),
        ),
    ];
    final removeSize = 20.0;
    final stickerRadius = t.size('radius.sticker', fallback: 4);
    final removeButton = Semantics(
      button: true,
      label: raftFormat(context, 'Remove {file}', {'file': item.name}),
      excludeSemantics: true,
      onTap: widget.onRemove,
      child: GestureDetector(
        key: const ValueKey('composer-attachment-remove'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onRemove,
        child: Container(
          width: removeSize,
          height: removeSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ui.layerCard,
            borderRadius: BorderRadius.circular(stickerRadius),
            border: Border.all(
              color: ui.lineStrong,
              width: raftControlBorderPx(context, 1.5),
            ),
          ),
          child: RaftIcon(RaftGlyph.x, size: 12, color: ui.foreground),
        ),
      ),
    );
    return RaftHoverRegion(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: _overhangInset,
            child: KeyedSubtree(
              key: ValueKey('composer-attachment-box-${item.id}'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  body,
                  if (image) ...overlays else ...overlays,
                ],
              ),
            ),
          ),
          Positioned(top: 0, right: 0, child: removeButton),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('composerAttachment.style', or: 'recipe') == 'raft') {
      return _buildRaft(context, t);
    }
    final resolver = RaftRecipeTokens(t);
    final touch = RaftDensityScope.of(context) == RaftDensity.touch;
    final image = item.preview != null;
    final s = _style(t, image: image, touch: touch, hovered: hovered);
    final remove = s.attachmentRemove;
    final size = remove.width ?? 16;
    final visible = (remove.opacity ?? 1) > 0;

    final Widget body;
    if (image) {
      body = _ImageBody(item: item, style: s, tokens: t);
    } else {
      body = _FileBody(item: item, style: s, tokens: t, resolver: resolver);
    }
    final preview = widget.onPreview;
    Widget content = body;
    if (preview == null && widget.sortable) {
      // Web `cursor-grab`: the chip body is the drag handle.
      content = RaftHoverRegion(cursor: SystemMouseCursors.grab, child: body);
    }
    if (preview != null) {
      content = Semantics(
        button: true,
        label: raftFormat(context, 'Preview {file}', {'file': item.name}),
        child: RaftTooltip(
          message: raftText(context, 'Preview Image'),
          child: RaftHoverRegion(
            cursor: SystemMouseCursors.zoomIn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: preview,
              child: ExcludeSemantics(child: body),
            ),
          ),
        ),
      );
    }

    // `attachment` root: brutal image chips carry the 2px border here, and
    // every absolutely positioned child is relative to its padding box.
    final border = s.attachment.border(resolver);
    final fixed = s.attachment.width != null && s.attachment.height != null;
    final overlays = <Widget>[
      if (item.status == RaftComposerAttachmentStatus.checking)
        Positioned.fill(
          child: _Overlay(
            style: s.attachmentUploadingOverlay,
            tokens: t,
            label: raftText(context, 'Checking file…'),
            spinner: true,
          ),
        ),
      if (item.status == RaftComposerAttachmentStatus.uploading) ...[
        Positioned.fill(
          child: _Overlay(
            style: s.attachmentUploadingOverlay,
            tokens: t,
            label: item.progress >= 99
                ? raftText(context, 'Finishing upload…')
                : item.progress > 0
                ? '${item.progress}%'
                : raftText(context, 'Uploading'),
            spinner: true,
          ),
        ),
        _ProgressBar(
          bar: s.attachmentUploadProgressBar,
          indicator: s.attachmentUploadProgressBarIndicator,
          tokens: t,
          percent: item.progress,
        ),
      ],
      if (item.status == RaftComposerAttachmentStatus.failed)
        Positioned.fill(
          child: _Overlay(
            style: s.attachmentFailedOverlay,
            tokens: t,
            label: raftText(context, 'Upload failed'),
            // The brutal image chip already has the 2px border.
            borderless: false,
          ),
        ),
    ];
    final removeButton = IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: raftMotionDuration(
          context,
          remove.transitionDuration ?? const Duration(milliseconds: 150),
        ),
        curve: remove.transitionCurve ?? Curves.ease,
        child: Semantics(
          button: true,
          label: raftFormat(context, 'Remove {file}', {'file': item.name}),
          excludeSemantics: true,
          onTap: widget.onRemove,
          child: GestureDetector(
            key: const ValueKey('composer-attachment-remove'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onRemove,
            child: Container(
              width: size,
              height: remove.height ?? size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: remove.backgroundColor?.resolve(resolver),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: remove.outlineColor?.resolve(resolver) ?? t.panel,
                    spreadRadius: remove.outlineWidth ?? 2,
                  ),
                ],
              ),
              child: RaftIcon(
                RaftGlyph.x,
                size: 10,
                color: remove.color?.resolve(resolver),
              ),
            ),
          ),
        ),
      ),
    );
    Widget stack = Stack(
      clipBehavior: Clip.none,
      children: [
        if (fixed) Positioned.fill(child: content) else content,
        ...overlays,
      ],
    );
    if (fixed) {
      stack = Container(
        width: s.attachment.width,
        height: s.attachment.height,
        decoration: border == null ? null : BoxDecoration(border: border),
        child: stack,
      );
    }
    // The badge sits at `top:-6 right:-6` of the chip's padding box (inside a
    // brutal image chip's border); here the layout box already carries the
    // 6px overhang, so it lies inside the Stack and takes hover and taps.
    final inset = fixed ? s.attachment.borderWidth : EdgeInsets.zero;
    return RaftHoverRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: _overhangInset,
            child: KeyedSubtree(
              key: ValueKey('composer-attachment-box-${item.id}'),
              child: stack,
            ),
          ),
          Positioned(
            top: _overhangInset.top + inset.top + (remove.length('top') ?? -6),
            right:
                _overhangInset.right +
                inset.right +
                (remove.length('right') ?? -6),
            child: removeButton,
          ),
        ],
      ),
    );
  }
}

/// Checkerboard under transparent pixels (Web `image-transparency-bg`:
/// white with 12% ink squares).
class _TransparencyPainter extends CustomPainter {
  const _TransparencyPainter();
  static const _cell = 8.0;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paint = Paint()..color = const Color(0x1f141111);
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = 0; x * _cell < size.width; x++) {
        if ((x + y).isOdd) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyPainter old) => false;
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({
    required this.item,
    required this.style,
    required this.tokens,
  });
  final RaftComposerAttachment item;
  final RaftComposerAttachmentRecipeStyle style;
  final RaftTokens tokens;
  @override
  Widget build(BuildContext context) {
    final resolver = RaftRecipeTokens(tokens);
    final slot = style.attachmentImage;
    final radius = slot.borderRadius;
    final decoration = slot.decoration(resolver);
    // brutal: 100% of the bordered chip; elegant: the slot's own 64x64.
    Widget picture = Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _TransparencyPainter()),
        RaftSizedImage.memory(
          item.preview!,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          semanticLabel: item.name,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
    if (radius != null) {
      picture = ClipRRect(borderRadius: radius, child: picture);
    } else {
      picture = ClipRect(child: picture);
    }
    return SizedBox(
      width: slot.width,
      height: slot.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: decoration.boxShadow,
        ),
        child: picture,
      ),
    );
  }
}

class _FileBody extends StatelessWidget {
  const _FileBody({
    required this.item,
    required this.style,
    required this.tokens,
    required this.resolver,
  });
  final RaftComposerAttachment item;
  final RaftComposerAttachmentRecipeStyle style;
  final RaftTokens tokens;
  final RaftRecipeTokens resolver;

  TextStyle text(RaftSlotStyle slot) =>
      slot.textStyle(resolver).copyWith(fontFamily: tokens.headingFont);

  @override
  Widget build(BuildContext context) {
    final slot = style.attachmentFile;
    final iconColor = tokens.colors['foreground-icon'] ?? tokens.muted;
    final meta = style.attachmentMeta;
    final metaText = item.mimeType.isEmpty
        ? raftText(context, 'file')
        : item.mimeType;
    final title = RaftCssText(
      item.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text(style.attachmentTitle),
    );
    final metaWidget = RaftCssText(
      metaText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: text(meta),
    );
    final padding = slot.padding;
    final body = Transform.translate(
      offset: style.attachmentTitle.translate ?? Offset.zero,
      child: title,
    );
    final inner = slot.width == null
        ? null
        : slot.width! - slot.borderWidth.horizontal;
    Widget card = Container(
      width: slot.width,
      height: slot.height,
      decoration: slot.decoration(resolver),
      clipBehavior: slot.overflowX == 'hidden' ? Clip.antiAlias : Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RaftIcon(RaftGlyph.fileText, size: 16, color: iconColor),
                  SizedBox(width: slot.columnGap ?? 8),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
          Positioned(
            right: meta.length('right') ?? 10,
            bottom: meta.length('bottom') ?? 6,
            width: inner,
            child: Align(alignment: Alignment.bottomRight, child: metaWidget),
          ),
        ],
      ),
    );
    // Elegant ring (`ring-1 ink10`) is a box-shadow outside the card.
    card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: slot.borderRadius,
        boxShadow: slot.decoration(resolver).boxShadow,
      ),
      child: card,
    );
    return card;
  }
}

/// Chromium blends a translucent fill in 8 bits and truncates, Flutter in
/// float and rounds: over an opaque backdrop Flutter lands up to one level
/// lighter. Lowering the colour by half a level (divided by its alpha)
/// makes the rounded result equal the truncated one (measured on the dark
/// theme's `layer-canvas-muted/80`; the light white/85 fill already agrees).
BoxDecoration _truncating(BoxDecoration d) {
  final c = d.color;
  if (c == null || c.a >= 1 || c.a <= 0) return d;
  final shift = .5 / 255 / c.a;
  double down(double v) => (v - shift).clamp(0.0, 1.0);
  return RaftRecipeDecoration(
    color: Color.from(
      alpha: c.a,
      red: down(c.r),
      green: down(c.g),
      blue: down(c.b),
    ),
    border: d.border,
    borderRadius: d.borderRadius,
    boxShadow: d.boxShadow,
  );
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.style,
    required this.tokens,
    required this.label,
    this.spinner = false,
    this.borderless = false,
  });
  final RaftSlotStyle style;
  final RaftTokens tokens;
  final String label;
  final bool spinner, borderless;
  @override
  Widget build(BuildContext context) {
    final resolver = RaftRecipeTokens(tokens);
    final decoration = tokens.dark
        ? _truncating(style.decoration(resolver))
        : style.decoration(resolver);
    final color = style.color?.resolve(resolver);
    return Container(
      decoration: borderless
          ? BoxDecoration(
              color: decoration.color,
              borderRadius: decoration.borderRadius,
            )
          : decoration,
      padding: style.padding,
      alignment: Alignment.center,
      child: IconTheme(
        data: IconThemeData(color: color),
        // CSS overflows its box without a layout error; the chip clips it.
        child: ClipRect(
          child: OverflowBox(
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spinner)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: RaftSpinner(),
                  ),
                RaftCssText(
                  label,
                  textAlign: TextAlign.center,
                  style: style
                      .textStyle(resolver)
                      .copyWith(color: color, fontFamily: tokens.headingFont),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.bar,
    required this.indicator,
    required this.tokens,
    required this.percent,
  });
  final RaftSlotStyle bar, indicator;
  final RaftTokens tokens;
  final int percent;
  @override
  Widget build(BuildContext context) {
    final resolver = RaftRecipeTokens(tokens);
    final radius = bar.borderRadius;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: bar.height ?? 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bar.backgroundColor?.resolve(resolver),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius ?? BorderRadius.zero,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (percent.clamp(0, 100)) / 100,
              heightFactor: 1,
              child: ColoredBox(
                color:
                    indicator.backgroundColor?.resolve(resolver) ??
                    tokens.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web failed-upload row: `role="alert" flex w-full flex-wrap items-center
/// gap-2 rounded-md border border-line-strong bg-warning px-2 py-1.5 text-xs
/// text-warning-foreground` (Brutal: square, 2px black border, orange fill).
class _FailureRow extends StatelessWidget {
  const _FailureRow({
    super.key,
    required this.item,
    required this.onRemove,
    this.onRetry,
  });
  final RaftComposerAttachment item;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  /// raft-ui 0.7 failure row (MessageInput `role="alert"`): `rounded-container
  /// bg-warning-soft px-3 py-2 text-footnote text-foreground`, the file name
  /// bold, the message muted, an outline `sm` retry and a ghost icon remove.
  Widget _buildRaft(BuildContext context, RaftTokens t) {
    final ui = t.ui;
    final style = t.scale(RaftTypeScale.footnote, color: ui.foreground);
    final retry = item.canRetry && onRetry != null;
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RaftCssText(item.name, style: style.copyWith(fontWeight: FontWeight.w700)),
        RaftCssText(
          item.error ?? raftText(context, 'Upload failed'),
          style: style.copyWith(color: ui.foregroundMuted),
        ),
        if (item.progress > 0)
          RaftCssText(
            raftFormat(context, '{progress}% sent', {'progress': item.progress}),
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (retry) ...[
          RaftButton(
            key: const ValueKey('composer-attachment-retry'),
            uiVariant: RaftButtonVariant.outline,
            uiSize: RaftButtonSize.sm,
            label: raftText(context, 'Tap to retry'),
            semanticLabel: raftFormat(context, 'Retry Uploading {file}', {
              'file': item.name,
            }),
            onPressed: onRetry,
          ),
          const SizedBox(width: 6),
        ],
        RaftButton(
          key: const ValueKey('composer-attachment-remove'),
          uiVariant: RaftButtonVariant.ghost,
          uiSize: RaftButtonSize.iconSm,
          label: '',
          glyph: RaftGlyph.x,
          semanticLabel: raftFormat(context, 'Remove {file}', {'file': item.name}),
          onPressed: onRemove,
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ui['warning-soft'],
          borderRadius: BorderRadius.circular(
            t.size('radius.container', fallback: 10),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `flex flex-wrap gap-2`: the text block (basis 14rem) and the
            // shrink-0 actions share a line while both fit.
            final wide = constraints.maxWidth >= 224 + 8 + (retry ? 128 : 32);
            return wide
                ? Row(
                    children: [
                      Expanded(child: label),
                      const SizedBox(width: 8),
                      actions,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (t.option('composerAttachment.style', or: 'recipe') == 'raft') {
      return _buildRaft(context, t);
    }
    final ink = t.colors['warning-foreground']!;
    final style = TextStyle(
      fontFamily: t.headingFont,
      fontSize: 12,
      height: 16 / 12,
      color: ink,
    );
    final retry = item.canRetry && onRetry != null;
    final message = item.error ?? raftText(context, 'Upload failed');
    final label = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaftCssText(
            item.name,
            style: style.copyWith(fontWeight: FontWeight.w700),
          ),
          RaftCssText(message, style: style),
          if (item.progress > 0)
            RaftCssText(
              raftFormat(context, '{progress}% sent', {
                'progress': item.progress,
              }),
              style: style.copyWith(fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (retry) ...[
          Semantics(
            button: true,
            label: raftFormat(context, 'Retry Uploading {file}', {
              'file': item.name,
            }),
            excludeSemantics: true,
            onTap: onRetry,
            child: GestureDetector(
              key: const ValueKey('composer-attachment-retry'),
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: t.colors['line-muted']!, width: 1),
                  boxShadow: t.themeShadows.xs.paintOrder,
                ),
                child: RaftCssText(
                  raftText(context, 'Tap to retry'),
                  underline: true,
                  style: style.copyWith(
                    fontWeight: FontWeight.w700,
                    color: t.strong,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Semantics(
          button: true,
          label: raftFormat(context, 'Remove {file}', {'file': item.name}),
          excludeSemantics: true,
          onTap: onRemove,
          child: GestureDetector(
            key: const ValueKey('composer-attachment-remove'),
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.colors['inactive'],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: t.colors['line-strong']!, width: 1),
              ),
              child: RaftIcon(
                RaftGlyph.x,
                size: 12,
                color: t.colors['inactive-foreground'],
              ),
            ),
          ),
        ),
      ],
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: t.colors['warning'],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.colors['line-strong']!, width: 1),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // `flex flex-wrap gap-2`: the text block (basis 14rem) and the
            // shrink-0 actions share a line while both fit, else the actions
            // wrap onto their own right-aligned line.
            final measured = TextPainter(
              text: TextSpan(
                text: raftText(context, 'Tap to retry'),
                style: style.copyWith(fontWeight: FontWeight.w700),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            final actionsWidth =
                28 + (retry ? 6 + measured.width + 16 + (2) : 0);
            measured.dispose();
            final wide = constraints.maxWidth >= 224 + 8 + actionsWidth;
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: label),
                      const SizedBox(width: 8),
                      actions,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
          },
        ),
      ),
    );
  }
}
