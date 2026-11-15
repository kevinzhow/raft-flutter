// The Computers overview's parts (Web v1.24 features/computer/
// ComputerRackRow.tsx, RackGroupTitle.tsx, RackListHeader.tsx,
// RackResource.tsx, ComputersAttentionSummary.tsx, ComputersRackToolbar.tsx,
// components/machine/rack/RackRowSkeleton.tsx; raft-design computers.md).
// Presentation only: the app supplies the words, the computers' facts and
// the callbacks; nothing here reads a server.
import 'package:flutter/widgets.dart';

import 'card.dart' show RaftCard;
import 'design_primitives.dart';
import 'raft/css_box.dart' show RaftCssBox;
import 'focus_visible.dart';
import 'hover_region.dart';
import 'icons.dart';
import 'adaptive_workspace.dart' show RaftPanelResizeHandle;
import 'banner.dart';
import 'indicators.dart';
import 'raft/avatar.dart' show RaftAvatarSize;
import 'raft/status.dart';
import 'theme.dart';
import 'tokens/raft_tokens.g.dart'
    show RaftRadius, RaftTypeScale, RaftTypeStyle;

/// The list's three layouts: a desktop table row, a phone block, or a card.
enum RaftRackLayout { list, phone, card }

// computersRackLayout.ts: the desktop columns, the same on every row and
// under the header (computer 252, agents the rest, Disk and Memory 80 each,
// Other 40, the next step 184, the … menu), 12px apart.
const double raftRackGap = 12;
const double raftRackIdentityWidth = 252;
const double raftRackCellWidth = 80;
const double raftRackOtherWidth = 40;
const double raftRackActionWidth = 184;
const double raftRackMenuWidth = 32;

/// Cards of at least 250px: four a row at 1440 wide, one on a phone.
const double raftRackCardMinWidth = 250;

TextStyle _type(
  RaftTokens t,
  RaftTypeStyle s, {
  Color? color,
  FontWeight? weight,
  bool mono = false,
}) =>
    (mono
            ? RaftTypography.mono(
                t,
                size: s.fontSize,
                line: s.lineHeight,
                color: color,
              )
            : RaftTypography.body(
                t,
                size: s.fontSize,
                line: s.lineHeight,
                color: color,
              ))
        .copyWith(fontWeight: weight);

Color _hint(RaftTokens t) => t.colors['foreground-hint']!;
Color _muted(RaftTokens t) => t.colors['foreground-muted']!;
Color _warn(RaftTokens t) => t.colors['warning-strong']!;

/// A computer's light on its device glyph's corner (ComputerRowStatusDot):
/// an update waiting (available or required) is the orange error light;
/// liveness is the fixed presence light.
enum RaftRackDot { online, offline, upgrade, upgrading }

/// One computer as the rack draws it.
class RaftRackComputer {
  const RaftRackComputer({
    required this.id,
    required this.name,
    required this.dot,
    required this.offline,
    required this.facts,
    required this.owner,
    this.availableVersion,
    this.factNote,
    this.diskLowLabel,
    this.diskLowTitle,
    this.disk,
    this.memory,
    this.agentCount = 0,
    this.agents = const [],
    this.otherRuntimes = const [],
    this.selected = false,
    this.dotLabel,
    this.glyph = RaftGlyph.monitor,
  });

  /// The device shape (Web ComputerDeviceIcon): laptop, monitor, server, cloud.
  final RaftGlyph glyph;
  final String id, name;
  final RaftRackDot dot;

  /// Offline (no meters, the recovery line instead of the next step).
  final bool offline;

  /// "Ubuntu 26.04 · v1.0.68", or "Offline · last seen 2 hours ago".
  final String facts;

  /// "→ v1.0.69" after the version, orange; or "Update required".
  final String? availableVersion, factNote;

  /// "Owner: Alice" or "Public (no owner)".
  final String owner;

  /// The Low disk badge and its title ("12 GB free of 500 GB").
  final String? diskLowLabel, diskLowTitle, dotLabel;

  /// Disk and Memory: label, share used (0..1, null = "—"), "x% used".
  final RaftRackMeter? disk, memory;
  final int agentCount;

  /// The agents' slots (avatars), in order.
  final List<Widget> agents;

  /// The runtimes that report no usage ("Other").
  final List<String> otherRuntimes;
  final bool selected;
}

class RaftRackMeter {
  const RaftRackMeter({
    required this.label,
    required this.used,
    required this.text,
    this.warn = false,
    this.emphasized = false,
  });
  final String label;
  final double? used;
  final String text;
  final bool warn, emphasized;
}

/// The device glyph with the row's light on its corner.
class RaftRackDeviceIcon extends StatelessWidget {
  const RaftRackDeviceIcon({
    super.key,
    required this.dot,
    this.label,
    this.glyph = RaftGlyph.monitor,
  });
  final RaftGlyph glyph;
  final RaftRackDot dot;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return SizedBox.square(
      dimension: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RaftIcon(glyph, size: 20, color: _muted(t)),
          Positioned(
            right: -4,
            bottom: -4,
            child: RaftStatus(
              semanticLabel: label,
              presence: switch (dot) {
                RaftRackDot.online => RaftPresence.online,
                RaftRackDot.offline => RaftPresence.offline,
                RaftRackDot.upgrade => RaftPresence.error,
                RaftRackDot.upgrading => RaftPresence.busy,
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// RackResource.tsx: Disk or Memory as a meter with its share used; "—"
/// with nothing to read.
class RaftRackResource extends StatelessWidget {
  const RaftRackResource({super.key, required this.meter, this.line = false});
  final RaftRackMeter meter;

  /// A card's line (label, bar, "x% used") instead of a list cell.
  final bool line;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final mono = _type(
      t,
      RaftTypeScale.monoMeta,
      mono: true,
      color: meter.warn ? _warn(t) : _hint(t),
      weight: meter.emphasized || meter.warn ? FontWeight.w700 : null,
    );
    final used = meter.used;
    final bar = used == null
        ? const SizedBox.shrink()
        : RaftProgressBar(
            value: used.clamp(0, 1) * 100,
            size: RaftProgressRecipeSize.sm,
            tone: meter.warn
                ? RaftProgressRecipeVariant.warning
                : RaftProgressRecipeVariant.information,
          );
    if (line) {
      return Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              meter.label,
              style: _type(
                t,
                RaftTypeScale.footnote,
                color: _muted(t),
                weight: meter.emphasized ? FontWeight.w700 : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: bar),
          const SizedBox(width: 8),
          Text(used == null ? '—' : meter.text, style: mono),
        ],
      );
    }
    return SizedBox(
      width: raftRackCellWidth,
      child: Semantics(
        label: '${meter.label}: ${used == null ? '—' : meter.text}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              used == null ? '—' : meter.text,
              style: mono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (used != null) ...[const SizedBox(height: 4), bar],
          ],
        ),
      ),
    );
  }
}

/// RackGroupTitle.tsx: a chevron that folds the group, its name and its
/// count in machine type; the whole title is the fold's button.
class RaftRackGroupTitle extends StatelessWidget {
  const RaftRackGroupTitle({
    super.key,
    required this.title,
    required this.counts,
    required this.collapsed,
    required this.onToggle,
    required this.semanticLabel,
    this.cards = false,
  });
  final String title, counts, semanticLabel;
  final bool collapsed, cards;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final toggle = RaftInteractive(
      onPressed: onToggle,
      semanticLabel: semanticLabel,
      builder: (context, state) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedRotation(
            turns: collapsed ? -.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: RaftIcon(
              RaftGlyph.chevronDown,
              size: 14,
              color: state.hovered ? t.strong : _hint(t),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _type(
                t,
                RaftTypeScale.subhead,
                color: t.strong,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            counts,
            style: _type(
              t,
              RaftTypeScale.monoMeta,
              mono: true,
              color: _hint(t),
            ),
          ),
        ],
      ),
    );
    if (cards) {
      return Padding(padding: const EdgeInsets.only(top: 8), child: toggle);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors['layer-canvas'],
        border: Border(bottom: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: toggle,
      ),
    );
  }
}

/// RackListHeader.tsx (desktop): the columns' headings; [onSort] makes the
/// sortable ones buttons, [sortedKey] marks the sorted one with its arrow.
class RaftRackListHeader extends StatelessWidget {
  const RaftRackListHeader({
    super.key,
    required this.computerLabel,
    required this.agentsLabel,
    required this.diskLabel,
    required this.memoryLabel,
    this.otherLabel,
    this.sortedKey,
    this.descending = false,
    this.onSort,
  });
  final String computerLabel, agentsLabel, diskLabel, memoryLabel;
  final String? otherLabel;

  /// 'name', 'disk' or 'memory'.
  final String? sortedKey;
  final bool descending;
  final ValueChanged<String>? onSort;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = _type(t, RaftTypeScale.caption, color: _hint(t));
    Widget heading(String label, String? key, double? width) {
      final sorted = key != null && key == sortedKey;
      final Widget headingLabel = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: sorted ? style.copyWith(color: t.strong) : style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sorted) ...[
            const SizedBox(width: 4),
            RaftIcon(
              descending ? RaftGlyph.arrowDown : RaftGlyph.arrowUp,
              size: 12,
              color: t.strong,
            ),
          ],
        ],
      );
      final text = key != null && onSort != null
          ? RaftInteractive(
              key: ValueKey('rack-sort-$key'),
              onPressed: () => onSort!(key),
              semanticLabel: label,
              builder: (_, _) => headingLabel,
            )
          : headingLabel;
      return width == null
          ? Expanded(child: text)
          : SizedBox(width: width, child: text);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            heading(computerLabel, 'name', raftRackIdentityWidth),
            const SizedBox(width: raftRackGap),
            heading(agentsLabel, null, null),
            const SizedBox(width: raftRackGap),
            heading(diskLabel, 'disk', raftRackCellWidth),
            const SizedBox(width: raftRackGap),
            heading(memoryLabel, 'memory', raftRackCellWidth),
            if (otherLabel != null) ...[
              const SizedBox(width: raftRackGap),
              heading(otherLabel!, null, raftRackOtherWidth),
            ],
            const SizedBox(width: raftRackGap + raftRackActionWidth),
            const SizedBox(width: raftRackGap + raftRackMenuWidth),
          ],
        ),
      ),
    );
  }
}

/// ComputerRackRow.tsx: one computer as a list row, a phone block or a card.
/// A pointer press anywhere on it opens the computer (Web's stretched name
/// link); the name button is the row's one tab stop and carries the focus
/// ring around the whole row. Its slots, next step and … menu act on their own.
class RaftRackRow extends StatefulWidget {
  const RaftRackRow({
    super.key,
    required this.computer,
    required this.layout,
    required this.onOpen,
    this.action,
    this.menu,
    this.noAgentsLabel = 'No agents on this computer yet',
    this.otherRuntimesLabel = 'Other runtimes',
  });
  final RaftRackComputer computer;
  final RaftRackLayout layout;
  final VoidCallback onOpen;

  /// The row's one next step (Upgrade, the recovery command, …) and its menu.
  final Widget? action, menu;
  final String noAgentsLabel, otherRuntimesLabel;

  @override
  State<RaftRackRow> createState() => _RaftRackRowState();
}

class _RaftRackRowState extends State<RaftRackRow> {
  final nameFocus = FocusNode();
  bool hovered = false, ring = false;

  @override
  void initState() {
    super.initState();
    nameFocus.addListener(updateRing);
    RaftFocusVisible.shared.addListener(updateRing);
  }

  @override
  void dispose() {
    RaftFocusVisible.shared.removeListener(updateRing);
    nameFocus.dispose();
    super.dispose();
  }

  void updateRing() {
    final next = nameFocus.hasFocus && RaftFocusVisible.shared.keyboard;
    if (mounted && next != ring) setState(() => ring = next);
  }

  /// The row's pointer surface: hover fill and a press that opens the
  /// computer, without a tab stop or a semantics node of its own.
  Widget surface(double radius, Widget child) => RaftHoverRegion(
    key: ValueKey('rack-row-${widget.computer.id}'),
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => hovered = true),
    onExit: (_) => setState(() => hovered = false),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onOpen,
      // The stretched link's focus ring, `inset-ring-2 inset-ring-ink` over
      // the whole row or card (paint only).
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: RaftCssBox(
                radius: radius,
                insetRingWidth: ring ? 2 : 0,
                insetRingColor: RaftTokens.of(context).ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final c = widget.computer;
    final layout = widget.layout;
    final action = widget.action, menu = widget.menu;
    final hint = _type(t, RaftTypeScale.monoMeta, mono: true, color: _hint(t));
    final orange = hint.copyWith(color: _warn(t), fontWeight: FontWeight.w700);
    // The stretched link's button: the name, the row's tab stop.
    final name = RaftInteractive(
      key: ValueKey('rack-row-name-${c.id}'),
      focusNode: nameFocus,
      onPressed: widget.onOpen,
      semanticLabel: c.name,
      selected: c.selected ? true : null,
      builder: (context, _) => ExcludeSemantics(
        child: Text(
          c.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _type(
            t,
            RaftTypeScale.callout,
            color: t.strong,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
    final diskLow = c.diskLowLabel == null
        ? null
        : RaftBadge(
            key: ValueKey('rack-disk-low-${c.id}'),
            label: c.diskLowLabel!,
            appearance: RaftBadgeRecipeAppearance.soft,
            variant: RaftBadgeRecipeVariant.warning,
          );
    final identity = Row(
      children: [
        RaftRackDeviceIcon(dot: c.dot, label: c.dotLabel, glyph: c.glyph),
        const SizedBox(width: 8),
        Flexible(child: name),
        if (layout == RaftRackLayout.phone) ...[
          const SizedBox(width: 8),
          Text('${c.agentCount}', style: hint),
        ],
        if (diskLow != null) ...[const SizedBox(width: 8), diskLow],
      ],
    );
    final facts = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: c.facts),
          if (!c.offline && c.availableVersion != null)
            TextSpan(text: ' ${c.availableVersion}', style: orange),
          if (!c.offline && c.factNote != null)
            TextSpan(text: ' · ${c.factNote}', style: orange),
        ],
      ),
      key: ValueKey('rack-row-facts-${c.id}'),
      style: hint,
      maxLines: c.offline && layout == RaftRackLayout.card ? 2 : 1,
      overflow: TextOverflow.ellipsis,
    );
    final owner = Text(
      c.owner,
      key: ValueKey('rack-row-owner-${c.id}'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _type(t, RaftTypeScale.caption, color: _hint(t)),
    );
    Widget slots({bool reserve = false}) => c.agents.isEmpty
        ? (reserve
              ? const SizedBox(height: 28)
              : Semantics(
                  label: widget.noAgentsLabel,
                  excludeSemantics: true,
                  child: Text('—', style: hint),
                ))
        // RackSlotStrip: one 27px line of compact-row slots. Its 4px inset
        // (taken back by a negative margin on Web) keeps the activity light
        // inside the scroll box; each slot keeps its own square size.
        : SizedBox(
            key: ValueKey('rack-slots-${c.id}'),
            height: RaftAvatarSize.sm.extent,
            child: OverflowBox(
              minHeight: RaftAvatarSize.sm.extent + 8,
              maxHeight: RaftAvatarSize.sm.extent + 8,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                scrollDirection: Axis.horizontal,
                itemCount: c.agents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (_, i) => Center(
                  child: Opacity(
                    opacity: c.offline ? .5 : 1,
                    child: c.agents[i],
                  ),
                ),
              ),
            ),
          );
    final other = c.otherRuntimes.isEmpty
        ? null
        : Text(
            c.otherRuntimes.join(', '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hint,
          );
    Color? fill() => c.selected
        ? t.colors['info-soft']
        : hovered
        ? t.colors['fill-muted']
        : c.offline
        ? (t.colors['fill-subtle'] ?? t.colors['layer-canvas'])
        : null;

    switch (layout) {
      case RaftRackLayout.card:
        return surface(
          RaftRadius.container,
          RaftCard(
            background: fill(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: identity),
                    ?menu,
                  ],
                ),
                const SizedBox(height: 4),
                facts,
                owner,
                const SizedBox(height: 12),
                slots(reserve: true),
                if (!c.offline) ...[
                  const SizedBox(height: 12),
                  if (c.disk != null)
                    RaftRackResource(meter: c.disk!, line: true),
                  const SizedBox(height: 8),
                  if (c.memory != null)
                    RaftRackResource(meter: c.memory!, line: true),
                  if (other != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          widget.otherRuntimesLabel,
                          style: _type(
                            t,
                            RaftTypeScale.footnote,
                            color: _muted(t),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: other),
                      ],
                    ),
                  ],
                ],
                if (action != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: c.offline
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ],
              ],
            ),
          ),
        );
      case RaftRackLayout.phone:
        return surface(
          0,
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill(),
              border: Border(bottom: BorderSide(color: t.colors['line-seam']!)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  const SizedBox(height: 2),
                  facts,
                  const SizedBox(height: 4),
                  owner,
                  if (c.agents.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    slots(),
                  ],
                  if (action != null) ...[const SizedBox(height: 8), action],
                ],
              ),
            ),
          ),
        );
      case RaftRackLayout.list:
        return surface(
          0,
          DecoratedBox(
            decoration: BoxDecoration(
              color: fill(),
              border: Border(
                bottom: BorderSide(color: t.colors['line-hairline']!),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: raftRackIdentityWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          identity,
                          Padding(
                            padding: const EdgeInsets.only(left: 28, top: 2),
                            child: facts,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: owner,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: raftRackGap),
                    Expanded(child: slots()),
                    const SizedBox(width: raftRackGap),
                    if (c.offline)
                      SizedBox(
                        width:
                            raftRackCellWidth * 2 +
                            raftRackGap * 2 +
                            raftRackActionWidth,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action ?? const SizedBox.shrink(),
                        ),
                      )
                    else ...[
                      if (c.disk != null) RaftRackResource(meter: c.disk!),
                      const SizedBox(width: raftRackGap),
                      if (c.memory != null) RaftRackResource(meter: c.memory!),
                      const SizedBox(width: raftRackGap),
                      SizedBox(
                        width: raftRackActionWidth,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(width: raftRackGap),
                    SizedBox(
                      width: raftRackMenuWidth,
                      child: menu ?? const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// RackRowSkeleton.tsx: a placeholder in a loaded row's shape.
class RaftRackRowSkeleton extends StatelessWidget {
  const RaftRackRowSkeleton({super.key, required this.layout});
  final RaftRackLayout layout;
  @override
  Widget build(BuildContext context) {
    final bars = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: const [
        RaftSkeleton(width: 112, height: 14),
        SizedBox(height: 6),
        RaftSkeleton(width: 160, height: 10),
        SizedBox(height: 4),
        RaftSkeleton(width: 96, height: 10),
      ],
    );
    return ExcludeSemantics(
      child: layout == RaftRackLayout.card
          ? RaftCard(padding: const EdgeInsets.all(16), child: bars)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: bars,
            ),
    );
  }
}

/// ComputersAttentionSummary.tsx: the lines above the list (what needs a
/// person, what is waiting), each made of parts joined by a middle dot.
class RaftRackAttentionSummary extends StatelessWidget {
  const RaftRackAttentionSummary({super.key, required this.lines});

  /// Each line's parts (text or a [RaftTextLink]).
  final List<List<Widget>> lines;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = _type(t, RaftTypeScale.callout, color: _muted(t));
    return DecoratedBox(
      key: const ValueKey('computers-attention-summary'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DefaultTextStyle.merge(
          style: style,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final parts in lines)
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < parts.length; i++) ...[
                      if (i > 0)
                        ExcludeSemantics(child: Text('·', style: style)),
                      parts[i],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line of the summary while the computers load: a bar per line.
class RaftRackAttentionSummarySkeleton extends StatelessWidget {
  const RaftRackAttentionSummarySkeleton({super.key, required this.lines});
  final int lines;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines.clamp(0, 2); i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: RaftSkeleton(width: i == 0 ? 224 : 160, height: 16),
            ),
        ],
      ),
    ),
  );
}

/// The toolbar over the list (Raft DS › Patterns › The toolbar over a
/// list): the search filling the line, the filters, Clear all at their end,
/// then Group, Sort, the view switch and Add computer last. Narrow, the
/// filters and display controls move to their own scrolling line.
class RaftRackToolbar extends StatelessWidget {
  const RaftRackToolbar({
    super.key,
    required this.search,
    required this.filters,
    required this.display,
    this.add,
  });
  final Widget search;
  final List<Widget> filters, display;
  final Widget? add;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('computers-rack-toolbar'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.colors['line-hairline']!)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LayoutBuilder(
          builder: (context, box) {
            final controls = [
              ...filters,
              if (filters.isNotEmpty && display.isNotEmpty)
                const SizedBox(width: 4),
              ...display,
            ];
            final wide = box.maxWidth >= 900;
            if (wide) {
              // Web: the search is a fixed-width field (322 px) at the start;
              // the controls follow at the end, scrolling sideways only when
              // the window is too narrow for them.
              return Row(
                children: [
                  SizedBox(width: 322, child: search),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < controls.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              controls[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (add != null) ...[const SizedBox(width: 8), add!],
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: search),
                    if (add != null) ...[const SizedBox(width: 8), add!],
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < controls.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        controls[i],
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The counts beside the page title: "15 computers · 13 online · 54 agents".
class RaftRackCounts extends StatelessWidget {
  const RaftRackCounts(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Text(
      text,
      key: const ValueKey('computers-rack-counts'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _type(t, RaftTypeScale.monoMeta, mono: true, color: _hint(t)),
    );
  }
}

/// ForceUnbindAgentsDialog.tsx's body: the consequence in a danger banner,
/// then every agent it unbinds with its owner and computer.
class RaftForceUnbindAgentList extends StatelessWidget {
  const RaftForceUnbindAgentList({
    super.key,
    required this.message,
    required this.listLabel,
    required this.agents,
  });
  final String message, listLabel;
  final List<({String id, String name, String meta})> agents;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Column(
      key: const ValueKey('force-unbind-dialog-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RaftBanner(
          status: RaftBannerRecipeStatus.destructive,
          size: RaftBannerRecipeSize.sm,
          description: message,
        ),
        const SizedBox(height: 12),
        Semantics(
          label: listLabel,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in agents)
                Padding(
                  key: ValueKey('force-unbind-agent-${a.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: RaftIcon(
                          RaftGlyph.bot,
                          size: 16,
                          color: _muted(t),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              style: _type(
                                t,
                                RaftTypeScale.body,
                                color: t.strong,
                                weight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              a.meta,
                              style: _type(
                                t,
                                RaftTypeScale.callout,
                                color: _muted(t),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// RackRowAction's offline step: "Bring this computer back online" (desktop
/// only) beside the restart command; the command takes its own line where
/// the label leaves it too little room.
class RaftRackRecovery extends StatelessWidget {
  const RaftRackRecovery({super.key, this.label, required this.command});
  final String? label;
  final Widget command;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Text(
            label!,
            style: _type(t, RaftTypeScale.footnote, color: _muted(t)),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 192, maxWidth: 520),
          child: command,
        ),
      ],
    );
  }
}

/// The … menu's box, held empty for whoever may not manage the computer.
class RaftRackMenuSpace extends StatelessWidget {
  const RaftRackMenuSpace({super.key});
  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: raftRackMenuWidth);
}

/// The rack's one scroller: rows top to bottom (the desktop list under its
/// header, scrolling sideways below its fixed columns' width), or cards in
/// rows of at least [raftRackCardMinWidth] with group titles across the row.
class RaftRackScroller extends StatelessWidget {
  const RaftRackScroller({
    super.key,
    required this.layout,
    required this.children,
    this.header,
  });
  final RaftRackLayout layout;
  final List<Widget> children;
  final Widget? header;

  /// computersRackLayout.ts listMinWidthPx without usage columns.
  static const double listMinWidth =
      raftRackIdentityWidth +
      96 +
      raftRackCellWidth * 2 +
      raftRackActionWidth +
      raftRackMenuWidth +
      raftRackGap * 5 +
      40;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    if (layout != RaftRackLayout.card) {
      final list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: children,
            ),
          ),
        ],
      );
      return ColoredBox(
        color: layout == RaftRackLayout.phone
            ? (t.colors['layer-card'] ?? t.panel)
            : t.colors['layer-canvas']!,
        child: layout == RaftRackLayout.phone
            ? list
            : LayoutBuilder(
                builder: (context, box) => box.maxWidth >= listMinWidth
                    ? list
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: listMinWidth, child: list),
                      ),
              ),
      );
    }
    return ColoredBox(
      color: t.colors['layer-canvas']!,
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = raftRackGap, pad = 20.0;
          final inner = box.maxWidth - pad * 2;
          final perRow = ((inner + gap) / (raftRackCardMinWidth + gap))
              .floor()
              .clamp(1, 64);
          final rows = <Widget>[];
          var pending = <Widget>[];
          void flush() {
            if (pending.isEmpty) return;
            final cells = pending;
            pending = [];
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < perRow; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        Expanded(
                          child: i < cells.length
                              ? cells[i]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }

          for (final child in children) {
            if (child is RaftRackGroupTitle) {
              flush();
              rows.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: child,
                ),
              );
            } else {
              pending.add(child);
              if (pending.length == perRow) flush();
            }
          }
          flush();
          return ListView(padding: const EdgeInsets.all(pad), children: rows);
        },
      ),
    );
  }
}

/// The rack beside the open computer's panel (Raft DS › Navigation,
/// "Opening an item"): the panel at [width] on the right, a hairline between.
/// With [onResize] its left edge is a drag handle (Web `ColumnResizeHandle
/// column="detail"`, the profile panel's 300 to 600 range), kept by the host.
class RaftRackSidePanelLayout extends StatelessWidget {
  const RaftRackSidePanelLayout({
    super.key,
    required this.rack,
    required this.width,
    this.panel,
    this.onResize,
    this.onResizeEnd,
    this.resizeLabel = 'Resize profile',
    this.resizeMin = 300,
    this.resizeMax = 600,
    this.resizeDefault = 380,
  });

  /// The profile panel's bounds (Web `COLUMN_BOUNDS.detail`) and default.
  final double resizeMin, resizeMax, resizeDefault;
  final Widget rack;
  final Widget? panel;
  final double width;
  final ValueChanged<double>? onResize;
  final VoidCallback? onResizeEnd;
  final String resizeLabel;
  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: rack),
        if (panel != null)
          DecoratedBox(
            key: const ValueKey('computers-rack-side-panel'),
            decoration: BoxDecoration(
              color: t.panel,
              border: Border(left: BorderSide(color: t.colors['line-muted']!)),
            ),
            child: SizedBox(width: width, child: panel),
          ),
      ],
    );
    if (panel == null || onResize == null) return row;
    return Stack(
      fit: StackFit.expand,
      children: [
        row,
        // The handle overlays the seam; its hit strip takes no layout width.
        Positioned(
          right: width - RaftPanelResizeHandle.hitExtent / 2,
          top: 0,
          bottom: 0,
          width: RaftPanelResizeHandle.hitExtent,
          child: RaftPanelResizeHandle(
            key: const ValueKey('rack-side-panel-resize-handle'),
            label: resizeLabel,
            value: width,
            reversed: true,
            onChanged: onResize!,
            onChangeEnd: onResizeEnd,
            min: resizeMin,
            max: resizeMax,
            defaultValue: resizeDefault,
          ),
        ),
      ],
    );
  }
}

/// A rack row or card that takes a dragged agent (Web ComputerRackRow
/// `data-drop-target`): `bg-info-soft` while a valid drag is over it. [accepts]
/// decides per dragged value; [onDrop] gets it.
class RaftRackDropTarget<T extends Object> extends StatelessWidget {
  const RaftRackDropTarget({
    super.key,
    required this.accepts,
    required this.onDrop,
    required this.child,
  });
  final bool Function(T value) accepts;
  final ValueChanged<T> onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return DragTarget<T>(
      onWillAcceptWithDetails: (d) => accepts(d.data),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) => Container(
        key: const ValueKey('rack-drop-surface'),
        color: candidates.isEmpty ? null : t.colors['info-soft'],
        child: child,
      ),
    );
  }
}
