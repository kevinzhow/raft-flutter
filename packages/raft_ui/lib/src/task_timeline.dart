import 'package:flutter/material.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'panel_layout.dart' show RaftCssText;
import 'mounted_task_chip.dart';
import 'theme.dart';

/// One history row: marker status, title, meta line and optional detail.
class RaftTimelineEntry {
  const RaftTimelineEntry({
    required this.status,
    required this.title,
    required this.meta,
    this.detail,
  });

  /// raft-ui `TimelineItem taskStatus`: the marker paints with this status's
  /// `task-status-*` token, the same one every other task surface reads. Null
  /// is the neutral marker (an event with no status).
  final RaftMessageTaskStatus? status;
  final String title, meta;

  /// Rendered under the meta line with `mt-0.5`.
  final Widget? detail;
}

/// raft-ui `Timeline size="sm"` (`style.css` `.r-timeline`): 12px marker on a
/// 2px rail, 12px/16px text, 16px between items, 12px axis gap. Elegant draws
/// hollow markers (`--r-timeline-marker-fill: 0%`) on a `line-muted` rail,
/// brutal filled markers on `line-strong`.
class RaftTimelineSm extends StatelessWidget {
  const RaftTimelineSm({super.key, required this.entries});
  final List<RaftTimelineEntry> entries;

  static const double marker = 12, axisOffset = 2, itemGap = 16, gap = 12;

  /// `--r-timeline-item-color` / `--r-timeline-item-fill`: both are
  /// `var(--task-status-<status>)` for a status marker (`taskStatusMarkerColor`).
  (Color color, Color fill) _tones(
    RaftTokens t,
    RaftMessageTaskStatus? status,
  ) {
    if (status == null) {
      return (t.colors['foreground-hint']!, t.colors['layer-panel']!);
    }
    final token = t.colors[RaftMessageTaskChipRecipe.tokenOf(status)]!;
    return (token, token);
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rail = t.colors[t.brutal ? 'line-strong' : 'line-muted']!;
    return Column(
      key: const ValueKey('timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _item(context, t, entries[i], rail, last: i == entries.length - 1),
      ],
    );
  }

  Widget _item(
    BuildContext context,
    RaftTokens t,
    RaftTimelineEntry e,
    Color rail, {
    required bool last,
  }) {
    final (color, fill) = _tones(t, e.status);
    final title = t.brutal
        ? RaftTypography.heading(t, size: 12, line: 16)
        : RaftTypography.body(t, size: 12, line: 16, weight: FontWeight.w500);
    // The body sets the height; the axis is stretched alongside it (the CSS
    // flex row, without an intrinsic pass: the body may contain a LayoutBuilder).
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: marker + gap,
            bottom: last ? 0 : itemGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RaftCssText(
                  e.title,
                  style: title.copyWith(color: t.strong),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RaftCssText(
                  e.meta,
                  style: RaftTypography.body(
                    t,
                    size: 12,
                    line: 16,
                    color: t.brutal
                        ? Colors.black.withValues(alpha: .5)
                        : t.muted,
                  ),
                ),
              ),
              if (e.detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: e.detail,
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: last ? 0 : -axisOffset,
          width: marker,
          child: Column(
            children: [
              const SizedBox(height: axisOffset),
              Container(
                width: marker,
                height: marker,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.brutal ? fill : Colors.transparent,
                  border: Border.all(
                    color: t.brutal ? t.colors['line-strong']! : color,
                    width: 2,
                  ),
                ),
              ),
              Expanded(
                child: last
                    ? const SizedBox.shrink()
                    : Container(width: 2, color: rail),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Clamped-to-one-line history text (`TimelineText`): when the text needs more
/// than a line it is clamped and a 12px chevron toggles the full text.
class RaftTimelineText extends StatefulWidget {
  const RaftTimelineText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;
  @override
  State<RaftTimelineText> createState() => _RaftTimelineTextState();
}

class _RaftTimelineTextState extends State<RaftTimelineText> {
  bool open = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final probe = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: box.maxWidth);
      final long = probe.computeLineMetrics().length > 1;
      probe.dispose();
      final text = RaftCssText(
        widget.text,
        style: widget.style,
        maxLines: long && !open ? 1 : null,
        overflow: long && !open ? TextOverflow.ellipsis : TextOverflow.clip,
      );
      if (!long) return text;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => open = !open),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: text),
            const SizedBox(width: 4),
            RaftIcon(
              open ? RaftGlyph.chevronDown : RaftGlyph.chevronRight,
              size: 12,
              color: widget.style.color,
            ),
          ],
        ),
      );
    },
  );
}
