import 'raft/list_row_action.dart';

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'attachment_lightbox.dart' show RaftFileTypeBadge;
import 'design_primitives.dart';
import 'icons.dart';
import 'localization.dart';
import 'text_scaling.dart';
import 'space.dart';
import 'theme.dart';

/// How much of an attachment's bytes has arrived. Pure data: the app owns the
/// transfer, raft_ui only draws it.
@immutable
class RaftTransferProgress {
  const RaftTransferProgress({
    this.received = 0,
    this.total,
    this.percentOnly = false,
  });

  /// Progress reported only as a percentage (a WebView page load: byte counts
  /// are unknown). 0 is still waiting; the label is `40%`, never byte sizes.
  const RaftTransferProgress.percent(int percent)
    : received = percent < 0
          ? 0
          : percent > 100
          ? 100
          : percent,
      total = 100,
      percentOnly = true;

  /// Nothing received and no length known: the URL or first byte is pending.
  static const connecting = RaftTransferProgress();
  final int received;

  /// Declared length; null or non-positive when the server did not send one.
  final int? total;

  /// [received] / [total] are percent points, not bytes.
  final bool percentOnly;

  /// The same progress with [fallback] (e.g. the attachment's `sizeBytes`)
  /// standing in for an unknown total.
  RaftTransferProgress withFallbackTotal(int? fallback) =>
      total != null && total! > 0 || fallback == null || fallback <= 0
      ? this
      : RaftTransferProgress(received: received, total: fallback);

  bool get hasTotal => total != null && total! > 0;

  /// Waiting for the first byte (the URL or the connection is pending).
  bool get waiting => received <= 0;

  /// 0..1, or null (indeterminate) while waiting or when the total is unknown.
  double? get fraction => waiting || !hasTotal
      ? null
      : (received / total!).clamp(0.0, 1.0).toDouble();

  /// `1.2 / 3.4 MB` (units follow the total), or `1.2 MB` without a total.
  String get sizeLabel => percentOnly
      ? '$received%'
      : formatTransferSizes(received, hasTotal ? total : null);

  @override
  bool operator ==(Object other) =>
      other is RaftTransferProgress &&
      received == other.received &&
      total == other.total &&
      percentOnly == other.percentOnly;
  @override
  int get hashCode => Object.hash(received, total, percentOnly);
}

/// `1.2 / 3.4 MB`: both numbers use the unit of the larger one.
String formatTransferSizes(int received, int? total) {
  const kb = 1024, mb = 1024 * 1024;
  final reference = total ?? received;
  final (divisor, unit, digits) = reference >= mb
      ? (mb, 'MB', 1)
      : reference >= kb
      ? (kb, 'KB', reference >= 10 * kb ? 0 : 1)
      : (1, 'B', 0);
  String n(int v) => (v / divisor).toStringAsFixed(digits);
  return total == null
      ? '${n(received)} $unit'
      : '${n(math.min(received, total))} / ${n(total)} $unit';
}

/// Dimensions and colors of the transfer bar, per theme family.
class RaftTransferRecipe {
  RaftTransferRecipe(this.tokens);
  final RaftTokens tokens;

  /// Bar flush with the bottom edge of an image tile or stage.
  double get edgeHeight => 4;

  /// Standalone bar of a file preview.
  double get inlineHeight => 6;
  double get rule => 2;
  Color get fill => tokens.accent;
  Color get danger => tokens.colors['danger']!;
  Color get dangerForeground => tokens.colors['danger-foreground']!;

  /// Danger text on a plain surface (file card, preview panel).
  Color get dangerText => tokens.colors['danger-strong'] ?? danger;
  Color track({required bool onImage}) => (onImage
      ? Colors.black.withValues(alpha: .35)
      : tokens.muted.withValues(alpha: .18));
}

enum RaftTransferBarStyle {
  /// Full-bleed, square-ended strip along the bottom edge of an image.
  edge,

  /// Standalone, bordered / rounded bar.
  inline,
}

/// Thin determinate bar; [value] null is indeterminate (a segment sweeps).
/// Painting is the only per-update work: no layout, no rebuild of siblings.
class RaftTransferBar extends StatefulWidget {
  const RaftTransferBar({
    super.key,
    this.value,
    this.failed = false,
    this.style = RaftTransferBarStyle.edge,
  });
  final double? value;
  final bool failed;
  final RaftTransferBarStyle style;
  @override
  State<RaftTransferBar> createState() => _RaftTransferBarState();
}

class _RaftTransferBarState extends State<RaftTransferBar>
    with SingleTickerProviderStateMixin {
  late final sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  bool reduced = false;

  bool get indeterminate => widget.value == null && !widget.failed;

  void sync() {
    if (indeterminate && !reduced) {
      // ignore: raft_lints/avoid_unreviewed_idle_work -- Loop driven by an AnimationController whose vsync is this State, so TickerMode (hidden routes, offstage tabs, folded panels) mutes it, it is disposed with the widget, and reduced motion stops it.
      if (!sweep.isAnimating) sweep.repeat();
    } else {
      sweep.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    sync();
  }

  @override
  void didUpdateWidget(RaftTransferBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void dispose() {
    sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = RaftTransferRecipe(RaftTokens.of(context));
    final edge = widget.style == RaftTransferBarStyle.edge;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: edge ? recipe.edgeHeight : recipe.inlineHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarPainter(
              repaint: sweep,
              value: widget.failed ? 1 : widget.value,
              failed: widget.failed,
              edge: edge,
              fill: widget.failed ? recipe.danger : recipe.fill,
              track: recipe.track(onImage: edge),
              sweep: sweep,
              frozenSegment: reduced,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required Listenable repaint,
    required this.value,
    required this.failed,
    required this.edge,
    required this.fill,
    required this.track,
    required this.sweep,
    required this.frozenSegment,
  }) : super(repaint: repaint);
  final double? value;
  final bool failed, edge, frozenSegment;
  final Color fill, track;
  final Animation<double> sweep;
  static const segment = .3;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    final bounds = Offset.zero & size;
    // Inline bars are pills; edge strips are flush (the tile clips the
    // corners).
    final pill = !edge;
    final trackShape = RRect.fromRectAndRadius(
      bounds,
      pill ? Radius.circular(h / 2) : Radius.zero,
    );
    canvas.drawRRect(trackShape, Paint()..color = track);
    final frac = value;
    final double left, width;
    if (frac == null) {
      final p = frozenSegment ? .35 : Curves.easeInOut.transform(sweep.value);
      width = w * segment;
      left = -width + (w + width) * p;
    } else {
      left = 0;
      width = w * frac;
    }
    final inner = bounds;
    final fillRect = Rect.fromLTRB(
      inner.left + left,
      inner.top,
      inner.left + left + width,
      inner.bottom,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        inner,
        pill ? Radius.circular(h / 2) : Radius.zero,
      ),
    );
    if (width > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, Radius.circular(fillRect.height / 2)),
        Paint()..color = fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value ||
      old.failed != failed ||
      old.fill != fill ||
      old.track != track ||
      old.edge != edge ||
      old.frozenSegment != frozenSegment;
}

/// Neutral reserved box of an image whose bytes are in flight (or failed):
/// the surface with a quiet picture glyph, under the bottom-edge bar.
class RaftTransferPlaceholder extends StatelessWidget {
  const RaftTransferPlaceholder({super.key, this.onDark = false});

  /// On a dark stage (the image viewer): a translucent white box and glyph
  /// instead of the cream / muted fill of the light surfaces.
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (onDark) {
      return ColoredBox(
        color: Colors.white.withValues(alpha: .1),
        child: Center(
          child: RaftIcon(
            RaftGlyph.image,
            size: 30,
            color: Colors.white.withValues(alpha: .4),
          ),
        ),
      );
    }
    return ColoredBox(
      color: t.colors['fill-muted']!,
      child: Center(
        child: RaftIcon(
          RaftGlyph.image,
          size: 30,
          color: t.muted.withValues(alpha: .6),
        ),
      ),
    );
  }
}

/// Small overlay label: brutal = white box with a hard border; elegant = dark
/// translucent pill. Danger variant is filled with the danger color.
class RaftTransferChip extends StatelessWidget {
  const RaftTransferChip({
    super.key,
    required this.label,
    this.leading,
    this.danger = false,
  });
  final String label;
  final RaftGlyph? leading;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftTransferRecipe(t);
    final foreground = danger
        ? recipe.dangerForeground
        : Colors.white.withValues(alpha: .95);
    final style = danger
        ? RaftTypography.body(t, size: 11, line: 14, color: foreground)
        : RaftTypography.mono(t, size: 11, line: 14, color: foreground);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: danger ? recipe.danger : Colors.black.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RaftSpace.x2,
          vertical: RaftSpace.x1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              RaftIcon(leading!, size: 12, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-edge progress of an image tile or stage (Option A): a thin bar flush
/// with the bottom edge and a small `1.2 / 3.4 MB` chip above it. Place it in a
/// `Stack(fit: StackFit.expand)` over the picture. Only this overlay rebuilds
/// when [progress] changes; it never takes pointer events, so the tile's own
/// tap (open / retry) keeps working.
class RaftImageTransferOverlay extends StatelessWidget {
  const RaftImageTransferOverlay({
    super.key,
    required ValueListenable<RaftTransferProgress?> this.progress,
    this.fallbackTotal,
    this.labelPrefix,
    this.inset = 8,
  }) : failed = false,
       onRetry = null;

  /// The failed state: a full red bar and "Download failed · tap to retry".
  /// With [onRetry] the bottom band holding the chip is a focusable button
  /// (the rest of the surface keeps its own tap).
  const RaftImageTransferOverlay.failed({
    super.key,
    this.inset = 8,
    this.onRetry,
  }) : progress = null,
       fallbackTotal = null,
       labelPrefix = null,
       failed = true;

  /// Null value: not on the network (queued, or served from the disk cache),
  /// so nothing is drawn.
  final ValueListenable<RaftTransferProgress?>? progress;

  /// Stands in for an unknown content length (the attachment's size).
  final int? fallbackTotal;

  /// Prefix of the numeric label, already localized (e.g. "Original image").
  final String? labelPrefix;
  final bool failed;
  final double inset;
  final VoidCallback? onRetry;

  /// Height of the retry hit band (the chip, its inset and the bar fit in it).
  static const retryBand = 48.0;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _frame(context, null, failed: true),
          if (onRetry != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: retryBand,
              child: RaftListRowAction(
                semanticLabel: raftText(
                  context,
                  'Download failed · tap to retry',
                ),
                key: const ValueKey('attachment-retry'),
                onPressed: onRetry,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      );
    }
    return ValueListenableBuilder<RaftTransferProgress?>(
      valueListenable: progress!,
      builder: (context, value, _) => value == null
          ? const SizedBox.shrink()
          : _frame(context, value.withFallbackTotal(fallbackTotal)),
    );
  }

  Widget _frame(
    BuildContext context,
    RaftTransferProgress? value, {
    bool failed = false,
  }) {
    final recipe = RaftTransferRecipe(RaftTokens.of(context));
    final String label;
    if (failed) {
      label = raftText(context, 'Download failed · tap to retry');
    } else if (value!.waiting) {
      label = raftText(context, 'Connecting…');
    } else {
      label = labelPrefix == null
          ? value.sizeLabel
          : '$labelPrefix ${value.sizeLabel}';
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: inset,
              right: inset,
              bottom: recipe.edgeHeight + inset,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: RaftTransferChip(
                  label: label,
                  leading: failed ? RaftGlyph.refreshCw : null,
                  danger: failed,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RaftTransferBar(failed: failed, value: value?.fraction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Download panel of a file preview (PDF, document, text): file head, bar,
/// `1.7 / 2.8 MB · 62%` and Cancel. [failed] swaps in the red bar and a retry
/// action. Only the bar and the size line rebuild per update.
class RaftFileTransferPanel extends StatelessWidget {
  const RaftFileTransferPanel({
    super.key,
    required this.filename,
    required this.meta,
    required this.progress,
    this.fallbackTotal,
    this.failed = false,
    this.onCancel,
    this.onRetry,
  });
  final String filename;

  /// Secondary line under the name, e.g. `PDF · 2.8 MB`.
  final String meta;
  final ValueListenable<RaftTransferProgress?> progress;
  final int? fallbackTotal;
  final bool failed;
  final VoidCallback? onCancel, onRetry;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final recipe = RaftTransferRecipe(t);
    final nameStyle = RaftTypography.body(
      t,
      size: 15,
      line: 20,
      weight: FontWeight.w700,
      color: t.ink,
    );
    final metaStyle = RaftTypography.body(
      t,
      size: 12,
      line: 16,
      color: t.muted,
    );
    final mono = RaftTypography.mono(t, size: 12, line: 16, color: t.muted);
    final retryTap = failed ? onRetry : null;
    final grows = RaftScaled.grows(context);
    final Widget status = failed
        ? Text(
            raftText(context, 'Download failed · tap to retry'),
            style: metaStyle.copyWith(color: recipe.dangerText),
          )
        : ValueListenableBuilder<RaftTransferProgress?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final resolved = (value ?? RaftTransferProgress.connecting)
                  .withFallbackTotal(fallbackTotal);
              final fraction = resolved.fraction;
              return Text(
                resolved.waiting
                    ? raftText(context, 'Connecting…')
                    : fraction == null || resolved.percentOnly
                    ? resolved.sizeLabel
                    : '${resolved.sizeLabel} · ${(fraction * 100).floor()}%',
                style: mono,
              );
            },
          );
    final Widget? action = failed && onRetry != null
        ? RaftTextButton(
            label: raftText(context, 'Retry'),
            glyph: RaftGlyph.refreshCw,
            onPressed: onRetry,
            visualHeight: 32,
          )
        : !failed && onCancel != null
        ? RaftTextButton(
            label: raftText(context, 'Cancel'),
            glyph: RaftGlyph.x,
            onPressed: onCancel,
            visualHeight: 32,
          )
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: retryTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  // The file tile is a minimum: it grows with the type badge.
                  constraints: BoxConstraints(
                    minWidth: RaftScaled.extent(context, 72, fontSize: 9),
                    minHeight: RaftScaled.extent(context, 88, fontSize: 9),
                  ),
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border.all(
                      color: t.colors['line-muted']!,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: RaftFileTypeBadge(
                      filename: filename,
                      size: const Size(40, 20),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  filename,
                  // The name wraps fully above the default text size.
                  maxLines: grows ? null : 2,
                  overflow: grows ? TextOverflow.clip : TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: nameStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  failed
                      ? '$meta · ${raftText(context, 'Download failed')}'
                      : meta,
                  style: metaStyle.copyWith(
                    color: failed ? recipe.dangerText : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (failed)
            const RaftTransferBar(
              failed: true,
              style: RaftTransferBarStyle.inline,
            )
          else
            ValueListenableBuilder<RaftTransferProgress?>(
              valueListenable: progress,
              builder: (context, value, _) => RaftTransferBar(
                style: RaftTransferBarStyle.inline,
                value: (value ?? RaftTransferProgress.connecting)
                    .withFallbackTotal(fallbackTotal)
                    .fraction,
              ),
            ),
          const SizedBox(height: 8),
          // Size line and Cancel / Retry: side by side at the default text
          // size, stacked above it so neither is squeezed.
          if (grows)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                if (action != null) ...[const SizedBox(height: 8), action],
              ],
            )
          else
            Row(
              children: [
                Expanded(child: status),
                if (action != null) action,
              ],
            ),
        ],
      ),
    );
  }
}

/// A file preview whose content is still arriving, drawn on the preview body
/// surface: the file panel (head, bar, `62%` or `1.7 / 2.8 MB · 62%`, Cancel)
/// centred and opaque, so it can also cover a platform view that is loading.
class RaftPreviewTransferStage extends StatelessWidget {
  const RaftPreviewTransferStage({
    super.key,
    required this.filename,
    required this.meta,
    required this.progress,
    this.onCancel,
  });
  final String filename, meta;
  final ValueListenable<RaftTransferProgress?> progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final panel = RaftFileTransferPanel(
      filename: filename,
      meta: meta,
      progress: progress,
      onCancel: onCancel,
    );
    return ColoredBox(
      color: t.panel,
      // Above the default text size the panel can outgrow the stage: it
      // scrolls instead of overflowing (still centred when it fits).
      child: RaftScaled.grows(context)
          ? LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(child: panel),
                ),
              ),
            )
          : Center(child: panel),
    );
  }
}
