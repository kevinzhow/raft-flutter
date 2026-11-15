// The Computers rack's runtime usage drawing (Web v1.24 components/machine/
// rack/RackRuntimeUsage.tsx: RackUsageCell, ModelUsageLine, RackUsageCardLine,
// RackRuntimeHeading, RackOtherCell; features/computer/RackListHeader.tsx).
// Presentation only: the app reads the usage, decides each cell's words and
// wraps a cell in the usage card's trigger; nothing here reads a server.
import 'package:flutter/widgets.dart';

import 'design_primitives.dart';
import 'icons.dart';
import 'indicators.dart';
import 'raft/status.dart';
import 'theme.dart';
import 'tokens/raft_tokens.g.dart' show RaftTypeScale;
import 'tooltip.dart';

/// RACK_USAGE_CELL_PX / RACK_OTHER_PX (computersRackLayout.ts).
const double raftRackUsageCellWidth = 96;
const double raftRackOtherCellWidth = 40;

enum RaftRackUsageKind {
  /// The computer has none of the provider's runtimes: an empty cell.
  absent,

  /// Read, not answered yet: bars in the value's shape.
  pending,

  /// Installed, nothing to read: "—".
  dash,

  /// A share used, over a bar.
  value,

  /// A login step ("Verify", "Sign in") instead of the bar.
  step,
}

/// The cell's second line: one model's (or model group's) share.
class RaftRackModelLine {
  const RaftRackModelLine({
    required this.name,
    required this.text,
    required this.used,
    required this.label,
  });

  /// "Opus", "Gemini".
  final String name;

  /// "40%", "6d", "Used up".
  final String text;

  /// Whole percent used (100 once its limit is reached).
  final int used;

  /// The line in words, for a screen reader ("Opus: 40% used").
  final String label;
  bool get warn => used >= 80;
}

/// One provider on one computer, as its cell draws it.
class RaftRackUsage {
  const RaftRackUsage({
    required this.kind,
    this.label = '',
    this.text = '',
    this.used = 0,
    this.warn = false,
    this.stale = false,
    this.attention = false,
    this.model,
    this.pendingTwoLines = false,
  });
  const RaftRackUsage.absent() : this(kind: RaftRackUsageKind.absent);
  final RaftRackUsageKind kind;

  /// "Claude account: 62% used": what a screen reader says and the card's label.
  final String label;

  /// "62% used", "Back in 3h", "Used up", or the step ("Sign in").
  final String text;

  /// Whole percent used, 0..100.
  final int used;
  final bool warn, stale, attention, pendingTwoLines;
  final RaftRackModelLine? model;
}

/// A usage column's heading in the list's header.
class RaftRackUsageHeading {
  const RaftRackUsageHeading({
    required this.key,
    required this.shortName,
    required this.fullName,
  });

  /// The sort key ("remaining:claude").
  final String key, shortName, fullName;
}

Color _hint(RaftTokens t) => t.colors['foreground-hint']!;
Color _muted(RaftTokens t) => t.colors['foreground-muted']!;
Color _warn(RaftTokens t) => t.colors['warning-strong']!;

TextStyle _mono(RaftTokens t, {Color? color, FontWeight? weight}) =>
    RaftTypography.mono(
      t,
      size: RaftTypeScale.monoMeta.fontSize,
      line: RaftTypeScale.monoMeta.lineHeight,
      color: color,
    ).copyWith(fontWeight: weight);

Widget _bar(int used, bool warn) => RaftProgressBar(
  value: used.clamp(0, 100).toDouble(),
  size: RaftProgressRecipeSize.sm,
  tone: warn
      ? RaftProgressRecipeVariant.warning
      : RaftProgressRecipeVariant.information,
);

/// An account needing attention, beside a value: the usage card's warning pixel.
class _AttentionPixel extends StatelessWidget {
  const _AttentionPixel();
  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: RaftStatus(
      key: ValueKey('rack-usage-attention'),
      size: RaftStatusSize.sm,
      variant: RaftStatusVariant.warning,
    ),
  );
}

/// A runtime's mark: no brand marks are bundled, so the generic runtime glyph.
class RaftRackRuntimeMark extends StatelessWidget {
  const RaftRackRuntimeMark({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: RaftIcon(RaftGlyph.cpu, size: 12, color: color));
}

/// A usage column's cell (list and phone) or line (card: [line], with the
/// runtime's [name] and mark first). Wrap it in the usage card's trigger.
class RaftRackUsageCell extends StatelessWidget {
  const RaftRackUsageCell({
    super.key,
    required this.usage,
    this.line = false,
    this.name,
    this.emphasized = false,
  });
  final RaftRackUsage usage;

  /// A card's line (name, bar, value) instead of a list cell.
  final bool line;
  final String? name;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final u = usage;
    if (u.kind == RaftRackUsageKind.absent) return const SizedBox.shrink();
    final valueColor = u.warn ? _warn(t) : _hint(t);
    final weight = u.warn || emphasized ? FontWeight.w700 : null;
    final Widget body;
    if (line) {
      body = _line(context, t, valueColor, weight);
    } else {
      body = switch (u.kind) {
        RaftRackUsageKind.pending => _pending(),
        RaftRackUsageKind.step => Text(
          u.text,
          key: const ValueKey('rack-usage-step'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _mono(t, color: _warn(t)),
        ),
        RaftRackUsageKind.dash => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('—', style: _mono(t, color: _hint(t))),
            if (u.attention) ...[
              const SizedBox(width: 4),
              const _AttentionPixel(),
            ],
          ],
        ),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _meter(t, u.text, u.used, u.warn, valueColor, weight, u.attention),
            if (u.model != null) ...[
              const SizedBox(height: 6),
              _modelLine(t, u.model!),
            ],
          ],
        ),
      };
    }
    return Opacity(
      opacity: u.stale ? .6 : 1,
      child: Semantics(label: u.label, excludeSemantics: true, child: body),
    );
  }

  Widget _meter(
    RaftTokens t,
    String text,
    int used,
    bool warn,
    Color color,
    FontWeight? weight,
    bool attention,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mono(t, color: color, weight: weight),
            ),
          ),
          if (attention) ...[const SizedBox(width: 4), const _AttentionPixel()],
        ],
      ),
      const SizedBox(height: 4),
      _bar(used, warn),
    ],
  );

  Widget _modelLine(RaftTokens t, RaftRackModelLine m) {
    final color = m.warn ? _warn(t) : _hint(t);
    return Column(
      key: const ValueKey('rack-usage-model'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(t, color: color),
              ),
            ),
            Flexible(
              child: Text(
                ' · ${m.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mono(t, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _bar(m.used, m.warn),
      ],
    );
  }

  Widget _pending() => ExcludeSemantics(
    child: Column(
      key: ValueKey('rack-usage-pending-${usage.pendingTwoLines ? 2 : 1}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const RaftSkeleton(width: 56, height: 14),
        const SizedBox(height: 4),
        const RaftSkeleton(height: 8),
        if (usage.pendingTwoLines) ...[
          const SizedBox(height: 6),
          const RaftSkeleton(width: 64, height: 14),
          const SizedBox(height: 4),
          const RaftSkeleton(height: 8),
        ],
      ],
    ),
  );

  /// RackUsageCardLine: the mark and short name, the bar, the value.
  Widget _line(
    BuildContext context,
    RaftTokens t,
    Color color,
    FontWeight? weight,
  ) {
    final u = usage;
    final label = TextStyle(
      fontSize: RaftTypeScale.footnote.fontSize,
      color: emphasized ? t.strong : _muted(t),
      fontWeight: emphasized ? FontWeight.w700 : null,
    );
    final labelBox = SizedBox(
      width: 76,
      child: Row(
        children: [
          const RaftRackRuntimeMark(),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RaftTypography.body(
                t,
                size: RaftTypeScale.footnote.fontSize,
                line: RaftTypeScale.footnote.lineHeight,
                color: label.color,
              ).copyWith(fontWeight: label.fontWeight),
            ),
          ),
        ],
      ),
    );
    Widget value(String text, {bool attention = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (attention) ...[const _AttentionPixel(), const SizedBox(width: 4)],
        Text(
          text,
          maxLines: 1,
          style: _mono(
            t,
            color: u.kind == RaftRackUsageKind.step
                ? _warn(t)
                : (emphasized && !u.warn ? t.strong : color),
            weight: weight,
          ),
        ),
      ],
    );
    final hasBar = u.kind == RaftRackUsageKind.value;
    final main = Row(
      children: [
        labelBox,
        const SizedBox(width: 8),
        Expanded(
          child: u.kind == RaftRackUsageKind.pending
              ? const RaftSkeleton(height: 8)
              : hasBar
              ? _bar(u.used, u.warn)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        switch (u.kind) {
          RaftRackUsageKind.pending => const RaftSkeleton(
            width: 48,
            height: 14,
          ),
          RaftRackUsageKind.dash => value('—', attention: u.attention),
          _ => value(u.text, attention: u.attention),
        },
      ],
    );
    final m = u.model;
    if (!hasBar || m == null) return main;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        main,
        const SizedBox(height: 4),
        Row(
          key: const ValueKey('rack-usage-model'),
          children: [
            SizedBox(
              width: 76,
              child: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: RaftTypeScale.footnote.fontSize,
                    color: _muted(t),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _bar(m.used, m.warn)),
            const SizedBox(width: 8),
            Text(
              m.text,
              maxLines: 1,
              style: _mono(t, color: m.warn ? _warn(t) : _hint(t)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The Other column's cell: each runtime's mark, their names on hover and focus.
class RaftRackOtherCell extends StatelessWidget {
  const RaftRackOtherCell({
    super.key,
    required this.count,
    required this.names,
  });
  final int count;

  /// "Aider, Goose": the runtimes in words.
  final String names;
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final t = RaftTokens.of(context);
    return RaftTooltip(
      message: names,
      child: Semantics(
        label: names,
        excludeSemantics: true,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < count; i++)
              RaftRackRuntimeMark(color: _hint(t)),
          ],
        ),
      ),
    );
  }
}

/// A usage column's heading: the mark and the short name, the full name on hover.
class RaftRackRuntimeHeading extends StatelessWidget {
  const RaftRackRuntimeHeading({
    super.key,
    required this.shortName,
    required this.fullName,
    this.color,
  });
  final String shortName, fullName;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = _mono(t, color: color ?? _hint(t));
    return RaftTooltip(
      message: fullName,
      child: Semantics(
        label: fullName,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftRackRuntimeMark(color: style.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone list's header (RackListHeader, non-desktop): only the runtime
/// columns, over the blocks' runtime cells; its headings do not sort.
class RaftRackPhoneRuntimeHeader extends StatelessWidget {
  const RaftRackPhoneRuntimeHeader({
    super.key,
    required this.usage,
    this.otherLabel,
  });
  final List<RaftRackUsageHeading> usage;
  final String? otherLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('computers-rack-header'),
      decoration: BoxDecoration(
        color: t.colors['layer-card'],
        border: Border(bottom: BorderSide(color: t.colors['line-seam']!)),
      ),
      child: SizedBox(
        height: 28,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (i, u) in usage.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: raftRackUsageCellWidth,
                      ),
                      child: RaftRackRuntimeHeading(
                        shortName: u.shortName,
                        fullName: u.fullName,
                        color: _muted(t),
                      ),
                    ),
                  ),
                ),
              ],
              if (otherLabel != null) ...[
                if (usage.isNotEmpty) const SizedBox(width: 8),
                SizedBox(
                  width: raftRackOtherCellWidth,
                  child: Text(
                    otherLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mono(t, color: _hint(t)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
